import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

const String prefsDataKey = 'dalideck.v1';
const String prefsSyncKey = 'dalideck.syncKey';
const String prefsSyncState = 'dalideck.syncState';

Future<Store> loadStore() async {
  final p = await SharedPreferences.getInstance();
  AppState s;
  final raw = p.getString(prefsDataKey);
  if (raw != null && raw.isNotEmpty) {
    try {
      s = AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      s = AppState.seed();
    }
  } else {
    s = AppState.seed();
  }
  s.repair();
  final store = Store(s);
  store.saveRequested = () async {
    await p.setString(prefsDataKey, jsonEncode(store.s.toJson()));
  };
  return store;
}

Future<void> persistData(Store store) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(prefsDataKey, jsonEncode(store.s.toJson()));
}