// Unit D tests — Encrypted backup service (lib/services/backup_service.dart).
//
// Plan asserts (UNIT D):
//   happy — encryptJson then decryptJson with the same password returns the
//           original JSON
//   edge  — wrong password returns null; corrupt input returns null (no throw)
//
// Only the pure functions encryptJson/decryptJson are exercised here.
// exportBackup/importBackup touch dart:io + share_plus/file_picker plugin
// channels and cannot run in unit tests (no plugin host on the test VM) — see
// EXTRA in the report.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dalideck/models.dart';
import 'package:dalideck/services/backup_service.dart';

Map<String, dynamic> _payloadOf(String ciphertext) =>
    Map<String, dynamic>.from(
        jsonDecode(utf8.decode(base64.decode(ciphertext))) as Map);

/// Re-encode a valid ciphertext with one or more wrapper fields rewritten.
String _remap(
    String ciphertext, void Function(Map<String, dynamic> m) edit) {
  final m = _payloadOf(ciphertext);
  edit(m);
  return base64.encode(utf8.encode(jsonEncode(m)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encryptJson -> decryptJson with the same password roundtrips '
      'identically', () {
    const json =
        '{"v":2,"name":"Dali","emoji":"🎯","n":3.14,"arr":[1,2,3],'
        '"nested":{"a":true},"s":"x\\"y"}';
    final enc = BackupService.encryptJson(json, 's3cret-pass');
    expect(enc, isNotEmpty);
    expect(enc, isNot(equals(json)), reason: 'backup is never plaintext');
    expect(BackupService.decryptJson(enc, 's3cret-pass'), json);
  });

  test('roundtrips a full serialized AppState backup', () {
    final s = AppState.seed()..repair();
    s.money.add(MoneyEntry(uid())
      ..type = 'out'
      ..amount = 2500
      ..cat = 'school'
      ..date = todayStr());
    s.budgets.add(BudgetCategory(uid())..cat = 'food'..limit = 50000);
    s.habits.add(Habit(uid())..name = 'revision'..days = [todayStr()]);
    final json = jsonEncode(s.toJson());
    final enc = BackupService.encryptJson(json, 'pw');
    expect(BackupService.decryptJson(enc, 'pw'), json);
  });

  test('wrong password returns null (no throw)', () {
    final enc = BackupService.encryptJson('{"a":1}', 'right-password');
    expect(BackupService.decryptJson(enc, 'wrong-password'), isNull);
    expect(BackupService.decryptJson(enc, ''), isNull);
  });

  test('an empty password is a valid (weak) password', () {
    final enc = BackupService.encryptJson('{"a":1}', '');
    expect(BackupService.decryptJson(enc, ''), '{"a":1}');
  });

  test('corrupt ciphertext returns null without throwing', () {
    expect(BackupService.decryptJson('', 'pw'), isNull);
    expect(BackupService.decryptJson('!!!not-base64!!!', 'pw'), isNull);
    // base64 of non-JSON bytes:
    expect(BackupService.decryptJson(base64.encode(utf8.encode('hello')), 'pw'),
        isNull);
    // valid JSON but not the backup wrapper format:
    expect(
        BackupService.decryptJson(
            base64.encode(utf8.encode('{"x":1}')), 'pw'),
        isNull);
  });

  test('surrounding whitespace is tolerated on decrypt', () {
    final enc = BackupService.encryptJson('{"a":1}', 'pw');
    expect(BackupService.decryptJson('  $enc  ', 'pw'), '{"a":1}');
  });

  test('tampered wrapper fields are rejected as corrupt (null)', () {
    final enc = BackupService.encryptJson('{"a":1}', 'pw');
    // unknown format version:
    expect(
        BackupService.decryptJson(_remap(enc, (m) => m['v'] = '9'), 'pw'),
        isNull);
    // salt shorter than the mandated 16 bytes:
    expect(
        BackupService.decryptJson(
            _remap(enc, (m) => m['salt'] = base64.encode(List.filled(4, 7))),
            'pw'),
        isNull);
    // iv shorter than the mandated 16 bytes:
    expect(
        BackupService.decryptJson(
            _remap(enc, (m) => m['iv'] = base64.encode(List.filled(8, 3))),
            'pw'),
        isNull);
  });

  test('two encryptions of the same JSON differ (random salt/iv)', () {
    final a = BackupService.encryptJson('{"a":1}', 'pw');
    final b = BackupService.encryptJson('{"a":1}', 'pw');
    expect(b, isNot(equals(a)));
    final p = _payloadOf(a);
    expect(p['v'], BackupService.formatVersion);
    expect(p.containsKey('salt'), isTrue);
    expect(p.containsKey('iv'), isTrue);
    expect(p.containsKey('data'), isTrue);
  });
}