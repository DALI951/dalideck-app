import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import '../sync.dart';

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
          _Header(t('profile_name'), s.settings.name, () => _editProfile(context)),
          const SizedBox(height: 6),
          Card(child: ListTile(
            leading: const Icon(Icons.language, color: kMuted),
            title: Text(t('language')),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'ar', label: Text('عربي')),
              ],
              selected: {s.settings.lang == 'ar' ? 'ar' : 'en'},
              onSelectionChanged: (sel) {
                final lang = sel.first;
                store.mutate(() => s.settings.lang = lang);
              },
            ),
          )),
          _SyncCard(store: store, sync: sync),
          Card(child: ListTile(
            leading: const Icon(Icons.download_outlined, color: kMuted),
            title: Text(t('export_json')),
            subtitle: Text('dalideck.v1 JSON'),
            onTap: () async {
              await Clipboard.setData(
                  ClipboardData(text: jsonEncode(store.s.toJson())));
              showSnack(context, t('export_json') + ' → clipboard');
            },
          )),
          Card(child: ListTile(
            leading: const Icon(Icons.upload_outlined, color: kMuted),
            title: Text(t('import_json')),
            onTap: () => _importDialog(context),
          )),
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
    try {
      final imported = AppState.fromJson(jsonDecode(v) as Map<String, dynamic>);
      store.mutate(() {
        // wholesale adoption, keys stay locally authoritative for the seed
        store.s = imported;
      });
      sync.disconnect();
      showSnack(context, t('ok'));
    } catch (_) {
      showSnack(context, t('sync_error'));
    }
  }
}

class _Header extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _Header(this.label, this.value, this.onTap);

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

  @override
  Widget build(BuildContext context) {
    final sync = widget.sync;
    final connected = sync.apiKey != null && sync.apiKey!.length >= 6;
    String status;
    switch (sync.state) {
      case SyncStateVal.syncing:
        status = t('syncing_dot');
        break;
      case SyncStateVal.err:
        status = '${t('sync_error')}: ${sync.lastErr}';
        break;
      case SyncStateVal.ok:
        status = t('sync_ok');
        break;
      default:
        status = t('offline_local');
    }
    final last =
        sync.lastSync == null ? t('never') : sync.lastSync!.toLocal().toString().substring(0, 19);
    final masked = (sync.apiKey ?? '').length >= 7
        ? (sync.apiKey ?? '')
            .replaceRange(3, (sync.apiKey ?? '').length - 3, '…')
        : sync.apiKey ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.cloud_sync_outlined, color: kAccent),
              const SizedBox(width: 8),
              Text(t('sync'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              _dot(sync.state),
            ]),
            const SizedBox(height: 12),
            Text(status,
                style: TextStyle(
                    color:
                        sync.state == SyncStateVal.err ? kAccent : Colors.white70)),
            if (sync.lastSync != null)
              Text('${t('last_sync')}: $last',
                  style: const TextStyle(color: kMuted, fontSize: 12)),
            const SizedBox(height: 12),
            if (!connected)
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _keyC,
                    decoration: InputDecoration(
                        labelText: t('sync_key'),
                        hintText: 'dalideck-test-1'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => sync.connect(_keyC.text),
                  child: Text(t('connect')),
                ),
              ])
            else
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('key: $masked',
                    style: const TextStyle(color: kMuted, fontFamily: 'monospace')),
                const SizedBox(height: 8),
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
                    onPressed: () => sync.disconnect(),
                    icon: const Icon(Icons.link_off, size: 16),
                    label: Text(t('disconnect')),
                  ),
                ]),
              ]),
          ],
        ),
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