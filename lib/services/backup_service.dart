import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';

enum BackupImportStatus { cancelled, success, wrongPassword, corrupt }

class BackupImportResult {
  final BackupImportStatus status;
  final Map<String, dynamic>? data;
  const BackupImportResult(this.status, [this.data]);
}

/// Local encrypted backups (AES-256-CBC, key derived with PBKDF2-HMAC-SHA256).
///
/// Format: base64( JSON { 'v', 'salt', 'iv', 'data' } ), i.e. the salt, iv and
/// ciphertext travel together so decrypt can recover them. Backups are LOCAL
/// ONLY and are never pushed through the sync engine.
class BackupService {
  BackupService._();

  static const String formatVersion = '1';
  static const int pbkdf2Iterations = 100000;
  static const int saltLength = 16;
  static const int ivLength = 16;
  static const int keyLength = 32;

  static final Random _random = Random.secure();

  // ---- key derivation: PBKDF2-HMAC-SHA256 (crypto is a direct dependency) ----
  static Uint8List _deriveKey(String password, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final out = Uint8List(keyLength);
    final block = Uint8List(4);
    var offset = 0;
    var blockIndex = 1;
    while (offset < keyLength) {
      block[0] = (blockIndex >> 24) & 0xff;
      block[1] = (blockIndex >> 16) & 0xff;
      block[2] = (blockIndex >> 8) & 0xff;
      block[3] = blockIndex & 0xff;
      final u1 = Uint8List.fromList(hmac.convert([...salt, ...block]).bytes);
      final t = Uint8List.fromList(u1);
      var u = u1;
      for (var i = 2; i <= pbkdf2Iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      final n = min(keyLength - offset, t.length);
      out.setRange(offset, offset + n, t.sublist(0, n));
      offset += n;
      blockIndex++;
    }
    return out;
  }

  static Map<String, dynamic> _wrapper(String jsonStr, String password) {
    final salt = Uint8List.fromList(
        List.generate(saltLength, (_) => _random.nextInt(256)));
    final key = _deriveKey(password, salt);
    final iv = IV.fromSecureRandom(ivLength);
    final encrypter = Encrypter(AES(Key(key), mode: AESMode.cbc));
    return {
      'v': formatVersion,
      'salt': base64.encode(salt),
      'iv': base64.encode(iv.bytes),
      'data': encrypter.encrypt(jsonStr, iv: iv).base64,
    };
  }

  /// JSON -> base64 ciphertext.
  static String encryptJson(String jsonStr, String password) => base64.encode(
      utf8.encode(jsonEncode(_wrapper(jsonStr, password))));

  /// base64 ciphertext -> original JSON string, or null on wrong password /
  /// corrupt payload.
  static String? decryptJson(String ciphertext, String password) {
    try {
      final payload = _parsePayload(ciphertext);
      if (payload == null) return null;
      final key = _deriveKey(password, payload.salt);
      final encrypter = Encrypter(AES(Key(key), mode: AESMode.cbc));
      return encrypter.decrypt(
        Encrypted(payload.data),
        iv: IV(payload.iv),
      );
    } catch (_) {
      return null;
    }
  }

  static _BackupPayload? _parsePayload(String ciphertext) {
    try {
      final decoded = jsonDecode(utf8.decode(base64.decode(ciphertext.trim())));
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (map['v'] != formatVersion) return null;
      final salt = base64.decode(map['salt'] as String);
      final iv = base64.decode(map['iv'] as String);
      final data = base64.decode(map['data'] as String);
      if (salt.length != saltLength || iv.length != ivLength) return null;
      return _BackupPayload(salt, iv, data);
    } catch (_) {
      return null;
    }
  }

  /// Serialize the state, encrypt it and write + share dalideck_backup_YYYYMMDD.enc.
  static Future<String> exportBackup(AppState s, String password) async {
    final payload = encryptJson(jsonEncode(s.toJson()), password);
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final name = 'dalideck_backup_${now.year}${two(now.month)}${two(now.day)}.enc';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(payload, flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'DaliDeck backup',
      text: 'DaliDeck encrypted backup',
    );
    return file.path;
  }

  /// Let the user pick a backup file (any file). Returns its path or null.
  static Future<String?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null || path.isEmpty) return null;
    return path;
  }

  /// Read, decrypt and validate a picked backup file.
  /// [path] can be omitted to trigger the picker here, but the UI flow that
  /// needs the password dialog BETWEEN pick and decrypt passes the path in.
  static Future<BackupImportResult> importBackup({
    String? path,
    required String password,
  }) async {
    final p = path ?? await pickBackupFile();
    if (p == null) {
      return const BackupImportResult(BackupImportStatus.cancelled);
    }
    try {
      final content = await File(p).readAsString();
      if (_parsePayload(content) == null) {
        return const BackupImportResult(BackupImportStatus.corrupt);
      }
      final jsonStr = decryptJson(content, password);
      if (jsonStr == null) {
        return const BackupImportResult(BackupImportStatus.wrongPassword);
      }
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        return const BackupImportResult(BackupImportStatus.corrupt);
      }
      final map = Map<String, dynamic>.from(decoded);
      if (!map.containsKey('v') && !map.containsKey('subjects')) {
        return const BackupImportResult(BackupImportStatus.corrupt);
      }
      return BackupImportResult(BackupImportStatus.success, map);
    } catch (_) {
      return const BackupImportResult(BackupImportStatus.corrupt);
    }
  }
}

class _BackupPayload {
  final Uint8List salt;
  final Uint8List iv;
  final Uint8List data;
  _BackupPayload(this.salt, this.iv, this.data);
}