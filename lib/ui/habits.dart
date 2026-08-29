import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import 'fields.dart';
import 'weeks.dart';

class HabitsView extends StatelessWidget {
  final Store store;
  const HabitsView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final ws = weekDays();
    final wnames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
        .map((k) => t(k))
        .toList();
    final total = weekTotal(s);
    final done = weekDone(s);
    final pct = total == 0 ? 0.0 : done / total;

    return Scaffold(
      appBar: AppBar(title: Text(t('habits'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t('week')} · $done/$total',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: kPanel,
                    color: kAccent,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          if (s.habits.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t('empty_tasks'),
                  style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
            ),
          ...s.habits.map((h) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(h.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Text('${t('streak')} ${habitStreak(h)}',
                          style: const TextStyle(color: kAccent, fontSize: 12)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: kMuted, size: 18),
                        onPressed: () => store.mutate(() => s.habits.remove(h)),
                      ),
                    ]),
                    Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Column(children: [
                                Text(wnames[i][0].toUpperCase(),
                                    style: const TextStyle(color: kMuted, fontSize: 10)),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => store.mutate(() {
                                    final d = ws[i];
                                    if (h.days.contains(d)) {
                                      h.days.remove(d);
                                    } else {
                                      h.days.add(d);
                                    }
                                  }),
                                  child: Container(
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: h.days.contains(ws[i])
                                          ? kAccent
                                          : kBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: kPanel),
                                    ),
                                    child: h.days.contains(ws[i])
                                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ]),
                ),
              )),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAccent,
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