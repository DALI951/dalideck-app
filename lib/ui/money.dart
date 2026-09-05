import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import 'fields.dart';
import 'savings_goals.dart';

const kCats = {
  'school': ['School', 'الدراسة'],
  'food': ['Food', 'أكل'],
  'tech': ['Tech', 'تقنية'],
  'gaming': ['Gaming', 'ألعاب'],
  'transport': ['Transport', 'نقل'],
  'trading': ['Trading', 'تداول'],
  'health': ['Health', 'صحة'],
  'family': ['Family', 'عائلة'],
  'other': ['Other', 'آخر'],
};

class MoneyView extends StatefulWidget {
  final Store store;
  const MoneyView({super.key, required this.store});

  @override
  State<MoneyView> createState() => _MoneyViewState();
}

class _MoneyViewState extends State<MoneyView> {
  Store get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      store.mutate(() => store.s.applyRecurring());
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final cur = s.settings.currency;
    final ym = todayStr().substring(0, 7);
    var inM = 0, outM = 0;
    for (final m in s.money) {
      if (m.date.startsWith(ym)) {
        if (m.type == 'in')
          inM += m.amount;
        else
          outM += m.amount;
      }
    }
    final sorted = List<MoneyEntry>.from(s.money)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: Text(t('money'))),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t('this_month'),
                          style: const TextStyle(color: kAccent, fontSize: 11, letterSpacing: 1.5)),
                      const SizedBox(height: 6),
                      Text('${fmtM(outM)} $cur',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      Text('${t('in')} ${fmtM(inM)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(t('wallet'),
                          style: const TextStyle(color: kAccent, fontSize: 11, letterSpacing: 1.5)),
                      const SizedBox(height: 6),
                      Text('${fmtM(walletTotal(s))} $cur',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ]),
                  ],
                ),
              ),
            ),
            ...s.accounts.map((a) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined, color: kMuted),
                    title: Text('${a.name} · ${a.type}'),
                    trailing: Text('${fmtM(accountBalance(s, a))} $cur',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )),
            _budgetsSection(context, s, ym),
            _recurringSection(s, cur),
            SavingsGoalsSection(store: store),
            const SizedBox(height: 6),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t('empty_money'),
                    style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
              ),
            ...sorted.map((m) => _MoneyTile(store: store, m: m, cur: cur)),
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAccent,
        onPressed: () => _addEntry(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addEntry(BuildContext context) async {
    final s = store.s;
    final catOpts = kCats.entries
        .map((e) => L.ar ? e.value[1] : e.value[0])
        .toList();
    final acctOpts = s.accounts.map((a) => a.id).toList();
    final v = await showEntryDialog(
      context,
      t('add'),
      [
        EntryField('type',
            label: t('type'),
            type: 'select',
            options: [t('spent'), t('income')],
            initial: t('spent')),
        EntryField('amount', label: t('amount'), type: 'number'),
        EntryField('accountId',
            label: t('account'),
            type: 'select',
            options: acctOpts,
            initial: acctOpts.isNotEmpty ? acctOpts.first : ''),
        EntryField('cat',
            label: t('category'),
            type: 'select',
            options: catOpts,
            initial: catOpts.isNotEmpty ? catOpts.first : ''),
        EntryField('note', label: t('note')),
        EntryField('date', label: t('date'), type: 'date', initial: todayStr()),
      ],
    );
    if (v == null) return;
    final obj = _catKey(v['cat'] as String? ?? '');
    store.mutate(() {
      s.money.add(MoneyEntry(uid())
        ..type = (v['type'] as String? ?? '') == t('income') ? 'in' : 'out'
        ..amount = tndToM(v['amount'] as String? ?? '0')
        ..accountId = v['accountId'] as String?
        ..cat = obj
        ..note = v['note'] as String? ?? ''
        ..date = v['date'] as String? ?? todayStr());
    });
  }

  String _catKey(String label) {
    for (final e in kCats.entries) {
      if (L.ar ? e.value[1] == label : e.value[0] == label) return e.key;
    }
    return 'other';
  }

  Widget _sectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6, left: 4, right: 4),
      child: Text(label.toUpperCase(),
          style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.2)),
    );
  }

  Widget _budgetsSection(BuildContext context, AppState s, String ym) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(t('budgets')),
      ...s.budgets.map((b) => _BudgetTile(store: store, b: b, s: s, ym: ym)),
      Card(
        child: ListTile(
          leading: const Icon(Icons.add, color: kAccent),
          title: Text(t('budgets')),
          onTap: () => _addBudget(context),
        ),
      ),
    ]);
  }

  Future<void> _addBudget(BuildContext context) async {
    final s = store.s;
    final catOpts = kCats.entries
        .map((e) => L.ar ? e.value[1] : e.value[0])
        .toList();
    final v = await showEntryDialog(
      context,
      t('budgets'),
      [
        EntryField('cat',
            label: t('category'),
            type: 'select',
            options: catOpts,
            initial: catOpts.isNotEmpty ? catOpts.first : ''),
        EntryField('limit', label: t('budget_limit'), type: 'number'),
      ],
    );
    if (v == null) return;
    final limit = tndToM(v['limit'] as String? ?? '0');
    if (limit <= 0) return;
    final catObj = _catKey(v['cat'] as String? ?? '');
    store.mutate(() {
      s.budgets.add(BudgetCategory(uid())
        ..cat = catObj
        ..limit = limit);
    });
  }

  Widget _recurringSection(AppState s, String cur) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(t('recurring')),
      if (s.recurring.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(t('recurring_entries'),
              style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
        ),
      ...s.recurring.map((r) => Card(
            child: ListTile(
              dense: true,
              leading: Icon(
                  r.type == 'in' ? Icons.arrow_downward : Icons.arrow_upward,
                  color: r.type == 'in' ? Colors.greenAccent : kAccent),
              title: Text(r.note.isEmpty ? _catLabel(r.cat) : r.note),
              subtitle: Text(
                  '${t('day_of_month')}: ${r.dayOfMonth} · ${fmtM(r.amount)} $cur'
                  '${r.lastApplied != null ? ' · ${t('last_applied')}: ${r.lastApplied}' : ''}'),
              trailing: Switch(
                value: r.active,
                onChanged: (v) => store.mutate(() => r.active = v),
              ),
              onLongPress: () => store.mutate(() => s.recurring.remove(r)),
            ),
          )),
      Card(
        child: ListTile(
          leading: const Icon(Icons.add, color: kAccent),
          title: Text(t('add_recurring')),
          onTap: () => _addRecurring(context),
        ),
      ),
    ]);
  }

  Future<void> _addRecurring(BuildContext context) async {
    final s = store.s;
    final catOpts = kCats.entries
        .map((e) => L.ar ? e.value[1] : e.value[0])
        .toList();
    final acctOpts = s.accounts.map((a) => a.id).toList();
    final v = await showEntryDialog(
      context,
      t('add_recurring'),
      [
        EntryField('type',
            label: t('type'),
            type: 'select',
            options: [t('spent'), t('income')],
            initial: t('spent')),
        EntryField('amount', label: t('amount_short'), type: 'number'),
        EntryField('accountId',
            label: t('account'),
            type: 'select',
            options: acctOpts,
            initial: acctOpts.isNotEmpty ? acctOpts.first : ''),
        EntryField('cat',
            label: t('category'),
            type: 'select',
            options: catOpts,
            initial: catOpts.isNotEmpty ? catOpts.first : ''),
        EntryField('note', label: t('note')),
        EntryField('dayOfMonth', label: t('day_of_month'), type: 'number', initial: '1'),
      ],
    );
    if (v == null) return;
    final amount = tndToM(v['amount'] as String? ?? '0');
    if (amount <= 0) return;
    final day = int.tryParse(v['dayOfMonth'] as String? ?? '') ?? 1;
    store.mutate(() {
      s.recurring.add(RecurringEntry(uid())
        ..type = (v['type'] as String? ?? '') == t('income') ? 'in' : 'out'
        ..amount = amount
        ..accountId = v['accountId'] as String?
        ..cat = _catKey(v['cat'] as String? ?? '')
        ..note = v['note'] as String? ?? ''
        ..dayOfMonth = day
        ..active = true);
    });
  }

  String _catLabel(String key) {
    final v = kCats[key];
    if (v == null) return key;
    return L.ar ? v[1] : v[0];
  }
}

class _BudgetTile extends StatelessWidget {
  final Store store;
  final BudgetCategory b;
  final AppState s;
  final String ym;
  const _BudgetTile(
      {required this.store, required this.b, required this.s, required this.ym});

  @override
  Widget build(BuildContext context) {
    int spent = 0;
    for (final m in s.money) {
      if (m.date.startsWith(ym) && m.type == 'out' && m.cat == b.cat) {
        spent += m.amount;
      }
    }
    final ratio = b.limit > 0 ? spent / b.limit : 0.0;
    final over = ratio >= 1.0;
    final near = !over && ratio >= 0.8;
    Color barColor = kAccent;
    String? warn;
    if (near) {
      barColor = Colors.orange;
      warn = t('near_limit');
    } else if (over) {
      barColor = kAccent;
      warn = t('over_budget');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_catLabel(b.cat), style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: kMuted, size: 18),
              onPressed: () => store.mutate(() => s.budgets.remove(b)),
            ),
          ]),
          LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0).toDouble(),
            color: barColor,
            backgroundColor: kPanel,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              t('spent_of').replaceFirst('%s', '${fmtM(spent)}')
                  .replaceFirst('%s', '${fmtM(b.limit)}'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (warn != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(warn,
                  style: TextStyle(
                      color: over ? kAccent : Colors.orange, fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}

class _MoneyTile extends StatelessWidget {
  final Store store;
  final MoneyEntry m;
  final String cur;
  const _MoneyTile({required this.store, required this.m, required this.cur});

  @override
  Widget build(BuildContext context) {
    final out = m.type == 'out';
    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(
            out ? Icons.arrow_upward : Icons.arrow_downward,
            color: out ? kAccent : Colors.greenAccent),
        title: Text((m.note.isEmpty ? m.cat : m.note)),
        subtitle: Text([
          m.date,
          _catLabel(m.cat),
          s_accountName(store.s, m.accountId),
        ].where((x) => x.isNotEmpty).join(' · ')),
        trailing: Text(
          '${out ? '-' : '+'}${fmtM(m.amount)} $cur',
          style: TextStyle(
              color: out ? kAccent : Colors.greenAccent,
              fontWeight: FontWeight.w700),
        ),
        onLongPress: () => store.mutate(() => store.s.money.remove(m)),
      ),
    );
  }

  String s_accountName(AppState s, String? id) {
    for (final a in s.accounts) {
      if (a.id == id) return a.name;
    }
    return '';
  }

  String _catLabel(String key) {
    final v = kCats[key];
    if (v == null) return key;
    return L.ar ? v[1] : v[0];
  }
}