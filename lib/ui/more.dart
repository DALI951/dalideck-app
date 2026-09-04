import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import 'focus.dart';
import 'habits.dart';
import 'notes.dart';
import 'pin_screen.dart';
import 'projects.dart';
import 'quran.dart';
import 'review.dart';
import 'tutoring.dart';

class MoreView extends StatefulWidget {
  final Store store;
  const MoreView({super.key, required this.store});

  @override
  State<MoreView> createState() => _MoreViewState();
}

class _MoreViewState extends State<MoreView> {
  String _q = '';

  bool _isLocked(String tabId) {
    final s = widget.store.s;
    if (!s.privacyLock['enabled']) return false;
    if (s.privacyLock['pinHash'] == null) return false;
    if (widget.store.isTabUnlocked(tabId)) return false;
    final tabs = s.privacyLock['tabs'] as Map? ?? {};
    return tabs[tabId] == true;
  }

  void _open(String tabId, Widget Function(Store) make) {
    if (_isLocked(tabId)) {
      Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PinScreen(
          storedHash: widget.store.s.privacyLock['pinHash'] as String?,
          onUnlocked: () {
            widget.store.unlockTab(tabId);
            Navigator.of(context).pop();
            _open(tabId, make);
          },
        ),
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: widget.store,
          builder: (_, __) => make(widget.store),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.s;
    final tiles = [
      (t('focus'), Icons.timer_outlined, 'focus', (Store st) => FocusView(store: st)),
      (t('quran'), Icons.menu_book_outlined, 'quran', (Store st) => QuranView(store: st)),
      (t('projects'), Icons.rocket_launch_outlined, 'projects', (Store st) => ProjectsView(store: st)),
      (t('habits'), Icons.fitness_center_outlined, 'habits', (Store st) => HabitsView(store: st)),
      (t('notes'), Icons.note_outlined, 'notes', (Store st) => NotesView(store: st)),
      (t('review'), Icons.fact_check_outlined, 'review', (Store st) => ReviewView(store: st)),
      (t('tutoring'), Icons.school_outlined, 'tutoring', (Store st) => TutoringView(store: st)),
    ];

    final results = _search(s, _q);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          onChanged: (v) => setState(() => _q = v.trim()),
          decoration: InputDecoration(
            hintText: t('search'),
            prefixIcon: const Icon(Icons.search, color: kMuted),
            border: InputBorder.none,
            isDense: true,
          ),
        ),
      ),
      body: _q.isEmpty
          ? GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                for (final (label, icon, tabId, make) in tiles)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _open(tabId, make),
                    child: Container(
                      decoration: BoxDecoration(
                        color: kPanel,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: kAccent, size: 28),
                          const SizedBox(height: 10),
                          Text(label,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t('no_results'),
                        style: const TextStyle(color: kMuted),
                        textAlign: TextAlign.center),
                  ),
                ...results,
              ],
            ),
    );
  }

  List<Widget> _search(AppState s, String q) {
    if (q.isEmpty) return const [];
    final lq = q.toLowerCase();
    final out = <Widget>[];
    List<Widget> group(String title, List<(String, String?)> items) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(title.toUpperCase(),
              style: const TextStyle(color: kAccent, fontSize: 11, letterSpacing: 1.2)),
        ),
        ...items.map((it) => Card(
              child: ListTile(
                dense: true,
                title: Text('${it.$1} ${it.$2 ?? ''}'),
              ),
            )),
      ];
    }

    for (final sub in s.subjects) {
      if (sub.name.toLowerCase().contains(lq)) {
        out.addAll(group(t('subject'), [(sub.name, 'x${sub.coeff}')]));
      }
    }
    final tasks = s.tasks.where((x) => x.title.toLowerCase().contains(lq)).take(8);
    if (tasks.isNotEmpty) {
      out.addAll(group(t('tasks'), tasks.map((x) => (x.title, x.due)).toList()));
    }
    final exams = s.exams.where((x) => x.title.toLowerCase().contains(lq)).take(8);
    if (exams.isNotEmpty) {
      out.addAll(group(t('exams'), exams.map((x) => (x.title, x.date)).toList()));
    }
    final notes = s.notes.where((x) => x.text.toLowerCase().contains(lq)).take(8);
    if (notes.isNotEmpty) {
      out.addAll(group(t('notes'), notes.map((x) => (x.text, x.date)).toList()));
    }
    final proj = s.projects.where((x) => x.name.toLowerCase().contains(lq)).take(8);
    if (proj.isNotEmpty) {
      out.addAll(group(t('projects'), proj.map((x) => (x.name, x.nextStep)).toList()));
    }
    final hab = s.habits.where((x) => x.name.toLowerCase().contains(lq)).take(8);
    if (hab.isNotEmpty) {
      out.addAll(group(t('habits'), hab.map((x) => (x.name, null)).toList()));
    }
    return out;
  }
}