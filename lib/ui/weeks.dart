import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';

// Monday of the current week, as ISO date
String weekStartStr() {
  final d = DateTime.now().subtract(Duration(days: todayIdx()));
  return isoOf(d);
}

List<String> weekDays() {
  final monday = DateTime.now().subtract(Duration(days: todayIdx()));
  return List.generate(7, (i) => isoOf(monday.add(Duration(days: i))));
}

// days-on streak ending today or yesterday
int habitStreak(Habit h) {
  var streak = 0;
  var d = DateTime.now();
  if (!h.days.contains(isoOf(d))) d = d.subtract(const Duration(days: 1));
  while (h.days.contains(isoOf(d))) {
    streak++;
    d = d.subtract(const Duration(days: 1));
  }
  return streak;
}

int weekDone(AppState s) {
  final ws = weekDays().toSet();
  var count = 0;
  for (final h in s.habits) {
    for (final d in h.days) {
      if (ws.contains(d)) count++;
    }
  }
  return count;
}

int weekTotal(AppState s) => s.habits.length * 7;

int totalDone(Habit h) => h.days.length;

// GitHub-style heatmap counts: 7*weeksBack ints, row-major (week-oldest
// first, Mon..Sun per column), each cell = number of completions on that
// exact ISO date (multiple check-ins on one day count up).
List<int> heatmapData(Habit h, int weeksBack) {
  final days = <String, int>{};
  for (final d in h.days) {
    days[d] = (days[d] ?? 0) + 1;
  }
  final today = DateTime.now();
  final oldest = DateTime(
          today.year, today.month, today.day)
      .subtract(Duration(days: 7 * weeksBack + today.weekday - 1));
  return List.generate(7 * weeksBack, (i) {
    final d = isoOf(oldest.add(Duration(days: i)));
    return days[d] ?? 0;
  });
}

// Longest run of consecutive dates in h.days (deduped by date).
int bestStreak(Habit h) {
  final dates = h.days.map(dateOf).toSet().toList()..sort();
  if (dates.isEmpty) return 0;
  var best = 1;
  var run = 1;
  for (var i = 1; i < dates.length; i++) {
    if (dates[i].difference(dates[i - 1]).inDays == 1) {
      run++;
      if (run > best) best = run;
    } else {
      run = 1;
    }
  }
  return best;
}

// % (0.0-1.0) of the last `days` calendar days completed (distinct dates).
// 0.0 if nothing in range (matches Unit C test: edge — completionRate 0.0).
double completionRate(Habit h, {int days = 30}) {
  final now = DateTime.now();
  final distinct = h.days.map(dateOf).where((d) {
    final diff = now.difference(d).inDays;
    return diff >= 0 && diff < days;
  }).toSet();
  if (distinct.isEmpty) return 0.0;
  return distinct.length / days;
}

void addNoteOrLog(BuildContext context, String msg) => showSnack(context, msg);