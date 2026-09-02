import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const String kAppVersion = '0.2.4';

class UpdateService {
  static const _repo = 'DALI951/dalideck-app';
  static const _apiUrl =
      'https://api.github.com/repos/$_repo/releases/latest';
  static const _releasesUrl =
      'https://github.com/$_repo/releases/latest';

  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      if (tagName.isEmpty) return;

      final latestVersion = tagName.replaceFirst('v', '');
      if (_compareVersions(latestVersion, kAppVersion) <= 0) return;

      if (!context.mounted) return;
      _showUpdateDialog(context, latestVersion);
    } catch (_) {
      // Silent fail — don't bother the user on network errors.
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

  void _showUpdateDialog(BuildContext context, String latestVersion) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update available'),
        content: Text('A new version (v$latestVersion) is available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(_releasesUrl));
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
