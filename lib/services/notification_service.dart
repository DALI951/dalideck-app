import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n.dart';
import '../models.dart';

/// NotificationService — channel setup + time-window notification delivery.
///
/// Exact future/zoned scheduling needs the `timezone` package (zonedSchedule
/// takes a `TZDateTime`), which is intentionally NOT in pubspec and adding
/// deps is out of scope. Fallback used here: each `schedule*` method checks
/// whether a notification is "now due" inside a firing window and shows it
/// once, guarded by a SharedPreferences flag. Callers are the app start-up
/// (main.dart) and periodic Workmanager tasks; together they cover the day
/// without a timezone dependency.
class NotificationService {
  static const _channelId = 'dalideck_channel';
  static const _channelName = 'DaliDeck Notifications';
  static const _channelDescription =
      'Notifications for DaliDeck (classes, exams, habits, ayah)';

  static const _idClass = 9001;
  static const _idExam = 9101;
  static const _idHabit = 9201;
  static const _idAyah = 9301;

  static const _flagClass = 'ns_fired_class';
  static const _flagExam = 'ns_fired_exam';
  static const _flagHabit = 'ns_fired_habit';
  static const _flagAyah = 'ns_fired_ayah';

  static FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _pluginInited = false;
  static bool _channelReady = false;
  static SharedPreferences? _prefs;

  /// Creates the Android channel and initializes the plugin.
  static Future<void> init() async {
    await _ensurePrefs();
    await _ensurePlugin();
    await ensureChannel();
  }

  static Future<void> _ensurePrefs() async {
    if (_prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  static Future<void> _ensurePlugin() async {
    if (_pluginInited) return;
    _pluginInited = true;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    try {
      await _plugin
          .initialize(const InitializationSettings(android: androidSettings));
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  /// Same channel pattern as background_worker.dart.
  static Future<void> ensureChannel() async {
    if (_channelReady) return;
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      _channelReady = true;
    } catch (e) {
      debugPrint('NotificationService channel failed: $e');
    }
  }

  static void _applyLang(AppState s) {
    L.lang = (s.settings.lang == 'ar') ? 'ar' : 'en';
  }

  /// Schedules "Class starts in 10 min" for TODAY's classes. Delivering via
  /// window checks: fires when the pre-class moment is now (within ±window),
  /// once per class per day.
  static Future<void> scheduleTimetableNotifications(
    AppState s, {
    Duration window = const Duration(minutes: 20),
  }) async {
    if (s.settings.notif['enabled'] == false) return;
    if (s.settings.notif['tasks'] == false) return;
    _applyLang(s);
    await _ensurePrefs();
    await ensureChannel();

    final now = DateTime.now();
    final today = isoOf(now);
    final wd = todayIdx();
    final lead = (s.settings.notif['classLeadMin'] as int?) ?? 10;

    for (var i = 0; i < s.periods.length; i++) {
      final p = s.periods[i];
      final subId = cellAt(s, p.id, wd);
      if (subId == null || subId.isEmpty) continue;
      final t = _parseTime(p.time);
      if (t == null) continue;
      final classStart = DateTime(now.year, now.month, now.day, t.$1, t.$2);
      final target = classStart.subtract(Duration(minutes: lead));
      final flag = '$_flagClass:$today:${p.id}';
      if (_prefs?.getBool(flag) == true) continue;
      // Fire only while the "lead before class" moment is current.
      if (now.isBefore(target.subtract(const Duration(minutes: 5)))) continue;
      if (now.isAfter(target.add(window))) continue;
      final name = s.subjectName(subId) ?? '';
      await _show(_idClass + i, t('class_in_10'), name);
      await _prefs?.setBool(flag, true);
    }
  }

  /// Schedules a 1-day-before reminder for each exam, firing during the whole
  /// "tomorrow" day once per exam.
  static Future<void> scheduleExamReminders(AppState s) async {
    if (s.settings.notif['enabled'] == false) return;
    if (s.settings.notif['exams'] == false) return;
    _applyLang(s);
    await _ensurePrefs();
    await ensureChannel();

    final today = todayStr();
    final tomorrow = addDaysStr(today, 1);
    var i = 0;
    for (final e in s.exams) {
      if (e.date != tomorrow) {
        i++;
        continue;
      }
      final flag = '$_flagExam:${e.id}:$tomorrow';
      if (_prefs?.getBool(flag) == true) {
        i++;
        continue;
      }
      final name = s.subjectName(e.subjectId);
      await _show(
        _idExam + i,
        t('exam_tomorrow'),
        [e.title, if (name != null) name].join(' · '),
      );
      await _prefs?.setBool(flag, true);
      i++;
    }
  }

  /// Habit reminder at a given 'HH:MM' time (once per day).
  static Future<void> scheduleHabitReminder(AppState s, String time) async {
    if (s.settings.notif['enabled'] == false) return;
    if (s.settings.notif['habits'] == false) return;
    _applyLang(s);
    await _ensurePrefs();
    await ensureChannel();

    final now = DateTime.now();
    final today = isoOf(now);
    final t = _parseTime(time);
    if (t == null) return;
    final at = DateTime(now.year, now.month, now.day, t.$1, t.$2);
    final flag = '$_flagHabit:$today';
    if (_prefs?.getBool(flag) == true) return;
    if (now.isBefore(at.subtract(const Duration(minutes: 5)))) return;
    if (now.isAfter(at.add(const Duration(minutes: 20)))) return;
    await _show(_idHabit, t('habit_reminder'), today);
    await _prefs?.setBool(flag, true);
  }

  /// Daily ayah notification (once per day, default 07:00).
  static Future<void> scheduleDailyAyah(AppState s) async {
    if (s.settings.notif['enabled'] == false) return;
    _applyLang(s);
    await _ensurePrefs();
    await ensureChannel();

    final now = DateTime.now();
    final today = isoOf(now);
    final t = _parseTime(s.settings.notif['ayahTime'] as String? ?? '07:00');
    if (t == null) return;
    final at = DateTime(now.year, now.month, now.day, t.$1, t.$2);
    final flag = '$_flagAyah:$today';
    if (_prefs?.getBool(flag) == true) return;
    if (now.isBefore(at.subtract(const Duration(minutes: 5)))) return;
    if (now.isAfter(at.add(const Duration(minutes: 20)))) return;
    await _show(_idAyah, t('daily_ayah'), t('daily_ayah'));
    await _prefs?.setBool(flag, true);
  }

  static Future<void> _show(int id, String title, String body) async {
    await _ensurePlugin();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    try {
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('NotificationService show($id) failed: $e');
    }
  }

  /// Parses 'HH:MM' (first token) from a period time like '08:00 – 08:55'.
  static (int, int)? _parseTime(String s) {
    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    if (h == null || min == null) return null;
    return (h, min);
  }
}