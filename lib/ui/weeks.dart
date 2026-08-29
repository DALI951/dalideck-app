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

void addNoteOrLog(BuildContext context, String msg) => showSnack(context, msg);