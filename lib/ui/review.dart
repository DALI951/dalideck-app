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

  @override
  Widget build(BuildContext context) {
    final s = widget.store.s;
    final wk = weekStartStr();
    final weeks = (s.review['weeks'] as Map?) ?? {};
    final entry = (weeks[wk] as Map?) ?? <String, dynamic>{};
    final plan = (entry['plan'] as String?) ?? '';
    final reviewed = entry['reviewed'] == true;

    // simple metrics
    final tod = todayStr();
    final examsWeek = s.exams.where((e) {
      final d = diffDays(tod, e.date);
      return d >= 0 && d <= 7;
    }).length;
    final tasksOpen = s.tasks.where((x) => !x.done).length;

    return Scaffold(
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t('exams')} 7d: $examsWeek · ${t('tasks')} ${t('due_now').toLowerCase()}: $tasksOpen',
                    style: const TextStyle(fontSize: 15)),
              ]),
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
                  onChanged: (_) => widget.store.mutate(() {
                    final w2 = (widget.store.s.review['weeks'] as Map?) ?? {};
                    final e = (w2[wk] as Map?) ?? <String, dynamic>{};
                    e['plan'] = _plan.text;
                    e['reviewed'] = !reviewed;
                    w2[wk] = e;
                    widget.store.s.review['weeks'] = w2;
                  }),
                ),
                const SizedBox(height: 4),
                if (_plan.text != plan || !reviewed)
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => widget.store.mutate(() {
                        final w2 = (widget.store.s.review['weeks'] as Map?) ?? {};
                        final e = (w2[wk] as Map?) ?? <String, dynamic>{};
                        e['plan'] = _plan.text;
                        w2[wk] = e;
                        showSnack(context, t('ok'));
                      }),
                      child: Text(t('save')),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text(t('review').toUpperCase(),
              style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.2)),
          ...weeks.entries.map((e) => Card(
                child: ListTile(
                  dense: true,
                  title: Text('${e.key}'),
                  subtitle: Text((e.value as Map)['plan'] as String? ?? ''),
                  trailing: (e.value as Map)['reviewed'] == true
                      ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                      : const Icon(Icons.circle_outlined, color: kMuted),
                ),
              )),
        ],
      ),
    );
  }
}