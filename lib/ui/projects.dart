import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import 'fields.dart';

const kProjStatuses = {'idea', 'active', 'parked', 'done'};
const kProjTags = {'dev', 'learning', 'game', 'web', 'app', 'mc', 'money', 'school', 'other'};

class ProjectsView extends StatelessWidget {
  final Store store;
  const ProjectsView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final sorted = List<Project>.from(s.projects)
      ..sort((a, b) => a.status == b.status ? 0 : (a.status == 'active' ? -1 : 1));
    return Scaffold(
      appBar: AppBar(title: Text(t('projects'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t('empty_tasks'),
                  style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
            ),
          ...sorted.map((p) => Card(
                child: ListTile(
                  leading: const Icon(Icons.rocket_launch_outlined, color: kMuted),
                  title: Text(p.name),
                  subtitle: Text([
                    _statusLabel(p.status),
                    _tagLabel(p.tag),
                    if (p.nextStep.isNotEmpty) p.nextStep,
                  ].join(' · ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: kMuted, size: 20),
                    onPressed: () => store.mutate(() => s.projects.remove(p)),
                  ),
                ),
              )),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAccent,
        onPressed: () => _addProject(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addProject(BuildContext context) async {
    final s = store.s;
    final v = await showEntryDialog(
      context,
      t('add'),
      [
        EntryField('name', label: t('name')),
        EntryField('status',
            label: t('status'),
            type: 'select',
            options: ['active', 'parked', 'idea', 'done'],
            initial: 'active'),
        EntryField('prio',
            label: t('priority'),
            type: 'select',
            options: ['high', 'med', 'low'],
            initial: 'med'),
        EntryField('tag',
            label: t('type'),
            type: 'select',
            options: ['dev', 'learning', 'game', 'web', 'app', 'mc', 'money', 'school', 'other'],
            initial: 'dev'),
        EntryField('nextStep', label: t('next_step')),
        EntryField('lastWorked',
            label: 'Last worked', type: 'date', initial: todayStr()),
      ],
    );
    if (v == null) return;
    final name = v['name'] as String? ?? '';
    if (name.isEmpty) return;
    store.mutate(() {
      s.projects.add(Project(uid())
        ..name = name
        ..status = v['status'] as String? ?? 'idea'
        ..prio = v['prio'] as String? ?? 'med'
        ..tag = v['tag'] as String? ?? 'other'
        ..nextStep = v['nextStep'] as String? ?? ''
        ..lastWorked = v['lastWorked'] as String? ?? todayStr());
    });
  }

  String _statusLabel(String k) => t({
        'idea': 'status_idea',
        'active': 'status_active',
        'parked': 'status_parked',
        'done': 'status_done',
      }[k] ?? '');
  String _tagLabel(String k) => t({
        'dev': 'tag_dev',
        'learning': 'tag_learning',
        'game': 'tag_game',
        'web': 'tag_web',
        'app': 'tag_app',
        'mc': 'tag_mc',
        'money': 'tag_money',
        'school': 'tag_school',
        'other': 'tag_other',
      }[k] ?? '');
}