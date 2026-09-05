import 'package:flutter/material.dart';

import '../models.dart';
import '../ui/weeks.dart';

/// DaliDeck home-screen widget — single source of truth for the widget's
/// identity, its SharedPreferences data keys, and the three summary strings
/// pushed to the launcher.
///
/// NOTE on home_widget 0.7.0: this version does NOT ship the Dart Glance API
/// (GlanceAppWidget / GlanceAppWidgetTile / GlanceAppWidgetProvider are not
/// exported by the package; its README states widgets must be written with
/// native code, and the Glance-style Dart toolchain only arrived in 0.8+).
/// So in 0.7.0 the flow is: WidgetService pushes the strings below with
/// HomeWidget.saveWidgetData and asks the launcher to redraw with
/// HomeWidget.updateWidget. [DaliDeckWidget] stays a plain compile-safe Dart
/// definition (identity + keys + layout tokens) so the CI build stays green.
class DaliDeckWidget {
  DaliDeckWidget._();

  /// Provider name used with HomeWidget.updateWidget(name:). Must match the
  /// receiver's android:name, which the CI manifest step registers as the
  /// plugin's own AppWidgetProvider (es.antonborri.home_widget.HomeWidgetProvider).
  static const String providerName =
      'es.antonborri.home_widget.HomeWidgetProvider';

  /// home_widget SharedPreferences keys the widget layer reads.
  static const String nextClassKey = 'nextClass';
  static const String balanceKey = 'balance';
  static const String habitsDoneKey = 'habitsDone';

  // Home-screen card palette (mirrors the in-app theme).
  static const Color background = Color(0xFF0B0D10);
  static const Color panel = Color(0xFF15181E);
  static const Color accent = Color(0xFFDC2626);
  static const Color textColor = Colors.white;
  static const Color mutedColor = Color(0xFF9AA3AD);

  /// "Maths in 10 min" / "No class today" — finds the soonest period cell with
  /// a start time still ahead today (cellAt + current time).
  static String nextClassText(AppState s) {
    final now = DateTime.now();
    final minsNow = now.hour * 60 + now.minute;
    final wd = now.weekday - 1;
    String? bestSubj;
    var bestStart = 1440;
    for (final p in s.periods) {
      final sid = cellAt(s, p.id, wd);
      if (sid == null || sid.isEmpty) continue;
      final start = _periodStart(p.time);
      if (start == null) continue;
      if (start >= minsNow && start < bestStart) {
        bestStart = start;
        bestSubj = sid;
      }
    }
    if (bestSubj == null) return 'No class today';
    final name = s.subjectName(bestSubj) ?? bestSubj;
    final diff = bestStart - minsNow;
    if (diff <= 0) return name;
    return '$name in $diff min';
  }

  /// Wallet balance (fmtM of the wallet total).
  static String balanceText(AppState s) =>
      '${fmtM(walletTotal(s))} ${s.settings.currency}';

  /// Weekly habits progress ("3/5 habits done today" via weekDone/weekTotal).
  static String habitsDoneText(AppState s) {
    final total = weekTotal(s);
    if (total <= 0) return 'No habits';
    return '${weekDone(s)}/$total habits done today';
  }

  static int? _periodStart(String time) {
    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    if (h == null || min == null) return null;
    return h * 60 + min;
  }
}

/// Preview card: renders the same summary a widget shows. Can be passed to
/// HomeWidget.renderFlutterWidget to produce a Flutter-drawn image surface.
class DaliDeckCard extends StatelessWidget {
  final String nextClass;
  final String balance;
  final String habitsDone;
  const DaliDeckCard({
    super.key,
    required this.nextClass,
    required this.balance,
    required this.habitsDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DaliDeckWidget.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DaliDeckWidget.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DaliDeck',
            style: TextStyle(
              color: DaliDeckWidget.accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            nextClass,
            style: const TextStyle(
              color: DaliDeckWidget.textColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            balance,
            style: const TextStyle(
              color: DaliDeckWidget.mutedColor,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            habitsDone,
            style: const TextStyle(
              color: DaliDeckWidget.mutedColor,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}