import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_download_manager.dart';

class AppVersion {
  static String _cached = '0.0.0';
  static String get current => _cached;
  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _cached = info.version;
    } catch (_) {}
  }
}

class UpdateService {
  static const _repo = 'DALI951/dalideck-app';
  static const _apiUrl =
      'https://api.github.com/repos/$_repo/releases/latest';
  static const _dismissedKey = 'dismissed_version';
  static const _lastCheckKey = 'last_update_check';

  final Dio _dio = Dio();

  static final UpdateService _instance = UpdateService._();
  factory UpdateService() => _instance;
  UpdateService._();

  Future<bool> checkForUpdate(BuildContext context,
      {bool force = false}) async {
    if (kIsWeb) return false;

    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('SharedPreferences init failed in update check: $e');
      return false;
    }

    if (!force) {
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastCheck < 30 * 60 * 1000) return false;
    }

    try {
      final response = await _dio.get(
        _apiUrl,
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );
      final data = response.data as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final assets = (data['assets'] as List?) ?? [];

      final apkAsset = assets.cast<Map<String, dynamic>?>().firstWhere(
            (a) => (a?['name'] as String?)?.endsWith('.apk') == true,
            orElse: () => null,
          );

      if (apkAsset == null) return false;

      final downloadUrl = apkAsset['browser_download_url'] as String;
      final latestVersion = tagName.replaceFirst('v', '');

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_compareVersions(latestVersion, currentVersion) <= 0) return false;

      try {
        await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        debugPrint('Failed to save update check state: $e');
      }

      if (!force) {
        final dismissed = prefs.getString(_dismissedKey);
        if (dismissed == latestVersion) return false;
      }

      if (!context.mounted) return false;

      UpdateDownloadManager().start(downloadUrl, latestVersion);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update downloading…')),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map(int.tryParse).toList();
    final bParts = b.split('.').map(int.tryParse).toList();
    final len = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < len; i++) {
      final av = i < aParts.length ? (aParts[i] ?? 0) : 0;
      final bv = i < bParts.length ? (bParts[i] ?? 0) : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}
