import 'package:flutter/material.dart';
import '../notifiers/player_notifier.dart';
import 'player_list_screen.dart';
import 'match_setup_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final PlayerNotifier playerNotifier;

  const MainNavigationScreen({Key? key, required this.playerNotifier}) : super(key: key);

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
      PlayerListScreen(notifier: widget.playerNotifier),
      const MatchSetupScreen(),
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
            icon: Icon(Icons.settings),
            label: '試合履歴',
          ),
        ],
      ),
    );
  }
}
