import 'package:flutter/material.dart';

import '../notifiers/player_notifier.dart';
import '../notifiers/session_notifier.dart';
import 'match_history_screen.dart';
import 'player_list_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final PlayerNotifier playerNotifier;
  final SessionNotifier sessionNotifier;

  const MainNavigationScreen({
    super.key,
    required this.playerNotifier,
    required this.sessionNotifier,
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
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'メンバ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_tennis),
            label: '試合履歴',
          ),
        ],
      ),
    );
  }
}
