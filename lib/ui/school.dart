import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import '../sync.dart';
import 'fields.dart';
import 'grades_utils.dart';

class SchoolView extends StatelessWidget {
  final Store store;
  final SyncEngine sync;
  const SchoolView({super.key, required this.store, required this.sync});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('school')),
          bottom: TabBar(
            isScrollable: true,
            labelColor: kAccent,
            unselectedLabelColor: kMuted,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: t('timetable')),
              Tab(text: t('tasks')),
              Tab(text: t('exams')),
              Tab(text: t('grades')),
              Tab(text: t('revision')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TimetableTab(store: store),
            TasksTab(store: store),
            ExamsTab(store: store),
            GradesTab(store: store),
            RevisionTab(store: store),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Timetable
class TimetableTab extends StatefulWidget {
  final Store store;
  const TimetableTab({super.key, required this.store});

  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab> {
  int _wd = todayIdx();

  @override
  Widget build(BuildContext context) {
    final s = widget.store.s;
    final wdNames = [0, 1, 2, 3, 4, 5, 6]
        .map((i) => t(['monday', 'tuesday', 'wednesday', 'thursday', 'friday',
            'saturday', 'sunday'][i]))
        .toList();
    final week = s.settings.weekOffset;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var w = 0; w < 2; w++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(w == 0 ? t('week_a') : t('week_b')),
                    selected: week == w,
                    onSelected: (_) {
                      if (week == w) return;
                      widget.store.mutate(() => s.settings.weekOffset = w);
                    },
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (var i = 0; i < 7; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(wdNames[i]),
                    selected: _wd == i,
                    onSelected: (_) => setState(() => _wd = i),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: s.periods.isEmpty
              ? const Center(child: Text('—', style: TextStyle(color: kMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: s.periods.length + 1,
                  itemBuilder: (context, i) {
                    if (i == s.periods.length) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.add, color: kMuted),
                          title: Text(t('add_period')),
                          onTap: () => _addPeriod(context),
                        ),
                      );
                    }
                    final p = s.periods[i];
                    final subId = cellAt(s, p.id, _wd);
                    final name = s.subjectName(subId);
                    return Card(
                      child: ListTile(
                        title: Text('${p.label} · ${p.time}'),
                        subtitle: name == null
                            ? Text(t('tap_cell'), style: const TextStyle(color: kMuted, fontSize: 12))
                            : null,
                        trailing: name == null
                            ? const Icon(Icons.add, color: kMuted)
                            : Text(name, style: const TextStyle(color: kAccent)),
                        onTap: () async {
                          final sel = await pickSubjectSheet(context, s);
                          if (sel == null) return;
                          widget.store.mutate(() {
                            if (sel.isEmpty) {
                              s.cells.remove('${p.id}:$_wd:$week');
                            } else {
                              s.cells['${p.id}:$_wd:$week'] = sel;
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _addPeriod(BuildContext context) async {
    final s = widget.store.s;
    final v = await showEntryDialog(
      context,
      t('add_period'),
      [
        EntryField('label', label: t('period_label'), initial: 'P${s.periods.length + 1}'),
        EntryField('time', label: t('period_time'), initial: '15:00'),
      ],
    );
    if (v == null) return;
    final label = v['label'] as String? ?? '';
    if (label.isEmpty) return;
    widget.store.mutate(() {
      s.periods.add(Period(uid())
        ..label = label
        ..time = v['time'] as String? ?? '');
    });
  }
}

// ------------------------------------------------------------------ Tasks
class TasksTab extends StatelessWidget {
  final Store store;
  const TasksTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final und = s.tasks.where((x) => !x.done).toList()
      ..sort((a, b) => (a.due ?? '9999').compareTo(b.due ?? '9999'));
    final don = s.tasks.where((x) => x.done).toList();
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (und.isEmpty && don.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t('empty_tasks'),
                  style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
            ),
          ...und.map((x) => _TaskTile(store: store, task: x)),
          ...don.map((x) => _TaskTile(store: store, task: x)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAccent,
        onPressed: () => _addTask(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addTask(BuildContext context) async {
    final s = store.s;
    final v = await showEntryDialog(
      context,
      t('add'),
      [
        EntryField('title', label: t('title'), hint: 'Review maths'),
        EntryField(
            'subjectId',
            label: t('subject'),
            type: 'select',
            options: ['', ...s.subjects.map((x) => x.id)],
            initial: ''),
        EntryField('due', label: t('due'), type: 'date', initial: addDaysStr(todayStr(), 1)),
        EntryField('prio',
            label: t('priority'),
            type: 'select',
            options: ['high', 'med', 'low'],
            initial: 'med'),
      ],
    );
    if (v == null) return;
    final title = v['title'] as String? ?? '';
    if (title.isEmpty) return;
    final id = v['subjectId'] as String? ?? '';
    store.mutate(() {
      s.tasks.add(Task(uid())
        ..title = title
        ..subjectId = id.isEmpty ? null : id
        ..due = v['due'] as String?
        ..prio = v['prio'] as String? ?? 'med');
    });
  }
}

class _TaskTile extends StatelessWidget {
  final Store store;
  final Task task;
  const _TaskTile({required this.store, required this.task});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final sub = s.subjectName(task.subjectId);
    final overdue = task.due != null && task.due!.compareTo(todayStr()) < 0 && !task.done;
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: task.done,
          activeColor: kAccent,
          onChanged: (_) => store.mutate(() {
            task.done = !task.done;
            task.doneDate = task.done ? todayStr() : null;
          }),
        ),
        title: Text(task.title,
            style: task.done
                ? const TextStyle(decoration: TextDecoration.lineThrough, color: kMuted)
                : null),
        subtitle: Text([
          if (task.due != null) task.due!,
          if (sub != null) sub,
        ].join(' · ')),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline,
              color: overdue ? kAccent : kMuted, size: 20),
          onPressed: () => store.mutate(() => s.tasks.remove(task)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Exams
class ExamsTab extends StatelessWidget {
  final Store store;
  const ExamsTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final sorted = List<Exam>.from(s.exams)..sort((a, b) => a.date.compareTo(b.date));
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t('empty_exams'),
                  style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
            ),
          ...sorted.map((e) => _ExamTile(store: store, exam: e)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAccent,
        onPressed: () => _addExam(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addExam(BuildContext context) async {
    final s = store.s;
    final v = await showEntryDialog(
      context,
      t('add'),
      [
        EntryField('title', label: t('title')),
        EntryField(
            'subjectId',
            label: t('subject'),
            type: 'select',
            options: ['', ...s.subjects.map((x) => x.id)],
            initial: ''),
        EntryField('date', label: t('date'), type: 'date', initial: addDaysStr(todayStr(), 7)),
        EntryField('term',
            label: t('status'),
            type: 'select',
            options: [t('term_1'), t('term_2'), t('term_3')],
            initial: t('term_1')),
      ],
    );
    if (v == null) return;
    final title = v['title'] as String? ?? '';
    if (title.isEmpty) return;
    final id = v['subjectId'] as String? ?? '';
    final term = _termNum(v['term'] as String?);
    store.mutate(() {
      s.exams.add(Exam(uid())
        ..title = title
        ..subjectId = id.isEmpty ? null : id
        ..date = (v['date'] as String?) ?? todayStr()
        ..term = term);
      syncRevisionList(s);
    });
  }
}

class _ExamTile extends StatelessWidget {
  final Store store;
  final Exam exam;
  const _ExamTile({required this.store, required this.exam});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final days = diffDays(todayStr(), exam.date);
    final past = days < 0;
    final col = past
        ? kMuted
        : (days <= 3
            ? Colors.redAccent
            : (days <= 7 ? Colors.orange : kMuted));
    return Card(
      child: ListTile(
        title: Text(exam.title),
        subtitle: Text([s.subjectName(exam.subjectId) ?? '', exam.date].join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(past ? 'D+${-days}' : 'D-$days',
                style: TextStyle(color: col, fontWeight: FontWeight.w700)),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: kMuted, size: 20),
              onPressed: () => store.mutate(() {
                s.exams.remove(exam);
                s.revision.removeWhere((r) => r.examId == exam.id);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Grades
class GradesTab extends StatefulWidget {
  final Store store;
  const GradesTab({super.key, required this.store});

  @override
  State<GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<GradesTab> {
  int? _term;

  @override
  Widget build(BuildContext context) {
    final s = widget.store.s;
    final sorted = List<Grade>.from(s.grades)..sort((a, b) => b.date.compareTo(a.date));
    final avg = moyenne(s, term: _term);
    final moyennes = allSubjectMoyennes(s, term: _term);

    // subjects that actually have grades (in the selected term)
    final withGrades = s.subjects
        .where((sub) => s.grades.any(
            (g) => g.subjectId == sub.id && (_term == null || g.term == _term)))
        .toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('semester_avg').toUpperCase(),
                      style: const TextStyle(
                          color: kAccent, fontSize: 11, letterSpacing: 1.5)),
                  const SizedBox(height: 6),
                  Text(_g(avg),
                      style:
                          const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _termChip(null, t('all_terms')),
                      _termChip(1, t('term_1')),
                      _termChip(2, t('term_2')),
                      _termChip(3, t('term_3')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (s.grades.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t('no_grades_yet'),
                  style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t('per_subject').toUpperCase(),
                    style: const TextStyle(
                        color: kMuted, fontSize: 12, letterSpacing: 1.2)),
                TextButton.icon(
                  onPressed: () => _targetCalc(context),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(t('target_calculator')),
                ),
              ],
            ),
            ...withGrades.map((sub) {
              final count = s.grades
                  .where((g) =>
                      g.subjectId == sub.id &&
                      (_term == null || g.term == _term))
                  .length;
              return Card(
                child: ListTile(
                  dense: true,
                  title: Text(sub.name),
                  subtitle: Text(t('grade_count').replaceFirst('%s', '$count')),
                  trailing: Text(_g(moyennes[sub.id]!) + '/20',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kAccent)),
                ),
              );
            }),
            const Divider(color: kMuted),
            ...sorted.map((g) => Card(
                  child: ListTile(
                    title:
                        Text('${s.subjectName(g.subjectId) ?? '-'} · ${g.label}'),
                    subtitle: Text(g.date),
                    trailing: Text('${g.score}/${g.max}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: (g.score / g.max >= 0.6) ? Colors.greenAccent : kAccent)),
                    onLongPress: () =>
                        widget.store.mutate(() => s.grades.remove(g)),
                  ),
                )),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAccent,
        onPressed: () => _addGrade(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _termChip(int? value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _term == value,
      onSelected: (_) => setState(() => _term = value),
    );
  }

  Future<void> _targetCalc(BuildContext context) {
    final s = widget.store.s;
    var tgt = 12.0;
    return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          title: Text(t('target_calculator')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t('target_grade')),
                  onChanged: (v) {
                    final d = double.tryParse(v);
                    if (d != null) tgt = d;
                    setDlg(() {});
                  },
                ),
                const SizedBox(height: 12),
                ...s.subjects
                    .where((sub) => s.grades.any((g) =>
                        g.subjectId == sub.id &&
                        (_term == null || g.term == _term)))
                    .map((sub) {
                  final need = neededOnNextTest(s, sub.id, tgt, term: _term);
                  String msg;
                  Color col;
                  if (need > 20) {
                    msg = t('target_impossible');
                    col = kMuted;
                  } else if (need <= 0) {
                    msg = t('already_above_target');
                    col = Colors.greenAccent;
                  } else {
                    msg =
                        t('needed_score').replaceFirst('%s', _g(need));
                    col = kAccent;
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(sub.name,
                              style: const TextStyle(fontSize: 13)),
                        ),
                        Text(msg,
                            style: TextStyle(fontSize: 13, color: col)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('ok')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addGrade(BuildContext context) async {
    final s = widget.store.s;
    final v = await showEntryDialog(
      context,
      t('add'),
      [
        EntryField('subjectId',
            label: t('subject'),
            type: 'select',
            options: ['', ...s.subjects.map((x) => x.id)],
            initial: ''),
        EntryField('label', label: t('label'), initial: 'Devoir 1'),
        EntryField('score', label: t('score'), type: 'number', initial: '12'),
        EntryField('max', label: t('max'), type: 'number', initial: '20'),
        EntryField('date', label: t('date'), type: 'date', initial: todayStr()),
      ],
    );
    if (v == null) return;
    widget.store.mutate(() {
      s.grades.add(Grade(uid())
        ..subjectId = (v['subjectId'] as String? ?? '').isEmpty
            ? null
            : v['subjectId'] as String?
        ..label = v['label'] as String? ?? ''
        ..score = double.tryParse(v['score'] as String? ?? '') ?? 12
        ..max = double.tryParse(v['max'] as String? ?? '') ?? 20
        ..date = v['date'] as String? ?? todayStr()
        ..term = int.parse(_termOf(v['date'] as String? ?? todayStr())));
    });
  }
}

// ---------------------------------------------------------------- Revision
class RevisionTab extends StatelessWidget {
  final Store store;
  const RevisionTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final tod = todayStr();
    final due = List<Revision>.from(
        s.revision.where((r) => !r.done && _dueFor(s, r).compareTo(tod) <= 0))
      ..sort((a, b) => _dueFor(s, a).compareTo(_dueFor(s, b)));
    final rest = s.revision.where((r) => !r.done && _dueFor(s, r).compareTo(tod) > 0).toList();
    final done = s.revision.where((r) => r.done).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (due.isEmpty && s.exams.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(t('no_exams'),
                style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
          ),
        if (due.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(t('due_now'),
                style: const TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ...due.map((r) => _RevTile(store: store, r: r)),
        ...rest.map((r) => _RevTile(store: store, r: r)),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Divider(color: kMuted),
          ...done.map((r) => _RevTile(store: store, r: r)),
        ],
      ],
    );
  }
}

class _RevTile extends StatelessWidget {
  final Store store;
  final Revision r;
  const _RevTile({required this.store, required this.r});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    Exam? ex;
    for (final e in s.exams) {
      if (e.id == r.examId) ex = e;
    }
    if (ex == null) return const SizedBox.shrink();
    final due = addDaysStr(ex.date, -r.offset);
    return Card(
      child: ListTile(
        dense: true,
        leading: IconButton(
          icon: Icon(r.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: r.done ? Colors.greenAccent : kMuted),
          onPressed: () => store.mutate(() {
            r.done = !r.done;
            r.doneDate = r.done ? todayStr() : null;
          }),
        ),
        title: Text('${ex.title} (D-${r.offset})',
            style: r.done
                ? const TextStyle(decoration: TextDecoration.lineThrough, color: kMuted)
                : null),
        subtitle: Text('$due · ${s.subjectName(ex.subjectId) ?? ''}'),
        onLongPress: () => store.mutate(() => s.revision.remove(r)),
      ),
    );
  }
}

// ------------------------------------------------------------------ utils
// Grade display: 15.00 -> '15', 13.50 -> '13.5', 14.66 -> '14.66'
String _g(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

String _dueFor(AppState s, Revision r) {
  for (final e in s.exams) {
    if (e.id == r.examId) return addDaysStr(e.date, -r.offset);
  }
  return todayStr();
}

int _termNum(String? s) {
  if (s == null) return 1;
  for (var i = 0; i < 3; i++) {
    if (s == t(['term_1', 'term_2', 'term_3'][i])) return i + 1;
  }
  return 1;
}

String _termOf(String iso) {
  final m = int.parse(iso.substring(5, 7));
  if (m >= 9) return '1';
  if (m >= 12) return '2';
  return '3';
}

// mirror of the web syncRevision(): ensure {7,3,1} entries per exam
void syncRevisionList(AppState s) {
  final valid = s.exams.map((e) => e.id).toSet();
  s.revision.removeWhere((r) => !valid.contains(r.examId));
  for (final e in s.exams) {
    for (final off in [7, 3, 1]) {
      var found = false;
      for (final r in s.revision) {
        if (r.examId == e.id && r.offset == off) {
          found = true;
          break;
        }
      }
      if (!found) {
        s.revision.add(Revision(e.id, off));
      }
    }
  }
}