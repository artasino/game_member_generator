import 'package:flutter/material.dart';
import 'package:game_member_generator/presentation/screens/shuttle_calculation_screen.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../di/app_scope.dart';
import 'match_history_screen.dart';
import 'other_screen.dart';
import 'player_list_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  late List<Widget> _screens;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return;
    final repositories = AppScope.of(context).repositories;
    _screens = [
      const PlayerListScreen(),
      const MatchHistoryScreen(),
      ShuttleCalculationScreen(
        shuttleRepository: repositories.shuttleUsageRepository,
        stockRepository: repositories.shuttleStockRepository,
        expenseRepository: repositories.expenseRepository,
      ),
      const OtherScreen(),
    ];
    _isInitialized = true;
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
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.people),
              label: AppLocalizations.of(context).navMembers,
            ),
            NavigationDestination(
              icon: const Icon(Symbols.badminton),
              label: AppLocalizations.of(context).navMatchHistory,
            ),
            NavigationDestination(
              icon: const Icon(Icons.currency_yen),
              label: AppLocalizations.of(context).navExpense,
            ),
            NavigationDestination(
              icon: const Icon(Icons.help_outline),
              label: AppLocalizations.of(context).navOther,
            ),
          ],
        ),
      ),
    );
  }
}
