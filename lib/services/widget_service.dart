import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models.dart';
import '../widgets/home_widgets.dart';

/// Pushes DaliDeck summary data to the Android home-screen widget and handles
/// widget-tap interactivity (brings the app to the foreground).
class WidgetService {
  WidgetService._();

  static AppState? _lastState;

  static Future<void> init() async {
    try {
      await registerCallbacks();
    } catch (e) {
      debugPrint('WidgetService.init failed: $e');
    }
  }

  /// Registers the tap callback so tapping the widget can launch the app's
  /// main activity (the manifest wires the home_widget LAUNCH action) and
  /// refresh the pushed data.
  static Future<void> registerCallbacks() async {
    await HomeWidget.registerInteractivityCallback(_onInteractivity);
  }

  @pragma('vm:entry-point')
  static Future<void> _onInteractivity(Uri? uri) async {
    final s = _lastState;
    if (s == null) return;
    try {
      await updateWidgets(s);
    } catch (_) {}
  }

  /// Recompute and push nextClass / balance / habitsDone, then ask the
  /// launcher to redraw the widget. All failures are swallowed (widget absence
  /// or a missing native provider only logs a debug line).
  static Future<void> updateWidgets(AppState s) async {
    _lastState = s;
    try {
      await HomeWidget.saveWidgetData(
          DaliDeckWidget.nextClassKey, DaliDeckWidget.nextClassText(s));
      await HomeWidget.saveWidgetData(
          DaliDeckWidget.balanceKey, DaliDeckWidget.balanceText(s));
      await HomeWidget.saveWidgetData(
          DaliDeckWidget.habitsDoneKey, DaliDeckWidget.habitsDoneText(s));
      await HomeWidget.updateWidget(name: DaliDeckWidget.providerName);
    } catch (e) {
      debugPrint('WidgetService.updateWidgets failed: $e');
    }
  }
}