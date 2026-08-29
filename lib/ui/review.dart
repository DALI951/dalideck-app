import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import 'weeks.dart';

class ReviewView extends StatefulWidget {
  final Store store;
  const ReviewView({super.key, required this.store});

  @override
  State<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<ReviewView> {
  late TextEditingController _plan;

  @override
  void initState() {
    super.initState();
    final s = widget.store.s;
    final wk = weekStartStr();
    final entry = ((s.review['weeks'] as Map?)?[wk] as Map?) ?? <String, dynamic>{};
    _plan = TextEditingController(text: entry['plan'] as String? ?? '');
  }

  @override
  void dispose() {
    _plan.dispose();
    super.dispose();
  }

  Map<String, dynamic> _entry() {
    final w = widget.store.s.review['weeks'] as Map?;
    if (w == null) return <String, dynamic>{};
    final e = w[weekStartStr()];
    return e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
  }

  void _save({bool markDone = false}) {
    widget.store.mutate(() {
      final s = widget.store.s;
      final w = Map<String, dynamic>.from((s.review['weeks'] as Map?) ?? {});
      final wk = weekStartStr();
      final e = Map<String, dynamic>.from((w[wk] as Map?) ?? {});
      if (markDone) {
        e['reviewed'] = !(e['reviewed'] == true);
      }
      if (_plan.text.isNotEmpty || e.containsKey('plan')) {
        e['plan'] = _plan.text;
      }
      w[wk] = e;
      s.review['weeks'] = w;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.s;
    final wk = weekStartStr();
    final entry = _entry();
    final plan = entry['plan'] as String? ?? '';
    final reviewed = entry['reviewed'] == true;
    final weeks = (s.review['weeks'] as Map?) ?? const {};

    final tod = todayStr();
    final examsWeek = s.exams.where((e) {
      final d = diffDays(tod, e.date);
      return d >= 0 && d <= 7;
    }).length;
    final tasksOpen = s.tasks.where((x) => !x.done).length;

    final sortedWeeks = weeks.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(t('review'))),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('${t('this_week_review')} — $wk',
                style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${t('exams')} 7d: $examsWeek · ${t('tasks')} ${t('due_now').toLowerCase()}: $tasksOpen',
                    style: const TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('plan_week'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _plan,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: '…'),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: reviewed,
                    activeColor: kAccent,
                    title: Text(t('mark_reviewed')),
                    onChanged: (_) => _save(markDone: true),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () {
                        _save();
                        showSnack(context, t('ok'));
                      },
                      child: Text(t('save')),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text(t('review').toUpperCase(),
                style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.2)),
            if (weekCount(s) == 0)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(t('empty_review'),
                    style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
              ),
            ...sortedWeeks.map((e) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text('${e.key}'),
                    subtitle: Text(_mapPlan(e.value)),
                    trailing: _isReviewed(e.value)
                        ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                        : const Icon(Icons.circle_outlined, color: kMuted),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  int weekCount(AppState s) {
    final w = s.review['weeks'];
    if (w is Map) return w.keys.where((k) => '$k'.isNotEmpty).length;
    return 0;
  }

  String _mapPlan(Object? v) {
    if (v is Map) return (v['plan'] as String?) ?? '';
    return '';
  }

  bool _isReviewed(Object? v) => v is Map && v['reviewed'] == true;
}