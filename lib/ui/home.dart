import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../i18n.dart';
import '../models.dart';
import '../services/update_download_manager.dart';
import '../services/update_service.dart';
import '../sync.dart';
import '../widgets/update_banner.dart';
import 'focus.dart';
import 'habits.dart';
import 'money.dart';
import 'more.dart';
import 'notes.dart';
import 'pin_screen.dart';
import 'projects.dart';
import 'quran.dart';
import 'review.dart';
import 'school.dart';
import 'settings.dart';
import 'today.dart';
import 'tutoring.dart';

class HomeShell extends StatefulWidget {
  final Store store;
  final SyncEngine sync;
  final String lang;
  final UpdateDownloadManager updateManager;
  const HomeShell({
    super.key,
    required this.store,
    required this.sync,
    required this.lang,
    required this.updateManager,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String _currentTabId = 'today';
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        UpdateService().checkForUpdate(context);
      });
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  bool _isLocked(String tabId) {
    final s = widget.store.s;
    if (!s.privacyLock['enabled']) return false;
    if (s.privacyLock['pinHash'] == null) return false;
    if (widget.store.isTabUnlocked(tabId)) return false;
    final tabs = s.privacyLock['tabs'] as Map? ?? {};
    return tabs[tabId] == true;
  }

  Widget _buildPage(String id) {
    final store = widget.store;
    switch (id) {
      case 'today': return TodayView(store: store);
      case 'school': return SchoolView(store: store, sync: widget.sync);
      case 'money': return MoneyView(store: store);
      case 'habits': return HabitsView(store: store);
      case 'notes': return NotesView(store: store);
      case 'projects': return ProjectsView(store: store);
      case 'quran': return QuranView(store: store);
      case 'focus': return FocusView(store: store);
      case 'review': return ReviewView(store: store);
      case 'tutoring': return TutoringView(store: store);
      case 'more': return MoreView(store: store, sync: widget.sync);
      case 'settings': return SettingsView(store: store, sync: widget.sync);
      default: return TodayView(store: store);
    }
  }

  IconData _navIcon(String id) {
    switch (id) {
      case 'today': return Icons.today_outlined;
      case 'school': return Icons.school_outlined;
      case 'money': return Icons.account_balance_wallet_outlined;
      case 'habits': return Icons.fitness_center_outlined;
      case 'notes': return Icons.note_outlined;
      case 'projects': return Icons.rocket_launch_outlined;
      case 'quran': return Icons.menu_book_outlined;
      case 'focus': return Icons.timer_outlined;
      case 'review': return Icons.fact_check_outlined;
      case 'tutoring': return Icons.school_outlined;
      case 'more': return Icons.grid_view_outlined;
      case 'settings': return Icons.settings_outlined;
      default: return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final ids = visibleTabIds(store.s);
        var tabIndex = ids.indexOf(_currentTabId);
        if (tabIndex < 0) {
          _currentTabId = 'today';
          tabIndex = ids.indexOf(_currentTabId);
          if (tabIndex < 0) tabIndex = 0;
        }
        final pages = <Widget>[
          for (final id in ids)
            _buildPage(id),
        ];
        return Scaffold(
          body: SafeArea(
            top: true,
            child: Column(
              children: [
                UpdateBanner(manager: widget.updateManager),
                Expanded(
                  child: IndexedStack(index: tabIndex, children: pages),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tabIndex,
            onDestinationSelected: (i) {
              final id = ids[i];
              if (_isLocked(id)) {
                Navigator.of(context).push(MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => PinScreen(
                    storedHash: store.s.privacyLock['pinHash'] as String?,
                    onUnlocked: () {
                      store.unlockTab(id);
                      setState(() => _currentTabId = id);
                    },
                  ),
                ));
              } else {
                setState(() => _currentTabId = id);
              }
            },
            destinations: [
              for (final id in ids)
                NavigationDestination(
                  icon: Icon(_navIcon(id)),
                  selectedIcon: Icon(_navIcon(id), fill: 1),
                  label: t(id),
                ),
            ],
          ),
        );
      },
    );
  }
}
