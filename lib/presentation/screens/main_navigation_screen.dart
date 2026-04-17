import 'package:flutter/material.dart';
import 'package:game_member_generator/infrastructure/persistence/app_repositories.dart';
import 'package:game_member_generator/presentation/screens/shuttle_calculation_screen.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../notifiers/player_notifier.dart';
import '../notifiers/session_notifier.dart';
import 'match_history_screen.dart';
import 'other_screen.dart';
import 'player_list_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final PlayerNotifier playerNotifier;
  final SessionNotifier sessionNotifier;
  final AppRepositories repositories;

  const MainNavigationScreen({
    super.key,
    required this.playerNotifier,
    required this.sessionNotifier,
    required this.repositories,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      PlayerListScreen(
        notifier: widget.playerNotifier,
        sessionNotifier: widget.sessionNotifier,
      ),
      MatchHistoryScreen(notifier: widget.sessionNotifier),
      ShuttleCalculationScreen(
        playerNotifier: widget.playerNotifier,
        sessionNotifier: widget.sessionNotifier,
        shuttleRepository: widget.repositories.shuttleUsageRepository,
        stockRepository: widget.repositories.shuttleStockRepository,
        expenseRepository: widget.repositories.expenseRepository,
      ),
      OtherScreen(inquiryRepository: widget.repositories.inquiryRepository),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.people),
              label: 'メンバー',
            ),
            NavigationDestination(
              icon: Icon(Symbols.badminton),
              label: '試合履歴',
            ),
            NavigationDestination(
              icon: Icon(Icons.currency_yen),
              label: '費用計算',
            ),
            NavigationDestination(
              icon: Icon(Icons.help_outline),
              label: 'その他',
            ),
          ],
        ),
      ),
    );
  }
}
