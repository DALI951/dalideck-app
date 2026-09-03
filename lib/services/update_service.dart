import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAppVersion = '0.2.6';

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
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UpdateDialog(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          onLater: () async {
            try {
              final p = await SharedPreferences.getInstance();
              await p.setString(_dismissedKey, latestVersion);
            } catch (e) {
              debugPrint('Failed to save update dismiss state: $e');
            }
          },
        ),
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

class _UpdateDialog extends StatefulWidget {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final VoidCallback onLater;

  const _UpdateDialog({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.onLater,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  final Dio _dio = Dio();

  bool _downloading = false;
  bool _failed = false;
  double _progress = 0;
  double _speed = 0;
  String _status = '';

  int _lastBytes = 0;
  int _lastTime = 0;

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _failed = false;
      _progress = 0;
      _speed = 0;
      _lastBytes = 0;
      _lastTime = 0;
      _status = 'Downloading... 0%';
    });

    try {
      final dir = await getTemporaryDirectory();
      final savePath =
          '${dir.path}${Platform.pathSeparator}dalideck_update.apk';

      await _dio.download(
        widget.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (!mounted) return;

          final now = DateTime.now().millisecondsSinceEpoch;
          if (_lastTime != 0) {
            final dt = (now - _lastTime) / 1000.0;
            if (dt > 0) {
              _speed = (received - _lastBytes) / dt;
            }
          }
          _lastBytes = received;
          _lastTime = now;

          final progress = total > 0 ? received / total : 0.0;
          setState(() {
            _progress = progress;
            _status = 'Downloading... ${(progress * 100).toStringAsFixed(0)}%'
                ' | ${_formatSpeed(_speed)}';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = 1;
        _status = 'Downloading... 100%';
      });

      await OpenFile.open(savePath);
    } catch (e) {
      debugPrint('Update download failed: $e');
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _failed = true;
        _status = 'Download failed.';
      });
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${bytesPerSecond.toStringAsFixed(0)} B/s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progressPercent = (_progress * 100).clamp(0.0, 100.0);

    return AlertDialog(
      title: const Text('Update Available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version ${widget.latestVersion} is available. '
            "You're on ${widget.currentVersion}.",
          ),
          const SizedBox(height: 16),
          if (_downloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${progressPercent.toStringAsFixed(0)}% | ${_formatSpeed(_speed)}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ] else if (_failed) ...[
            Text(
              _status,
              style: TextStyle(color: cs.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _downloading
              ? null
              : () {
                  widget.onLater();
                  Navigator.of(context).pop();
                },
          child: const Text('Remind Me Later'),
        ),
        TextButton(
          onPressed: _downloading ? null : _startDownload,
          child: _downloading
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Downloading...'),
                  ],
                )
              : Text(_failed ? 'Retry' : 'Install Now'),
        ),
      ],
    );
  }
}
