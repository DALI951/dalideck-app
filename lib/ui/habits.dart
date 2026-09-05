import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import '../services/notification_service.dart';
import 'fields.dart';
import 'weeks.dart';

const _red = Color(0xFFEF4444);
const _cellSize = 32.0;

class HabitsView extends StatelessWidget {
  final Store store;
  const HabitsView({super.key, required this.store});

  static const _dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    return Scaffold(
      appBar: AppBar(title: Text(t('habits'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _WeeklyMatrix(store: store),
          const SizedBox(height: 14),
          _ReminderRow(store: store),
          const SizedBox(height: 14),
          if (s.habits.isEmpty)
            _EmptyState(onAdd: () => _addHabit(context))
          else
            ...[
              Text(t('week').toUpperCase(),
                  style: const TextStyle(
                      color: kMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              ...s.habits.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HabitCard(store: store, habit: h),
                  )),
            ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _red,
        onPressed: () => _addHabit(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addHabit(BuildContext context) async {
    final s = store.s;
    final v = await showEntryDialog(
      context,
      t('add'),
      [EntryField('name', label: t('name'), hint: '30 min revision')],
    );
    if (v == null) return;
    final name = v['name'] as String? ?? '';
    if (name.isEmpty) return;
    store.mutate(() => s.habits.add(Habit(uid())..name = name));
  }
}

class _WeeklyMatrix extends StatelessWidget {
  final Store store;
  const _WeeklyMatrix({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final ws = weekDays();
    final today = todayIdx();
    final cols = HabitsView._dayKeys.map((k) => t(k)).toList();
    const nameW = 84.0;

    if (s.habits.isEmpty) return const SizedBox.shrink();

    return Card(
      color: kPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('habits').toUpperCase(),
                style: const TextStyle(
                    color: kMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            // header row
            Row(
              children: [
                const SizedBox(width: nameW),
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        cols[i][0].toUpperCase(),
                        style: TextStyle(
                          color: i == today ? _red : kMuted,
                          fontSize: 12,
                          fontWeight:
                              i == today ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final h in s.habits) ...[
              _matrixHabitRow(h, ws, today, nameW),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _matrixHabitRow(Habit h, List<String> ws, int today, double nameW) {
    return Row(
      children: [
        SizedBox(
          width: nameW,
          child: Text(
            h.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: _matrixCell(
                  done: h.days.contains(ws[i]), isToday: i == today),
            ),
          ),
      ],
    );
  }

  Widget _matrixCell({required bool done, required bool isToday}) {
    return Container(
      width: _cellSize,
      height: _cellSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? _red
            : (isToday ? _red.withOpacity(0.15) : kPanel),
        border: Border.all(
          color: isToday
              ? (done ? _red : _red.withOpacity(0.6))
              : kBg,
          width: isToday ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Store store;
  final Habit habit;
  const _HabitCard({required this.store, required this.habit});

  static const _dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final ws = weekDays();
    final today = todayIdx();
    final streak = habitStreak(habit);
    final cols = _dayKeys.map((k) => t(k)).toList();

    return Card(
      color: kPanel,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(habit.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                _StreakPill(streak: streak),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatPill(
                  label: t('best_streak'),
                  value: '${bestStreak(habit)}d',
                  icon: Icons.local_fire_department,
                ),
                _StatPill(
                  label: t('completion_rate'),
                  value: '${(completionRate(habit) * 100).round()}%',
                  icon: Icons.percent,
                ),
                _StatPill(
                  label: t('total_done'),
                  value: '${totalDone(habit)}',
                  icon: Icons.check_circle_outline,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Heatmap(store: store, habit: habit),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < 7; i++)
                            Expanded(
                              child: Center(
                                child: Text(
                                  cols[i][0].toUpperCase(),
                                  style: TextStyle(
                                    color: i == today ? _red : kMuted,
                                    fontSize: 11,
                                    fontWeight: i == today
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          for (var i = 0; i < 7; i++)
                            Expanded(
                              child: Center(
                                child: _ToggleCell(
                                  habit: habit,
                                  day: ws[i],
                                  isToday: i == today,
                                  onTap: () => store.mutate(() {
                                    final d = ws[i];
                                    if (habit.days.contains(d)) {
                                      habit.days =
                                          List<String>.from(habit.days)
                                            ..remove(d);
                                    } else {
                                      habit.days = [...habit.days, d];
                                    }
                                  }),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, color: kMuted, size: 18),
                  onPressed: () => _editHabit(context),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: kMuted, size: 18),
                  onPressed: () => store.mutate(() => s.habits.remove(habit)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editHabit(BuildContext context) async {
    final v = await showEntryDialog(
      context,
      t('add'),
      [EntryField('name', label: t('name'), initial: habit.name)],
    );
    if (v == null) return;
    final name = v['name'] as String? ?? '';
    if (name.isEmpty) return;
    store.mutate(() => habit.name = name);
  }
}

class _ToggleCell extends StatelessWidget {
  final Habit habit;
  final String day;
  final bool isToday;
  final VoidCallback onTap;
  const _ToggleCell(
      {required this.habit,
      required this.day,
      required this.isToday,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = habit.days.contains(day);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: _cellSize,
        height: _cellSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done
              ? _red
              : (isToday ? _red.withOpacity(0.12) : kBg),
          border: Border.all(
            color: isToday
                ? (done ? _red : _red.withOpacity(0.6))
                : kBg,
            width: isToday ? 2 : 1,
          ),
          boxShadow: isToday
              ? [BoxShadow(color: _red.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)]
              : null,
        ),
        alignment: Alignment.center,
        child: done ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  final int streak;
  const _StreakPill({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '🔥 ${streak}d',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.local_fire_department, size: 56, color: _red),
          const SizedBox(height: 16),
          const Text('No habits yet',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(t('empty_tasks'),
              style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add your first habit'),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final Store store;
  const _ReminderRow({required this.store});

  Future<void> _pick(BuildContext context) async {
    final s = store.s;
    final current = s.settings.notif['habitsTime'] as String? ?? '20:00';
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final h = picked.hour.toString().padLeft(2, '0');
    final m = picked.minute.toString().padLeft(2, '0');
    final timeStr = '$h:$m';
    store.mutate(() => s.settings.notif['habitsTime'] = timeStr);
    await NotificationService.scheduleHabitReminder(s, timeStr);
    if (context.mounted) showSnack(context, '${t('set_reminder')} $timeStr');
  }

  @override
  Widget build(BuildContext context) {
    final current = store.s.settings.notif['habitsTime'] as String? ?? '20:00';
    return Card(
      color: kPanel,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: const Icon(Icons.alarm, color: _red),
        title: Text(t('habit_reminder_time')),
        subtitle: Text(current, style: const TextStyle(color: kMuted)),
        trailing: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _red),
          onPressed: () => _pick(context),
          icon: const Icon(Icons.access_time, size: 15),
          label: Text(t('set_reminder')),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _red.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _red),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  final Store store;
  final Habit habit;
  const _Heatmap({required this.store, required this.habit});

  static const _cellSize = 14.0;
  static const _cellGap = 3.0;
  static const _laneW = 20.0;
  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _monthsAr = [
    'جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان',
    'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  double get _colTotal => _cellSize + _cellGap;
  List<String> get _days => const [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];

  @override
  Widget build(BuildContext context) {
    final data = heatmapData(habit, 12);
    final today = DateTime.now();
    final oldest = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: 7 * 12 + today.weekday - 1));
    final months = L.lang == 'ar' ? _monthsAr : _monthsEn;

    String? monthFor(int c) {
      final d = oldest.add(Duration(days: c * 7));
      final prev = c == 0 ? null : oldest.add(Duration(days: (c - 1) * 7));
      if (c == 0 || prev == null || prev.month != d.month) return months[d.month - 1];
      return null;
    }

    final lane = const SizedBox(width: _laneW);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              lane,
              for (var c = 0; c < 12; c++)
                SizedBox(
                  width: _colTotal,
                  child: monthFor(c) == null
                      ? null
                      : Text(
                          monthFor(c)!,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                              color: kMuted, fontSize: 9,
                              fontWeight: FontWeight.w700),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < 7; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: _cellGap),
              child: Row(
                children: [
                  SizedBox(
                    width: _laneW,
                    child: Text(
                      t(_days[r])[0].toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kMuted, fontSize: 9),
                    ),
                  ),
                  for (var c = 0; c < 12; c++)
                    _cell(
                      context: context,
                      count: data[c * 7 + r],
                      date: oldest.add(Duration(days: c * 7 + r)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(
      {required BuildContext context,
      required int count,
      required DateTime date}) {
    final dayStr = isoOf(date);
    final done = count > 0;
    return Padding(
      padding: const EdgeInsets.only(right: _cellGap),
      child: GestureDetector(
        onLongPress: () => _recover(context: context, dateStr: dayStr),
        child: Container(
          width: _cellSize,
          height: _cellSize,
          decoration: BoxDecoration(
            color: done
                ? (count >= 3
                    ? kAccent
                    : count == 2
                        ? kAccent.withValues(alpha: 0.6)
                        : kAccent.withValues(alpha: 0.32))
                : kPanel,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  void _recover({required BuildContext context, required String dateStr}) {
    if (dateStr.compareTo(todayStr()) >= 0) return;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPanel,
        title: Text(t('recover_day')),
        content: Text(t('confirm_recover').replaceFirst('%s', dateStr)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('ok')),
          ),
        ],
      ),
    ).then((yes) {
      if (yes != true || !context.mounted) return;
      store.mutate(() {
        if (habit.days.contains(dateStr)) {
          habit.days = List<String>.from(habit.days)
            ..removeWhere((x) => x == dateStr);
        } else {
          habit.days = [...habit.days, dateStr];
        }
      });
    });
  }
}
