import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import '../services/update_service.dart';
import '../sync.dart';
import 'fields.dart';

class SettingsView extends StatelessWidget {
  final Store store;
  final SyncEngine sync;
  const SettingsView({super.key, required this.store, required this.sync});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    return Scaffold(
      appBar: AppBar(title: Text(t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(t('profile_name')),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline, color: kMuted),
              title: Text(s.settings.name),
              trailing: const Icon(Icons.chevron_right, color: kMuted),
              onTap: () => _editProfile(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: kMuted),
              title: Text(t('language')),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('EN')),
                  ButtonSegment(value: 'ar', label: Text('عربي')),
                ],
                selected: {s.settings.lang == 'ar' ? 'ar' : 'en'},
                onSelectionChanged: (sel) {
                  store.mutate(() => s.settings.lang = sel.first);
                },
              ),
            ),
          ),
          _Section(t('school')),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.currency_exchange_outlined, color: kMuted),
                title: Text(t('currency')),
                trailing: Text(s.settings.currency,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => _editCurrency(context),
              ),
              ListTile(
                leading: const Icon(Icons.savings_outlined, color: kMuted),
                title: Text(t('monthly_budget')),
                trailing: Text(fmtM(s.settings.monthlyBudget),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => _editBudget(context),
              ),
              ListTile(
                leading: const Icon(Icons.event_outlined, color: kMuted),
                title: Text(t('school_start')),
                trailing: Text(s.settings.schoolStart,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: dateOf(s.settings.schoolStart),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (d != null) {
                    store.mutate(() => s.settings.schoolStart = isoOf(d));
                  }
                },
              ),
            ]),
          ),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined, color: kMuted),
                title: Text(t('school_days')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(t([
                        'monday', 'tuesday', 'wednesday', 'thursday', 'friday',
                        'saturday', 'sunday'
                      ][i])),
                      selected: s.settings.schoolDays.contains(i),
                      onSelected: (v) => store.mutate(() {
                        if (v && !s.settings.schoolDays.contains(i)) {
                          s.settings.schoolDays.add(i);
                        } else if (!v) {
                          s.settings.schoolDays.remove(i);
                        }
                      }),
                    ),
                ]),
              ),
            ]),
          ),
          _Section(t('account')),
          ...s.accounts.map((a) => Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, color: kMuted),
                  title: Text('${a.name} · ${a.type}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: kMuted, size: 20),
                    onPressed: () => store.mutate(() => s.accounts.remove(a)),
                  ),
                ),
              )),
          Card(
            child: ListTile(
              leading: const Icon(Icons.add, color: kAccent),
              title: Text(t('new_account')),
              onTap: () => _addAccount(context),
            ),
          ),
          _Section(t('subject')),
          ...s.subjects.map((sub) => Card(
                child: ListTile(
                  dense: true,
                  title: Text('${sub.name} (x${sub.coeff})'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: kMuted, size: 20),
                    onPressed: () => store.mutate(() {
                      s.subjects.remove(sub);
                      s.cells.removeWhere((k, v) => v == sub.id);
                    }),
                  ),
                ),
              )),
          Card(
            child: ListTile(
              leading: const Icon(Icons.add, color: kAccent),
              title: Text(t('new_subject')),
              onTap: () => _addSubject(context),
            ),
          ),
          _Section(t('sync')),
          _SyncCard(store: store, sync: sync),
          _Section('ABOUT'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update, color: kMuted),
              title: const Text('Check for Updates'),
              subtitle: Text('v$kAppVersion'),
              onTap: () => UpdateService().checkForUpdate(context, force: true),
            ),
          ),
          _Section(t('export_json')),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download_outlined, color: kMuted),
              title: Text(t('export_json')),
              subtitle: Text('dalideck.v1 JSON'),
              onTap: () async {
                await Clipboard.setData(
                    ClipboardData(text: jsonEncode(store.s.toJson())));
                showSnack(context, '${t('export_json')} → clipboard');
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload_outlined, color: kMuted),
              title: Text(t('import_json')),
              onTap: () => _importDialog(context),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _editProfile(BuildContext context) {
    final s = store.s;
    final c = TextEditingController(text: s.settings.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('profile_name')),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
          FilledButton(
            onPressed: () {
              store.mutate(() => s.settings.name = c.text.trim());
              Navigator.pop(context);
            },
            child: Text(t('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _editCurrency(BuildContext context) async {
    final s = store.s;
    final c = TextEditingController(text: s.settings.currency);
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('currency')),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: Text(t('ok')),
          ),
        ],
      ),
    );
    if (v != null && v.isNotEmpty) {
      store.mutate(() => s.settings.currency = v);
    }
  }

  Future<void> _editBudget(BuildContext context) async {
    final s = store.s;
    final c = TextEditingController(text: (s.settings.monthlyBudget / 1000).toString());
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('monthly_budget')),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: Text(t('ok')),
          ),
        ],
      ),
    );
    if (v != null) {
      store.mutate(() => s.settings.monthlyBudget = tndToM(v));
    }
  }

  Future<void> _addAccount(BuildContext context) async {
    final s = store.s;
    final v = await showEntryDialog(
      context,
      t('new_account'),
      [
        EntryField('name', label: 'Name', initial: 'Cash'),
        EntryField('type',
            label: t('type'),
            type: 'select',
            options: ['cash', 'card', 'mobile', 'other'],
            initial: 'cash'),
        EntryField('balance', label: t('balance') + ' (TND)', type: 'number', initial: '0'),
      ],
    );
    if (v == null) return;
    store.mutate(() {
      s.accounts.add(Account(uid())
        ..name = v['name'] as String? ?? 'Account'
        ..type = v['type'] as String? ?? 'cash'
        ..base = tndToM(v['balance'] as String? ?? '0'));
    });
  }

  Future<void> _addSubject(BuildContext context) async {
    final s = store.s;
    final v = await showEntryDialog(
      context,
      t('new_subject'),
      [
        EntryField('name', label: 'Name'),
        EntryField('coeff', label: t('coefficient'), type: 'number', initial: '1'),
      ],
    );
    if (v == null) return;
    final name = v['name'] as String? ?? '';
    if (name.isEmpty) return;
    store.mutate(() {
      s.subjects.add(Subject(uid())
        ..name = name
        ..coeff = int.tryParse(v['coeff'] as String? ?? '') ?? 1);
    });
  }

  Future<void> _importDialog(BuildContext context) async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('import_json')),
        content: TextField(
          controller: c,
          maxLines: 6,
          decoration: InputDecoration(labelText: t('paste_json')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: Text(t('ok')),
          ),
        ],
      ),
    );
    if (v == null || v.isEmpty) return;
    if (v.length > 500000) {
      showSnack(context, 'Import too large');
      return;
    }
    try {
      final decoded = jsonDecode(v);
      if (decoded is! Map<String, dynamic> ||
          !(decoded.containsKey('v') || decoded.containsKey('subjects'))) {
        showSnack(context, 'Invalid import structure');
        return;
      }
      final imported = AppState.fromJson(decoded);
      store.mutate(() => store.s = imported);
      sync.disconnect();
      showSnack(context, t('ok'));
    } catch (_) {
      showSnack(context, t('sync_error'));
    }
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6, left: 4, right: 4),
      child: Text(label.toUpperCase(),
          style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.2)),
    );
  }
}

class _SyncCard extends StatefulWidget {
  final Store store;
  final SyncEngine sync;
  const _SyncCard({required this.store, required this.sync});

  @override
  State<_SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends State<_SyncCard> {
  final _keyC = TextEditingController();
  String? _generated;

  @override
  void dispose() {
    _keyC.dispose();
    super.dispose();
  }

  String _statusText(SyncEngine sync) {
    switch (sync.state) {
      case SyncStateVal.syncing:
        return t('syncing_dot');
      case SyncStateVal.err:
        return '${t('sync_error')}: ${sync.lastErr}';
      case SyncStateVal.ok:
        return t('sync_ok');
      default:
        return t('offline_local');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = widget.sync;
    final connected = sync.apiKey != null && sync.apiKey!.length >= 6;
    final last = sync.lastSync == null
        ? t('never')
        : sync.lastSync!.toLocal().toString().substring(0, 16);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.cloud_sync_outlined, color: kAccent),
            const SizedBox(width: 8),
            Text(t('sync'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            _dot(sync.state),
          ]),
          const SizedBox(height: 10),
          Text(_statusText(sync),
              style: TextStyle(color: sync.state == SyncStateVal.err ? kAccent : Colors.white70)),
          Row(children: [
            Text('${t('last_sync')}: $last',
                style: const TextStyle(color: kMuted, fontSize: 12)),
            if (connected) ...[
              const SizedBox(width: 8),
              Text('key ${sync.apiKey}',
                  style: const TextStyle(color: kMuted, fontSize: 12, fontFamily: 'monospace')),
            ],
          ]),
          const SizedBox(height: 12),

          if (connected)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_generated != null) ...[
                Text(t('key_created'),
                    style: const TextStyle(color: Colors.orange, fontSize: 12)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _generated!));
                    showSnack(context, t('copy'));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: kPanel,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kAccent),
                    ),
                    child: Text(_generated!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.w800,
                            fontFamily: 'monospace')),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(children: [
                OutlinedButton.icon(
                  onPressed: () {
                    sync.startPullTimer();
                    sync.syncNow();
                  },
                  icon: const Icon(Icons.sync, size: 16),
                  label: Text(t('sync_now')),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.sync.disconnect();
                    setState(() => _generated = null);
                  },
                  icon: const Icon(Icons.link_off, size: 16),
                  label: Text(t('disconnect')),
                ),
              ]),
            ])
          else ...[
            // ---- GENERATE side ----
            Text(t('generate_key').toUpperCase(),
                style: const TextStyle(color: kAccent, fontSize: 11, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            if (_generated == null)
              OutlinedButton.icon(
                onPressed: () {
                  final k = generateKey();
                  sync.connect(k);
                  setState(() => _generated = k);
                  Clipboard.setData(ClipboardData(text: k));
                  showSnack(context, t('key_created'));
                },
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(t('generate')),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kPanel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kAccent),
                ),
                child: Text(_generated!,
                    style: const TextStyle(
                        fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.w800,
                        fontFamily: 'monospace')),
              ),
              const SizedBox(height: 6),
              Text(t('key_short_ok'),
                  style: const TextStyle(color: kMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Text(t('waiting_for_key'),
                  style: const TextStyle(color: Colors.orange)),
            ],
            const Divider(height: 28),
            // ---- TYPE side ----
            Text(t('type_key').toUpperCase(),
                style: const TextStyle(color: kAccent, fontSize: 11, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _keyC,
                  decoration: InputDecoration(
                      labelText: t('sync_key'), hintText: 'abcdef12'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAccent),
                onPressed: () {
                  widget.sync.connect(_keyC.text);
                  setState(() => _generated = null);
                },
                child: Text(t('connect')),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _dot(SyncStateVal v) {
    final color = v == SyncStateVal.ok
        ? Colors.greenAccent
        : v == SyncStateVal.err
            ? kAccent
            : v == SyncStateVal.syncing
                ? Colors.orange
                : kMuted;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}