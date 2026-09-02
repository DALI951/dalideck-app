import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
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
    final nameW = 84.0;

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

  Widget _matrixHabitRow(
      Habit h, List<String> ws, int today, double nameW) {
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
              child: _matrixCell(done: h.days.contains(ws[i]), isToday: i == today),
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
            : (isToday ? _red.withValues(alpha: 0.15) : kPanel),
        border: Border.all(
          color: isToday
              ? (done ? _red : _red.withValues(alpha: 0.6))
              : kBg,
          width: isToday ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
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
            const SizedBox(height: 12),
            // day labels + toggles side by side, right aligned to edit/delete row
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
                                          List<String>.from(habit.days)..remove(d);
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
    final s = store.s;
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
              : (isToday ? _red.withValues(alpha: 0.12) : kBg),
          border: Border.all(
            color: isToday
                ? (done ? _red : _red.withValues(alpha: 0.6))
                : kBg,
            width: isToday ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: done
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
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
        color: _red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _red.withValues(alpha: 0.5)),
      ),
      child: Text(
        '🔥 ${streak}d',
        style: const TextStyle(
          color: _red,
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
          const Icon(Icons.done_all, size: 56, color: kMuted),
          const SizedBox(height: 16),
          Text(t('habits'),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(t('empty_tasks'),
              style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text('Add your first habit'),
          ),
        ],
      ),
    );
  }
}
