import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models.dart';
import 'notification_service.dart';

const String updateDownloadTaskName = 'bg-download';
const String timetableNotifTaskName = 'timetable-notif';
const String habitReminderTaskName = 'habit-reminder';
const String dailyAyahTaskName = 'daily-ayah';

const String _channelId = 'dalideck_channel';
const String _channelName = 'DaliDeck Notifications';
const String _channelDescription = 'Notifications for DaliDeck updates';
const int updateNotificationId = 20000;

FlutterLocalNotificationsPlugin _notifications() =>
    FlutterLocalNotificationsPlugin();

Future<void> _ensureChannel() async {
  const channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.high,
  );
  await _notifications()
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == updateDownloadTaskName) {
      return _runUpdateDownloadTask(inputData);
    }
    if (task == timetableNotifTaskName) {
      return _runTimetableNotifications();
    }
    if (task == habitReminderTaskName) {
      return _runHabitReminder();
    }
    if (task == dailyAyahTaskName) {
      return _runDailyAyah();
    }
    return true;
  });
}

/// Loads the AppState JSON from SharedPreferences for background tasks that
/// have no in-memory Store.
Future<AppState?> _loadBackgroundState() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('dalideck.v1');
    if (raw == null || raw.isEmpty) return null;
    return AppState.fromJson(
        json.decode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

Future<bool> _runTimetableNotifications() async {
  final s = await _loadBackgroundState();
  if (s == null) return true;
  await NotificationService.scheduleTimetableNotifications(s);
  await NotificationService.scheduleExamReminders(s);
  return true;
}

Future<bool> _runHabitReminder() async {
  final s = await _loadBackgroundState();
  if (s == null) return true;
  final time = s.settings.notif['habitsTime'] as String? ?? '20:00';
  await NotificationService.scheduleHabitReminder(s, time);
  return true;
}

Future<bool> _runDailyAyah() async {
  final s = await _loadBackgroundState();
  if (s == null) return true;
  await NotificationService.scheduleDailyAyah(s);
  return true;
}

/// Registers the periodic notification tasks. Android's Workmanager minimum
/// periodic interval is 15 minutes, so each task re-runs at ~15-min cadence
/// and the NotificationService time-window logic fires only when due.
Future<void> registerNotificationTasks({bool force = false}) async {
  Future<void> reg(String name,
      {Duration initialDelay = const Duration(seconds: 15)}) async {
    try {
      await Workmanager().registerPeriodicTask(
        name,
        name,
        frequency: const Duration(minutes: 15),
        initialDelay: initialDelay,
        existingWorkPolicy:
            force ? ExistingWorkPolicy.replace : ExistingWorkPolicy.keep,
      );
    } catch (_) {}
  }

  await reg(timetableNotifTaskName, initialDelay: const Duration(seconds: 20));
  await reg(habitReminderTaskName,
      initialDelay: const Duration(minutes: 5));
  await reg(dailyAyahTaskName,
      initialDelay: const Duration(minutes: 10));
}

/// Downloads the update APK in a background task. Progress is mirrored to a
/// state file (`update_state.json` in app documents) so the in-app banner can
/// follow it, and to the progress notification. On completion the
/// notification transforms into "Ready to install" with an Install action
/// that opens the package installer even if the app was closed.
///
/// Android requires user consent for install (REQUEST_INSTALL_PACKAGES shows
/// the system screen). The completion notification must prompt the user —
/// silent auto-install is not possible.
Future<bool> _runUpdateDownloadTask(Map<String, dynamic>? inputData) async {
  final url = inputData?['url'] as String?;
  final version = inputData?['version'] as String?;
  if (url == null || version == null) return true;
  await _ensureChannel();

  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/dalideck_update.apk';
  final file = File(path);

  var startBytes = file.existsSync() ? file.lengthSync() : 0;
  var lastNotify = 0.0;
  var lastWrite = 0.0;
  var absoluteProgress = startBytes > 0 ? 0.0 : null;
  var absoluteTotal = 0;
  var received = startBytes;

  var lastSpeedBytes = startBytes;
  var lastSpeedTime = DateTime.now().millisecondsSinceEpoch;
  var currentSpeed = 0.0;

  void pushState(double p) {
    if (p < 1 && p - lastWrite >= 0.01) {
      lastWrite = p;
      unawaited(_writeUpdateState('downloading', p, path, version, url, speed: currentSpeed));
    }
    if (p - lastNotify >= 0.02 || p >= 1) {
      lastNotify = p;
      unawaited(_showDownloadProgress((p * 100).round()));
    }
  }

  try {
    if (startBytes > 0) {
      await _writeUpdateState('downloading', null, path, version, url);
    } else {
      await _writeUpdateState('downloading', 0, path, version, url);
      await _showDownloadProgress(0);
    }

    final response = await Dio().get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: {if (startBytes > 0) 'range': 'bytes=$startBytes-'},
        receiveTimeout: const Duration(seconds: 45),
      ),
    );

    final code = response.statusCode ?? 0;
    if (code == 416) {
      await _writeUpdateState('done', 1, path, version, url);
      await _showDownloadReady(version);
      return true;
    }
    if (code == 200) {
      try {
        file.deleteSync();
      } catch (_) {}
      startBytes = 0;
      received = 0;
    } else if (code != 206) {
      await _writeUpdateState('error', null, path, version, url);
      return false;
    }

    final body = response.data;
    if (body == null) {
      await _writeUpdateState('error', absoluteProgress, path, version, url,
          error: 'Empty response body');
      return false;
    }

    final contentLength =
        int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '') ?? 0;
    absoluteTotal = received + contentLength;
    if (absoluteTotal > 0) absoluteProgress = received / absoluteTotal;

    final raf = file.openSync(mode: FileMode.append);
    try {
      await for (final chunk in body.stream) {
        raf.writeFromSync(chunk);
        received += chunk.length;

        final now = DateTime.now().millisecondsSinceEpoch;
        final dt = (now - lastSpeedTime) / 1000.0;
        if (dt > 0.5 && received > lastSpeedBytes) {
          final instant = (received - lastSpeedBytes) / dt;
          currentSpeed = 0.7 * instant + 0.3 * currentSpeed;
          lastSpeedBytes = received;
          lastSpeedTime = now;
        }

        if (absoluteTotal > 0) {
          pushState(received / absoluteTotal);
        }
      }
    } finally {
      raf.closeSync();
    }

    await _writeUpdateState('done', 1, path, version, url);
    await _showDownloadReady(version);
    return true;
  } catch (e) {
    debugPrint('Background update download failed: $e');
    await _writeUpdateState('error', absoluteProgress, path, version, url,
        error: e.toString());
    return false;
  }
}

Future<void> _showDownloadProgress(int percent) async {
  final details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.low,
    priority: Priority.low,
    showProgress: true,
    progress: percent,
    onlyAlertOnce: true,
  );
  await _notifications().show(
    updateNotificationId,
    'Downloading update…',
    'DaliDeck $percent%',
    NotificationDetails(android: details),
    payload: json.encode({'type': 'update_install'}),
  );
}

Future<void> _showDownloadReady(String version) async {
  final details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
    actions: [
      AndroidNotificationAction('install', 'Install', showsUserInterface: true),
    ],
  );
  await _notifications().show(
    updateNotificationId,
    'Update ready',
    'DaliDeck v$version downloaded — tap to install',
    NotificationDetails(android: details),
    payload: json.encode({'type': 'update_install'}),
  );
}

Future<String> updateStateFilePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/update_state.json';
}

Future<void> _writeUpdateState(String state, double? progress, String path,
    String version, String? url, {String? error, double speed = 0}) async {
  try {
    final file = File(await updateStateFilePath());
    file.writeAsStringSync(json.encode({
      'state': state,
      'progress': progress,
      'speed': speed,
      'path': path,
      'version': version,
      'url': url,
      if (error != null) 'error': error,
    }));
  } catch (_) {}
}
