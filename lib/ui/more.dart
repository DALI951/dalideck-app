import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import 'focus.dart';
import 'habits.dart';
import 'notes.dart';
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

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.s;
    final tiles = [
      (t('focus'), Icons.timer_outlined, FocusView(store: widget.store)),
      (t('quran'), Icons.menu_book_outlined, QuranView(store: widget.store)),
      (t('projects'), Icons.rocket_launch_outlined, ProjectsView(store: widget.store)),
      (t('habits'), Icons.fitness_center_outlined, HabitsView(store: widget.store)),
      (t('notes'), Icons.note_outlined, NotesView(store: widget.store)),
      (t('review'), Icons.fact_check_outlined, ReviewView(store: widget.store)),
      (t('tutoring'), Icons.school_outlined, TutoringView(store: widget.store)),
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
                for (final (label, icon, page) in tiles)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _open(page),
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