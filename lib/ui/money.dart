import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import 'fields.dart';

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

class MoneyView extends StatelessWidget {
  final Store store;
  const MoneyView({super.key, required this.store});

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