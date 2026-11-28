import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/session.dart';
import 'package:game_member_generator/domain/entities/team.dart';
import 'package:game_member_generator/domain/services/player_stats_calculator.dart';
import 'package:game_member_generator/presentation/widgets/match_history_widgets.dart';

void main() {
  final players = List.generate(
    12,
    (i) => Player(
      id: '$i',
      name: i.isEven ? '長谷川・アレクサンダー$i' : '佐藤$i',
      yomigana: '',
      gender: Gender.male,
    ),
  );
  final session = Session(
    1,
    List.generate(
      3,
      (i) => Game(
        MatchType.maleDoubles,
        Team(players[4 * i], players[4 * i + 1]),
        Team(players[4 * i + 2], players[4 * i + 3]),
      ),
    ),
  );

  for (final width in [320.0, 390.0, 680.0, 1000.0]) {
    testWidgets('match cards fit a viewport of width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 840));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? tappedPlayer;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GamesArea(
                session: session,
                allSessions: [session],
                pool: PlayerStatsCalculator().buildPool(
                  allPlayers: players,
                  sessions: [session],
                ),
                scale: 1,
                screenWidth: width - 32,
                onPlayerTap: (p) => tappedPlayer = p.id,
                onPlayerLongPress: (_) {},
              ),
            ),
          ),
        ),
      );

      final first = tester.getRect(find.byType(GameCard).at(0));
      final second = tester.getRect(find.byType(GameCard).at(1));
      if (width < 760) {
        expect(first.width, width - 32);
        expect(second.top, greaterThan(first.bottom));
      } else {
        expect(second.top, first.top);
        expect(second.left, greaterThan(first.right));
      }

      final name = find.text(players.first.name);
      expect(tester.widget<Text>(name).style?.fontWeight, FontWeight.w600);
      await tester.tap(name);
      expect(tappedPlayer, players.first.id);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('extra viewport height enlarges names without hiding court three',
      (tester) async {
    const width = 744.0;
    await tester.binding.setSurfaceSize(const Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pool = PlayerStatsCalculator().buildPool(
      allPlayers: players,
      sessions: [session],
    );

    Future<void> showCards(double height) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: height,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GamesArea(
                    session: session,
                    allSessions: [session],
                    pool: pool,
                    scale: 1,
                    screenWidth: width - 32,
                    availableHeight: height,
                    onPlayerTap: (_) {},
                    onPlayerLongPress: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

    await showCards(390);
    final shortName = find.text(players[1].name);
    final originalNameHeight = tester.getRect(shortName).height;
    expect(tester.widget<Text>(shortName).style?.fontSize, 20);

    await showCards(600);
    await tester.pumpAndSettle();
    final style = tester.widget<Text>(shortName).style!;
    expect(style.fontSize, 26);
    expect(style.fontWeight, FontWeight.w600);
    expect(tester.getRect(shortName).height, greaterThan(originalNameHeight));
    expect(tester.getRect(find.byType(GameCard).last).bottom, lessThan(600));
    expect(tester.takeException(), isNull);
  });
}
