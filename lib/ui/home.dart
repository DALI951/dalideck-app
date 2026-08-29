import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';
import '../sync.dart';
import 'money.dart';
import 'school.dart';
import 'settings.dart';
import 'today.dart';

class HomeShell extends StatefulWidget {
  final Store store;
  final SyncEngine sync;
  final String lang;
  const HomeShell(
      {super.key, required this.store, required this.sync, required this.lang});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.store, widget.sync]),
      builder: (context, _) {
        final pages = [
          TodayView(store: widget.store),
          SchoolView(store: widget.store, sync: widget.sync),
          MoneyView(store: widget.store),
          SettingsView(store: widget.store, sync: widget.sync),
        ];
        return Scaffold(
          body: IndexedStack(index: _tab, children: pages),
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
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: t('settings')),
            ],
          ),
        );
      },
    );
  }
}