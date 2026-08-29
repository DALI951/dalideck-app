import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import 'fields.dart';
import 'weeks.dart';

class TutoringView extends StatelessWidget {
  final Store store;
  const TutoringView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final tod = todayStr();
    const goal = 300; // 5h/wk
    final ws = weekDays();
    var weekMin = 0, todayMin = 0;
    for (final tu in s.tutoring) {
      if (ws.contains(tu.date)) weekMin += tu.mins;
      if (tu.date == tod) todayMin += tu.mins;
    }
    final sorted = List<Tutoring>.from(s.tutoring)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: Text(t('tutoring'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t('week')} $weekMin/${goal} ${t('minutes')}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (weekMin / goal).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: kPanel,
                    color: kAccent,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t('empty_sessions'),
                  style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
            ),
          ...sorted.map((tu) => Card(
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.menu_book_outlined, color: kMuted),
                  title: Text(s.subjectName(tu.subjectId) ?? (tu.note.isEmpty ? '—' : tu.note)),
                  subtitle: Text([tu.date, '${tu.mins} min', tu.note].join(' · ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: kMuted, size: 20),
                    onPressed: () => store.mutate(() => s.tutoring.remove(tu)),
                  ),
                ),
              )),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAccent,
        onPressed: () => _addSession(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addSession(BuildContext context) async {
    final s = store.s;
    final v = await showEntryDialog(
      context,
      t('add'),
      [
        EntryField('subjectId',
            label: t('subject'),
            type: 'select',
            options: ['', ...s.subjects.map((x) => x.id)],
            initial: ''),
        EntryField('mins', label: t('minutes'), type: 'number', initial: '60'),
        EntryField('date', label: t('date'), type: 'date', initial: todayStr()),
        EntryField('note', label: t('note')),
      ],
    );
    if (v == null) return;
    store.mutate(() {
      s.tutoring.add(Tutoring(uid())
        ..subjectId = (v['subjectId'] as String? ?? '').isEmpty
            ? null
            : v['subjectId'] as String?
        ..mins = int.tryParse(v['mins'] as String? ?? '') ?? 60
        ..date = v['date'] as String? ?? todayStr()
        ..note = v['note'] as String? ?? '');
    });
  }
}