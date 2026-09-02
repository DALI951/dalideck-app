import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'store.dart';

const String syncEnd = 'https://modali.powerpme.com/dalideck-sync/api.php';

Future<String?> _getPref(String key) async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getString(key);
  } catch (e) {
    debugPrint('SharedPreferences get failed: $e');
    return null;
  }
}
Future<void> _setPref(String key, String value) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, value);
  } catch (e) {
    debugPrint('SharedPreferences set failed: $e');
  }
}
Future<void> _delPref(String key) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.remove(key);
  } catch (e) {
    debugPrint('SharedPreferences remove failed: $e');
  }
}

enum SyncStateVal { off, syncing, ok, err }

// Short, typable sync key — 8 chars, no confusing glyphs.
String generateKey() {
  const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
  final rnd = DateTime.now().millisecondsSinceEpoch;
  var seed = rnd;
  final out = StringBuffer();
  for (var i = 0; i < 8; i++) {
    seed = (seed * 31 + 7) & 0x7fffffff;
    out.write(chars[seed % chars.length]);
  }
  return out.toString();
}

class SyncEngine extends ChangeNotifier {
  final Store store;
  SyncStateVal state = SyncStateVal.off;
  String lastErr = '';
  String? apiKey;
  DateTime? lastSync;

  Map<String, dynamic> _ss = {
    'v': 1, 'baseRev': 0, 'updatedAt': 0, 'seen': {}, 'local': {}
  };
  bool _busy = false;
  int _pushAttempts = 0;
  Timer? _pullTimer;
  Timer? _pushDebounce;

  SyncEngine(this.store);

  Future<void> load() async {
    apiKey = await _getPref(prefsSyncKey);
    final raw = await _getPref(prefsSyncState);
    if (raw != null && raw.isNotEmpty) {
      try {
        _ss = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    if (apiKey != null && apiKey!.length >= 6) {
      startPullTimer();
      syncNow();
    } else {
      state = SyncStateVal.off;
      notifyListeners();
    }
  }

  // Called by the app after every save().
  void markSaved() {
    _persist();
    if (apiKey == null || apiKey!.length < 6) return;
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 1500), pushNow);
  }

  void connect(String key) {
    final clean = key.trim().replaceAll(RegExp(r'[\s\-_]'), '');
    if (clean.length < 6) {
      lastErr = 'Key too short (min 6 chars)';
      state = SyncStateVal.err;
      notifyListeners();
      return;
    }
    apiKey = clean;
    _setPref(prefsSyncKey, apiKey!);
    _ss = {
      'v': 1, 'baseRev': 0, 'updatedAt': 0, 'seen': {}, 'local': {}
    };
    _setPref(prefsSyncState, jsonEncode(_ss));
    startPullTimer();
    state = SyncStateVal.ok;
    notifyListeners();
    syncNow();
  }

  void disconnect() {
    _delPref(prefsSyncKey);
    _delPref(prefsSyncState);
    _pullTimer?.cancel();
    apiKey = null;
    state = SyncStateVal.off;
    notifyListeners();
  }

  void startPullTimer() {
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(const Duration(seconds: 60), (_) => syncNow());
  }

  Future<void> syncNow() async {
    if (_busy || apiKey == null || apiKey!.length < 6) return;
    _busy = true;
    if (state != SyncStateVal.syncing) {
      state = SyncStateVal.syncing;
      notifyListeners();
    }
    try {
      final res = await http.get(Uri.parse('$syncEnd?op=get&key=${apiKey}'));
      if (res.statusCode == 200) {
        final box = jsonDecode(res.body) as Map<String, dynamic>;
        if (box['ok'] == true) {
          _ss['baseRev'] = box['rev'];
          _ss['updatedAt'] = box['updatedAt'];
          final data = box['data'];
          if (data is Map) {
            final changed = mergeState(Map<String, dynamic>.from(data));
            if (changed) {
              await persistData(store);
            }
          }
          lastSync = DateTime.now();
          state = SyncStateVal.ok;
        } else if (box['code'] == 'new') {
          // First contact: seed the server with our data. (Direct _doPush:
          // pushNow() would bail out because _busy is still true here.)
          _ss['baseRev'] = 0;
          _pushAttempts = 0;
          await _doPush();
        } else {
          lastErr = '${box['code']}';
          state = SyncStateVal.err;
        }
      } else {
        lastErr = 'HTTP ${res.statusCode}';
        state = SyncStateVal.err;
      }
    } catch (e) {
      lastErr = '$e';
      state = SyncStateVal.err;
    } finally {
      _persist();
      _busy = false;
      notifyListeners();
    }
  }

  // Returns true if the local state changed (server won somewhere).
  bool mergeState(Map<String, dynamic> serverData) {
    final seen0 = Map<String, dynamic>.from((_ss['seen'] as Map?) ?? {});
    final local0 = Map<String, dynamic>.from((_ss['local'] as Map?) ?? {});
    var changed = false;
    for (final col in kColls) {
      final sval = serverData[col];
      if (sval == null) continue;
      final ser = jsonSer(sval);
      final serverNew = seen0[col] != ser;
      final ld = local0[col];
      final localDirty = ld is Map && (ld['n'] as num? ?? 0) > 0;
      final localTs = ld is Map ? ((ld['t'] as num?) ?? 0) : 0;
      final serverTs = ((_ss['updatedAt'] as num?) ?? 0) * 1000;
      if (serverNew && !localDirty) {
        store.s.putColl(col, sval);
        seen0[col] = ser;
        changed = true;
      } else if (serverNew && localDirty) {
        if (serverTs > localTs) {
          store.s.putColl(col, sval);
          seen0[col] = ser;
          local0.remove(col);
          changed = true;
        } else {
          // local change stays pending; acknowledge server version
          seen0[col] = ser;
        }
      }
    }
    _ss['seen'] = seen0;
    _ss['local'] = local0;
    return changed;
  }

  Future<void> pushNow() async {
    if (_busy || apiKey == null || apiKey!.length < 6) return;
    _pushAttempts = 0;
    await _doPush();
  }

  Future<void> _doPush() async {
    _pushAttempts++;
    if (_pushAttempts > 3) return;
    try {
      final body = jsonEncode({
        'op': 'push',
        'key': apiKey,
        'rev': _ss['baseRev'] ?? 0,
        'data': store.s.toJson(),
      });
      final res = await http.post(Uri.parse(syncEnd),
          headers: {'Content-Type': 'application/json'}, body: body);
      if (res.statusCode == 200) {
        final box = jsonDecode(res.body) as Map<String, dynamic>;
        if (box['ok'] == true) {
          _ss['baseRev'] = box['rev'];
          _ss['updatedAt'] = box['updatedAt'];
          _markAllSeen();
          lastSync = DateTime.now();
          state = SyncStateVal.ok;
          _persist();
          notifyListeners();
          return;
        } else if (box['code'] == 'new') {
          _ss['baseRev'] = 0;
          await _doPush();
          return;
        } else {
          lastErr = '${box['code']}';
          state = SyncStateVal.err;
          _persist();
          notifyListeners();
          return;
        }
      } else if (res.statusCode == 409) {
        final box = jsonDecode(res.body) as Map<String, dynamic>;
        _ss['baseRev'] = box['rev'];
        _ss['updatedAt'] = box['updatedAt'];
        final data = box['data'];
        if (data is Map) {
          mergeState(Map<String, dynamic>.from(data));
          await persistData(store);
        }
        await _doPush();
        return;
      } else {
        lastErr = 'HTTP ${res.statusCode}';
        state = SyncStateVal.err;
        _persist();
        notifyListeners();
      }
    } catch (e) {
      lastErr = '$e';
      state = SyncStateVal.err;
      _persist();
      notifyListeners();
    }
  }

  void _markAllSeen() {
    final seen0 = Map<String, dynamic>.from((_ss['seen'] as Map?) ?? {});
    for (final col in kColls) {
      seen0[col] = jsonSer(store.s.coll(col));
    }
    _ss['seen'] = seen0;
  }

  void _persist() async {
    await _setPref(prefsSyncState, jsonEncode(_ss));
  }
}