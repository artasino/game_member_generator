import 'dart:math';

import 'package:collection/collection.dart';

import '../entities/gender.dart';
import '../entities/match_type.dart';
import '../entities/player_stats_pool.dart';
import '../entities/player_with_stats.dart';

typedef RotationSelection = ({
  Set<String> playerIds,
  int longestRest,
  int consecutiveRestCount,
});

/// Searches attendance sets independently of team and court arrangement.
class RestRotationPlanner {
  static const _searchBudget = 30000;

  ({RotationSelection? normal, RotationSelection? exception}) plan({
    required List<MatchType> matchTypes,
    required PlayerStatsPool pool,
    required Set<String> baselineIds,
    int? fixedMaleCount,
  }) {
    final players = pool.filterAvailable().all.toList()
      ..sort((a, b) {
        final restOrder = b.stats.consecutiveRests.compareTo(
          a.stats.consecutiveRests,
        );
        return restOrder != 0
            ? restOrder
            : a.stats.totalMatches.compareTo(b.stats.totalMatches);
      });
    final slots = matchTypes.length * 4;
    if (slots == 0 || slots >= players.length) {
      return (normal: null, exception: null);
    }

    if (baselineIds.length != slots ||
        !players.map((p) => p.id).toSet().containsAll(baselineIds)) {
      return (normal: null, exception: null);
    }
    final requiredMale = matchTypes.requiredPlayerCount(isMale: true);
    final requiredFemale = matchTypes.requiredPlayerCount(isMale: false);
    final maxMale = fixedMaleCount ?? slots - requiredFemale;
    final maxFemale =
        fixedMaleCount == null ? slots - requiredMale : slots - fixedMaleCount;
    final compareRest = fixedMaleCount == null
        ? _compareRest
        : compareConsecutiveRestStreaks;

    // A lower bound for the next round with the same court settings. Players
    // who already rested get the available places in longest-streak order.
    // Exclusion pairs are checked for the actual round during search.
    List<int> projectedRests(Iterable<PlayerWithStats> bench) {
      var males = 0;
      var females = 0;
      final forcedRests = <int>[];
      for (final player in bench) {
        final male = player.player.gender == Gender.male;
        if (males + females == slots ||
            (male ? males == maxMale : females == maxFemale)) {
          forcedRests.add(player.stats.consecutiveRests + 2);
        } else if (male) {
          males++;
        } else {
          females++;
        }
      }
      return forcedRests;
    }

    _Candidate candidate(
      Iterable<PlayerWithStats> selected,
      Iterable<PlayerWithStats> bench,
    ) => _Candidate(selected, bench, projectedRests(bench));

    final baseline = candidate(
      players.where((p) => baselineIds.contains(p.id)),
      players.where((p) => !baselineIds.contains(p.id)),
    );
    final recent = <Set<String>>[];
    final availableIds = players.map((p) => p.id).toSet();
    final historyLength = min(
      pool.previousMaleSelections.length,
      pool.previousFemaleSelections.length,
    );
    final rotationWindow = (players.length / slots).ceil() + 1;
    // Count actual rounds so alternating court counts can still be detected.
    final firstRecentIndex = max(0, historyLength - rotationWindow);
    for (var i = historyLength - 1; i >= firstRecentIndex; i--) {
      final ids = {
        ...pool.previousMaleSelections[i],
        ...pool.previousFemaleSelections[i],
      };
      if (!availableIds.containsAll(ids)) break;
      if (ids.length == slots) recent.add(ids);
    }

    bool repeated(Set<String> ids) =>
        recent.any((prior) => const SetEquality<String>().equals(prior, ids));

    final baselineRepeats = repeated(baselineIds);
    if (baseline.longestRest < 2 && !baselineRepeats) {
      return (normal: null, exception: null);
    }

    final selected = <PlayerWithStats>[];
    final bench = <PlayerWithStats>[];
    _Candidate best = baseline;
    _Candidate? fresh;
    var budget = _searchBudget;

    void search(int index, int males, int females) {
      if (budget-- <= 0) return;
      final currentFresh = fresh;
      if (currentFresh != null && bench.isNotEmpty) {
        final partialRests = _restStreaks(bench);
        if (compareRest(partialRests, currentFresh.restStreaks) > 0 &&
            compareRest(partialRests, best.restStreaks) > 0) {
          return;
        }
      }
      final remaining = players.length - index;
      if (selected.length + remaining < slots ||
          males > maxMale ||
          females > maxFemale) {
        return;
      }
      if (index == players.length) {
        final result = candidate(selected, bench);
        if (result.compareTo(best, repeated, compareRest) < 0) best = result;
        if (!repeated(result.ids) &&
            (fresh == null || result.compareTo(fresh!, repeated, compareRest) < 0)) {
          fresh = result;
        }
        return;
      }

      final player = players[index];
      if (selected.length < slots &&
          !selected.any(
            (other) =>
                other.player.excludedPartnerId == player.id ||
                player.player.excludedPartnerId == other.id,
          )) {
        selected.add(player);
        final male = player.player.gender == Gender.male;
        search(index + 1, males + (male ? 1 : 0), females + (male ? 0 : 1));
        selected.removeLast();
      }
      if (bench.length < players.length - slots) {
        bench.add(player);
        search(index + 1, males, females);
        bench.removeLast();
      }
    }

    search(0, 0, 0);
    final alternative = fresh;
    // A partial search can improve the normal result, but cannot establish
    // how much extra rest is necessary to break the rotation.
    final needsConsent =
        budget > 0 &&
        alternative != null &&
        repeated(best.ids) &&
        compareRest(alternative.restStreaks, best.restStreaks) > 0;
    return (
      normal: const SetEquality<String>().equals(best.ids, baselineIds)
          ? null
          : best.selection,
      exception: needsConsent ? alternative.selection : null,
    );
  }
}

class _Candidate {
  final Set<String> ids;
  final List<int> restStreaks;
  final List<int> projectedRests;
  final int totalMatches;

  _Candidate(
    Iterable<PlayerWithStats> selected,
    Iterable<PlayerWithStats> bench,
    this.projectedRests,
  ) : ids = selected.map((p) => p.id).toSet(),
      restStreaks = _restStreaks(bench),
      totalMatches = selected.fold(0, (sum, p) => sum + p.stats.totalMatches);

  int get longestRest => restStreaks.firstOrNull ?? 1;

  RotationSelection get selection => (
    playerIds: ids,
    longestRest: longestRest,
    consecutiveRestCount: restStreaks.length,
  );

  int compareTo(
    _Candidate other,
    bool Function(Set<String>) repeated,
    int Function(List<int>, List<int>) compareRest,
  ) {
    final rest = compareRest(restStreaks, other.restStreaks);
    if (rest != 0) return rest;
    final rotation = (repeated(ids) ? 1 : 0).compareTo(
      repeated(other.ids) ? 1 : 0,
    );
    if (rotation != 0) return rotation;
    final nextRound = _compareRest(projectedRests, other.projectedRests);
    if (nextRound != 0) return nextRound;
    return totalMatches.compareTo(other.totalMatches);
  }
}

List<int> _restStreaks(Iterable<PlayerWithStats> bench) => bench
    .map((p) => p.stats.consecutiveRests + 1)
    .where((streak) => streak > 1)
    .sorted((a, b) => b.compareTo(a));

int _compareRest(List<int> left, List<int> right) {
  final longest = (left.firstOrNull ?? 1).compareTo(right.firstOrNull ?? 1);
  if (longest != 0) return longest;
  final count = left.length.compareTo(right.length);
  if (count != 0) return count;
  for (var i = 1; i < left.length; i++) {
    final order = left[i].compareTo(right[i]);
    if (order != 0) return order;
  }
  return 0;
}

// The inputs are ordered longest-first. Additional rests of a given length
// matter only after all longer streaks have been compared.
int compareConsecutiveRestStreaks(List<int> left, List<int> right) {
  for (var i = 0; i < min(left.length, right.length); i++) {
    final order = left[i].compareTo(right[i]);
    if (order != 0) return order;
  }
  return left.length.compareTo(right.length);
}
