import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import 'fields.dart';

class NotesView extends StatelessWidget {
  final Store store;
  const NotesView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final sorted = List<Note>.from(s.notes)..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: Text(t('notes'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t('empty_notes'),
                  style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
            ),
          ...sorted.map((n) => Card(
                child: ListTile(
                  subtitle: Text(n.text),
                  leading: const Icon(Icons.note_outlined, color: kMuted),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: kMuted, size: 20),
                    onPressed: () => store.mutate(() => s.notes.remove(n)),
                  ),
                ),
              )),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAccent,
        onPressed: () => _addNote(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addNote(BuildContext context) async {
    final s = store.s;
    final v = await showEntryDialog(
      context,
      t('add'),
      [EntryField('text', label: t('note'), hint: '…')],
    );
    if (v == null) return;
    final text = v['text'] as String? ?? '';
    if (text.isEmpty) return;
    store.mutate(() => s.notes.add(Note(uid())..text = text..date = todayStr()));
  }
}