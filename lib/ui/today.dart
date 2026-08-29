import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';

class TodayView extends StatelessWidget {
  final Store store;
  const TodayView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final c = s.coll('cells');
    final cells = c is Map<String, Object?> ? c : const <String, Object?>{};
    final wd = todayIdx();
    final tod = todayStr();
    final dayDiff = diffDays(s.settings.schoolStart, tod);

    // today's lessons
    final lessons = s.periods
        .map((p) => (p, cells['${p.id}:$wd'] as String?))
        .where((x) => x.$2 != null && x.$2!.isNotEmpty)
        .toList();

    // this month money
    final ym = tod.substring(0, 7);
    var inM = 0, outM = 0;
    for (final m in s.money) {
      if (m.date.startsWith(ym)) {
        if (m.type == 'in')
          inM += m.amount;
        else
          outM += m.amount;
      }
    }
    final wallet = walletTotal(s);
    final cur = s.settings.currency;

    // next exam
    Exam? next;
    var nextUntil = 0;
    for (final e in s.exams) {
      if (e.date.compareTo(tod) >= 0) {
        final d = diffDays(tod, e.date);
        if (next == null || d < nextUntil) {
          next = e;
          nextUntil = d;
        }
      }
    }

    // today's tasks (due today or overdue, not done)
    final todayTasks =
        s.tasks.where((x) => !x.done && x.due != null && x.due!.compareTo(tod) <= 0).toList();

    // revision due
    final revDue = s.revision.where((r) {
      final e = _findExam(s, r.examId);
      if (e == null || r.done) return false;
      return addDaysStr(e.date, -r.offset).compareTo(tod) <= 0;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(t('today')), actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: kMuted),
          onPressed: () => showSnack(context, t('no_class_today')),
        )
      ]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Metric(
              label: t('days'), value: '$dayDiff', sub: '${s.settings.schoolStart}'),
          _Metric(
              label: t('this_month'),
              value: '${fmtM(outM)} $cur',
              sub: '${t('in')} ${fmtM(inM)} · ${t('out')} ${fmtM(outM)}'),
          _Metric(label: t('wallet'), value: '${fmtM(wallet)} $cur',
              sub: s.accounts.map((a) => a.name).join(', ')),
          if (next != null)
            _Metric(
                label: t('next_exam'),
                value: '${next.title} $nextUntil ${t('days')}',
                sub: s.subjectName(next.subjectId) ?? ''),
          const SizedBox(height: 8),
          _Section(t('today_classes')),
          if (lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(t('no_class_today'), style: const TextStyle(color: kMuted)),
            )
          else
            ...lessons.map((x) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text('${x.$1.label} · ${x.$1.time}'),
                    trailing: Text(s.subjectName(x.$2) ?? ''),
                  ),
                )),
          _Section(t('tasks')),
          if (todayTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(t('empty_tasks'), style: const TextStyle(color: kMuted)),
            )
          else
            ...todayTasks.map((x) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(x.title),
                    trailing: const Icon(Icons.priority_high, color: kAccent),
                  ),
                )),
          _Section(t('revision')),
          if (revDue.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(t('no_exams'), style: const TextStyle(color: kMuted)),
            )
          else
            ...revDue.map((r) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(s.subjectName(_findExam(s, r.examId)?.subjectId) ?? ''),
                    trailing: Text('D-${r.offset}', style: const TextStyle(color: kAccent)),
                  ),
                )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Exam? _findExam(AppState s, String id) {
    for (final e in s.exams) {
      if (e.id == id) return e;
    }
    return null;
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  const _Metric({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(color: kAccent, fontSize: 11, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: kMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6, left: 4, right: 4),
      child: Text(text.toUpperCase(),
          style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.2)),
    );
  }
}