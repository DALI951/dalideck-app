import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

const String prefsDataKey = 'dalideck.v1';
const String prefsSyncKey = 'dalideck.syncKey';
const String prefsSyncState = 'dalideck.syncState';

Future<Store> loadStore() async {
  SharedPreferences p;
  try {
    p = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences init failed, using defaults: $e');
    final s = AppState.seed()..repair();
    final store = Store(s);
    store.saveRequested = () async {
      try {
        final pp = await SharedPreferences.getInstance();
        await pp.setString(prefsDataKey, jsonEncode(store.s.toJson()));
      } catch (_) {}
    };
    return store;
  }
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
    try {
      await p.setString(prefsDataKey, jsonEncode(store.s.toJson()));
    } catch (e) {
      debugPrint('Failed to persist DaliDeck data: $e');
    }
  };
  return store;
}

Future<void> persistData(Store store) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(prefsDataKey, jsonEncode(store.s.toJson()));
  } catch (e) {
    debugPrint('Failed to persist DaliDeck data: $e');
  }
}