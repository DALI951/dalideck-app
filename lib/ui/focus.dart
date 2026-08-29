import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import 'weeks.dart';

class FocusView extends StatefulWidget {
  final Store store;
  const FocusView({super.key, required this.store});

  @override
  State<FocusView> createState() => _FocusViewState();
}

class _FocusViewState extends State<FocusView> {
  int _preset = 25; // minutes
  int _leftSec = 25 * 60;
  bool _running = false;
  Timer? _t;

  void _pick(int mins) {
    _t?.cancel();
    setState(() {
      _preset = mins;
      _leftSec = mins * 60;
      _running = false;
    });
  }

  void _toggle() {
    if (_running) {
      _t?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_leftSec <= 0) {
      setState(() => _leftSec = _preset * 60);
    }
    setState(() => _running = true);
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_leftSec <= 1) {
        _t?.cancel();
        setState(() {
          _running = false;
          _leftSec = 0;
        });
        widget.store.mutate(() {
          widget.store.s.sessions.add(Session(uid())
            ..date = todayStr()
            ..mins = _preset
            ..subjectId = null);
        });
        showSnack(context, '+$_preset ${t('minutes')} 👊');
        return;
      }
      setState(() => _leftSec--);
    });
  }

  void _reset() {
    _t?.cancel();
    setState(() {
      _leftSec = _preset * 60;
      _running = false;
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.s;
    final tod = todayStr();
    var todayMin = 0, weekMin = 0;
    final ws = weekDays();
    for (final se in s.sessions) {
      if (se.date == tod) todayMin += se.mins;
      if (ws.contains(se.date)) weekMin += se.mins;
    }
    final mm = _leftSec ~/ 60;
    final ss = (_leftSec % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: Text(t('focus'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat(t('today_minutes'), '$todayMin ${t('minutes')}'),
              _Stat(t('focus_goal'), '$weekMin/300'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final m in [25, 50, 10])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$m'),
                    selected: _preset == m,
                    onSelected: (_) => _pick(m),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${mm.toString().padLeft(2, '0')}:$ss',
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w300, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAccent),
                onPressed: _toggle,
                child: Text(_running ? t('pause') : t('start')),
              ),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: _reset, child: Text(t('reset'))),
            ],
          ),
          const SizedBox(height: 28),
          Text(t('sessions').toUpperCase(),
              style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          ...List.from(s.sessions.reversed).map((se) => Card(
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.timer_outlined, color: kMuted),
                  title: Text('${se.date} · ${se.mins} ${t('minutes')}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: kMuted, size: 20),
                    onPressed: () => widget.store.mutate(() => s.sessions.remove(se)),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Column(children: [
          Text(label.toUpperCase(),
              style: const TextStyle(color: kAccent, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}