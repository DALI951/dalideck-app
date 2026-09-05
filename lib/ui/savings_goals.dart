import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import 'fields.dart';

class SavingsGoalsSection extends StatefulWidget {
  final Store store;
  const SavingsGoalsSection({super.key, required this.store});

  @override
  State<SavingsGoalsSection> createState() => _SavingsGoalsSectionState();
}

class _SavingsGoalsSectionState extends State<SavingsGoalsSection> {
  Store get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final cur = s.settings.currency;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(t('savings_goals')),
      if (s.savingsGoals.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(t('no_goals'),
              style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
        ),
      ...s.savingsGoals.map((g) => Dismissible(
            key: ValueKey(g.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: kAccent,
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) =>
                store.mutate(() => s.savingsGoals.remove(g)),
            child: _GoalCard(store: store, goal: g, cur: cur),
          )),
      Card(
        child: ListTile(
          leading: const Icon(Icons.add, color: kAccent),
          title: Text(t('add_goal')),
          onTap: () => _addGoal(context),
        ),
      ),
    ]);
  }

  Widget _sectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6, left: 4, right: 4),
      child: Text(label.toUpperCase(),
          style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.2)),
    );
  }

  Future<void> _addGoal(BuildContext context) async {
    final s = store.s;
    final v = await showEntryDialog(
      context,
      t('add_goal'),
      [
        EntryField('name', label: t('name')),
        EntryField('target', label: t('target_amount'), type: 'number'),
        EntryField('icon', label: t('icon'), initial: '🎯'),
        EntryField('deadline', label: t('date'), type: 'date', initial: todayStr()),
      ],
    );
    if (v == null) return;
    final name = v['name'] as String? ?? '';
    if (name.isEmpty) return;
    final target = tndToM(v['target'] as String? ?? '0');
    if (target <= 0) return;
    store.mutate(() {
      s.savingsGoals.add(SavingsGoal(uid())
        ..name = name
        ..target = target
        ..saved = 0
        ..deadline = v['deadline'] as String? ?? todayStr()
        ..icon = v['icon'] as String? ?? '🎯');
    });
  }
}

class _GoalCard extends StatelessWidget {
  final Store store;
  final SavingsGoal goal;
  final String cur;
  const _GoalCard({required this.store, required this.goal, required this.cur});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final reached = goal.target > 0 && goal.saved >= goal.target;
    final progress = goal.target > 0
        ? (goal.saved / goal.target).clamp(0.0, 1.0).toDouble()
        : 0.0;
    String daysLeft = '';
    if (goal.deadline != null && goal.deadline!.length >= 10) {
      final d = dateOf(goal.deadline!).difference(dateOf(todayStr())).inDays;
      if (d >= 0) daysLeft = t('days_left').replaceFirst('%s', '$d');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _RingPainter(progress, reached),
              child: Center(
                child: Text('${(progress * 100).round()}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${goal.icon} ${goal.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (reached)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(t('goal_reached'),
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${fmtM(goal.saved)} / ${fmtM(goal.target)} $cur'
                  '${daysLeft.isNotEmpty ? ' · $daysLeft' : ''}',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: kAccent),
            onPressed: () => _quickAdd(context),
          ),
        ]),
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context) async {
    final c = TextEditingController();
    final v = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t('quick_add')} — ${goal.name}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: t('amount_short')),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kAccent),
              onPressed: () => Navigator.pop(context, {'amount': c.text.trim()}),
              child: Text(t('add')),
            ),
          ]),
        ),
      ),
    );
    if (v == null) return;
    final amt = tndToM(v['amount'] as String? ?? '0');
    if (amt <= 0) return;
    store.mutate(() {
      goal.saved += amt;
      if (goal.saved >= goal.target) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t('goal_reached')} ${goal.name}')));
      }
    });
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool reached;
  _RingPainter(this.progress, this.reached);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 6.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = kPanel;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = reached ? Colors.greenAccent : kAccent;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159265 / 2,
      2 * 3.14159265 * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.reached != reached;
}
