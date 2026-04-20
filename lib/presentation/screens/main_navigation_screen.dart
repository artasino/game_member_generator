import 'package:flutter/material.dart';
import 'package:game_member_generator/presentation/screens/shuttle_calculation_screen.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../infrastructure/persistence/app_repositories.dart';
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
    final repositories = context.read<AppRepositories>();
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
