import 'package:flutter/material.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/repository/player_repository.dart';
import 'domain/algorithm/random_match_algorithm.dart';
import 'domain/entities/match_type.dart';
import 'domain/entities/player.dart';
import 'domain/repository/in_memory_repository.dart';
import 'domain/services/match_making_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Match App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 仮データ
    final players = List.generate(
      10,
          (index) => Player(
        id: '$index',
        name: 'Player $index', gender: Gender.male,
      ),
    );

    final matchTypes = [
      MatchType.menDoubles,
      MatchType.menDoubles,
    ];

    PlayerRepository playerRepository = InMemoryPlayerRepository();
    players.forEach(playerRepository.add);


    final service = MatchMakingService(
      RandomMatchAlgorithm(),
      playerRepository,
    );

    final matches = service.generateMatches(
      matchTypes: matchTypes,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Result'),
      ),
      body: ListView.builder(
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final match = matches[index];

          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(
                'Court ${match.type.name}',
              ),
              subtitle: Text(
                '${match.teamA.player1.name}, ${match.teamA.player2.name} '
                    'vs ${match.teamB.player1.name}, ${match.teamB.player2.name}',
              ),
            ),
          );
        },
      ),
    );
  }
}