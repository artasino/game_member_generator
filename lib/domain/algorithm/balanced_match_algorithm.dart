import 'dart:developer' as dev;

import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/game_evaluator.dart';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_session_selection.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';

/// 試合数や対戦履歴の偏りを抑えつつ、同時出場制限ペアを自動解消するマッチメイキングアルゴリズム
class BalancedMatchAlgorithm implements MatchAlgorithm {
  final GameEvaluator gameEvaluator;
  final CourtAssignmentAlgorithm courtAssignmentAlgorithm;

  BalancedMatchAlgorithm({
    required this.gameEvaluator,
    required this.courtAssignmentAlgorithm,
  });

  @override
  List<Game> generateMatches({
    required List<MatchType> matchTypes,
    required PlayerStatsPool playerPool,
  }) {
    final available = playerPool.filterAvailable();
    final malePool = available.males;
    final femalePool = available.females;

    // 1. 各形式の必要人数（固定・柔軟）を計算
    int reqM = 0;
    int reqF = 0;
    int reqFlex = 0;
    for (final t in matchTypes) {
      if (t == MatchType.maleDoubles) {
        reqM += 4;
      } else if (t == MatchType.femaleDoubles) {
        reqF += 4;
      } else if (t == MatchType.mixedDoubles) {
        reqM += 2;
        reqF += 2;
      } else if (t == MatchType.fixedDoubles) {
        reqFlex += 4;
      }
    }

    // 2. 柔軟枠(FD)を男女どちらで埋めるか決定
    // 固定枠で選ばれなかった人の中から、出場回数が少ない順に reqFlex 人選ぶ
    int currentReqM = reqM;
    int currentReqF = reqF;

    if (reqFlex > 0) {
      // 簡易的なシミュレーション: 固定枠を引いたあ後のプールから、試合数の少ない順に reqFlex 人ピックする
      // 男女混合の待機者リスト（試合数順）
      final remainingPlayers = [...malePool.all, ...femalePool.all];
      remainingPlayers
          .sort((a, b) => a.stats.totalMatches.compareTo(b.stats.totalMatches));

      // 固定枠（仮）を除外
      // ※ 厳密には制限ペア等で変わるが、ここでは「男女比」を決めるための概算
      int tempM = reqM;
      int tempF = reqF;
      final candidatesForFlex = <PlayerWithStats>[];
      for (final p in remainingPlayers) {
        if (p.player.gender == Gender.male && tempM > 0) {
          tempM--;
          continue;
        }
        if (p.player.gender == Gender.female && tempF > 0) {
          tempF--;
          continue;
        }
        candidatesForFlex.add(p);
      }

      // 柔軟枠としてピックされる人の性別をカウント
      final flexPicked = candidatesForFlex.take(reqFlex);
      for (final p in flexPicked) {
        if (p.player.gender == Gender.male) {
          currentReqM++;
        } else {
          currentReqF++;
        }
      }
    }

    dev.log(
        '--- マッチ生成開始: 男子必要 $currentReqM (内柔軟 ${currentReqM - reqM}), 女子必要 $currentReqF (内柔軟 ${currentReqF - reqF}) ---',
        name: 'MatchAlgo');

    // 3. セッション選抜状態の初期化
    var session = MatchSessionSelection(
      male: malePool.splitSelection(currentReqM),
      female: femalePool.splitSelection(currentReqF),
    );

    // 4. 制限ペア解消と補充
    session = session.resolveAndRefill(
      requiredMale: currentReqM,
      requiredFemale: currentReqF,
      malePool: malePool,
      femalePool: femalePool,
    );

    // 5. 最適な試合構成を探索
    return _findOptimalMatches(matchTypes, session, currentReqM, currentReqF);
  }

  List<Game> _findOptimalMatches(List<MatchType> types,
      MatchSessionSelection session, int reqM, int reqF) {
    final assignmentResult = courtAssignmentAlgorithm.searchBestAssignment(
      types: types,
      mustMales: session.male.mustPlayers,
      mustFemales: session.female.mustPlayers,
      candidateMales: session.male.candidatePool.all,
      candidateFemales: session.female.candidatePool.all,
      requiredMale: reqM,
      requiredFemale: reqF,
      previousMaleSelections: session.male.candidatePool.previousMaleSelections,
      previousFemaleSelections:
          session.female.candidatePool.previousFemaleSelections,
    );

    if (assignmentResult.games.isEmpty) {
      throw Exception('最適な試合構成が見つかりませんでした。');
    }
    return assignmentResult.games;
  }
}
