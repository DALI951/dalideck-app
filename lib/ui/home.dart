import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../i18n.dart';
import '../models.dart';
import '../services/update_download_manager.dart';
import '../services/update_service.dart';
import '../sync.dart';
import '../widgets/update_banner.dart';
import 'money.dart';
import 'more.dart';
import 'school.dart';
import 'settings.dart';
import 'today.dart';

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
  int _tab = 0;
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

  ListenableBuilder _listen(Listenable listenable, Widget Function() build) {
    return ListenableBuilder(listenable: listenable, builder: (_, __) => build());
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final pages = <Widget>[
      _listen(store, () => TodayView(store: store)),
      _listen(store, () => SchoolView(store: store, sync: widget.sync)),
      _listen(store, () => MoneyView(store: store)),
      _listen(store, () => MoreView(store: store)),
      _listen(Listenable.merge([store, widget.sync]),
          () => SettingsView(store: store, sync: widget.sync)),
    ];
    return Scaffold(
      body: Column(
        children: [
          UpdateBanner(manager: widget.updateManager),
          Expanded(
            child: IndexedStack(index: _tab, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.today_outlined),
              selectedIcon: const Icon(Icons.today),
              label: t('today')),
          NavigationDestination(
              icon: const Icon(Icons.school_outlined),
              selectedIcon: const Icon(Icons.school),
              label: t('school')),
          NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet),
              label: t('money')),
          NavigationDestination(
              icon: const Icon(Icons.grid_view_outlined),
              selectedIcon: const Icon(Icons.grid_view),
              label: t('more')),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: t('settings')),
        ],
      ),
    );
  }
}
