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
    final wd = todayIdx();
    final tod = todayStr();
    final dayDiff = diffDays(s.settings.schoolStart, tod);

    // today's lessons (A/B week aware)
    final lessons = s.periods
        .map((p) => (p, cellAt(s, p.id, wd)))
        .where((x) => x.$2 != null && x.$2!.isNotEmpty)
        .toList();

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

    // exams within the next 7 days (inclusive)
    final soonExams = s.exams
        .where((e) {
          final d = diffDays(tod, e.date);
          return d >= 0 && d <= 7;
        })
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // distinct recommended subjects for the study plan
    final focusLabels = <String>[];
    for (final e in soonExams) {
      final label = s.subjectName(e.subjectId) ?? e.title;
      if (label.isEmpty) continue;
      if (focusLabels.contains(label)) continue;
      focusLabels.add(label);
    }

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
          if (soonExams.isNotEmpty) ...[
            _Section(t('upcoming_exams')),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: soonExams.map((e) {
                    final d = diffDays(tod, e.date);
                    final col = d <= 3 ? Colors.redAccent : Colors.orange;
                    final name = s.subjectName(e.subjectId) ?? e.title;
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.event, size: 20, color: col),
                      title: Text(name),
                      subtitle: Text(e.date),
                      trailing: Text(
                        d == 0
                            ? t('exam_due_today').replaceFirst('%s', name)
                            : t('exam_in_days')
                                .replaceFirst('%s', name)
                                .replaceFirst('%s', '$d'),
                        style: TextStyle(
                            color: col,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            _Section(t('study_plan')),
            if (focusLabels.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(t('no_exams'), style: const TextStyle(color: kMuted)),
              )
            else
              ...focusLabels.map((lab) => Card(
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.menu_book, color: kAccent),
                      title: Text(t('study_recommendation')
                          .replaceFirst('%s', lab)),
                    ),
                  )),
          ],
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