import 'package:flutter/material.dart';
import 'domain/repository/player_repository/in_memory_repository.dart';
import 'presentation/notifiers/player_notifier.dart';
import 'presentation/screens/main_navigation_screen.dart';

void main() {
  final repository = InMemoryPlayerRepository();
  final playerNotifier = PlayerNotifier(repository);

  runApp(MyApp(playerNotifier: playerNotifier));
}

class MyApp extends StatelessWidget {
  final PlayerNotifier playerNotifier;

  const MyApp({Key? key, required this.playerNotifier}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Member Generator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: MainNavigationScreen(playerNotifier: playerNotifier),
    );
  }
}
