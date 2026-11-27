import 'package:collection/collection.dart';

import '../entities/court_settings.dart';
import '../entities/gender.dart';
import '../entities/match_type.dart';
import '../entities/player_stats_pool.dart';
import '../entities/player_with_stats.dart';
import 'rest_rotation_planner.dart';

typedef _Counts = ({int men, int women});

/// The attendance and projected statistics for one recommended court setup.
class AutoMatchRecommendation {
  final List<MatchType> matchTypes;
  final Set<String> playerIds;
  final List<int> consecutiveRestStreaks;
  final List<String> restrictedRestPlayerNames;
  final int maleCount;
  final int femaleCount;
  final double? projectedMaleAverage;
  final double? projectedFemaleAverage;
  final double? projectedAverageGap;
  final PlayerStatsPool _pool;

  AutoMatchRecommendation._({
    required List<MatchType> matchTypes,
    required _AttendanceOption option,
    required _Attendance attendance,
    required PlayerStatsPool pool,
  })  : matchTypes = List.unmodifiable(matchTypes),
        playerIds = Set.unmodifiable(option.selection.ids),
        consecutiveRestStreaks =
            List.unmodifiable(option.selection.restStreaks),
        restrictedRestPlayerNames = List.unmodifiable(
          _restrictedRestNames(pool, option.selection.ids.toSet()),
        ),
        maleCount = attendance.participants.men,
        femaleCount = attendance.participants.women,
        projectedMaleAverage = attendance.participants.men == 0
            ? null
            : (attendance.totals.men + option.counts.men) /
                attendance.participants.men,
        projectedFemaleAverage = attendance.participants.women == 0
            ? null
            : (attendance.totals.women + option.counts.women) /
                attendance.participants.women,
        projectedAverageGap = attendance.participants.men == 0 ||
                attendance.participants.women == 0
            ? null
            : attendance._averageGap(option.counts) /
                (attendance.participants.men * attendance.participants.women),
        _pool = pool;

  static Iterable<String> _restrictedRestNames(
    PlayerStatsPool pool,
    Set<String> selectedIds,
  ) {
    final available = pool.active.filterAvailable().all;
    final partnersOfSelected = {
      for (final player in available)
        if (selectedIds.contains(player.id)) player.player.excludedPartnerId,
    };
    return available
        .where((p) =>
            !selectedIds.contains(p.id) &&
            (partnersOfSelected.contains(p.id) ||
                selectedIds.contains(p.player.excludedPartnerId)))
        .map((p) => p.name);
  }

  bool matches(PlayerStatsPool pool, List<MatchType> types) =>
      identical(_pool, pool) &&
      const ListEquality<MatchType>().equals(matchTypes, types);
}

/// Compares court formats using feasible attendance, before pairing teams.
class AutoMatchTypeService {
  const AutoMatchTypeService();

  AutoMatchRecommendation? recommend(
    PlayerStatsPool pool,
    int courtCount,
    AutoCourtPolicy policy,
  ) {
    final attendance = _Attendance(pool, courtCount * 4);
    for (var courts = courtCount; courts > 0; courts--) {
      List<MatchType> bestTypes = [];
      _AttendanceOption? best;
      var bestPreferred = -1;
      var bestMixedCount = 0;
      for (var md = 0; md <= courts; md++) {
        for (var wd = 0; wd <= courts - md; wd++) {
          for (var xd = 0; xd <= courts - md - wd; xd++) {
            if (policy == AutoCourtPolicy.mix && (md != 0 || wd != 0) ||
                policy == AutoCourtPolicy.genderSeparated && xd != 0) {
              continue;
            }
            final fd = courts - md - wd - xd;
            final preferred = switch (policy) {
              AutoCourtPolicy.mix => xd,
              AutoCourtPolicy.genderSeparated => md + wd,
              AutoCourtPolicy.balance => md + wd + xd,
            };
            if (preferred < bestPreferred) continue;
            final option = attendance.bestFor(
              courts * 4,
              md * 4 + xd * 2,
              wd * 4 + xd * 2,
            );
            if (option == null) continue;
            final order = best == null ? -1 : attendance.compare(option, best);
            final fewerMixedOnTie = policy == AutoCourtPolicy.balance &&
                order == 0 &&
                xd < bestMixedCount;
            if (preferred > bestPreferred || order < 0 || fewerMixedOnTie) {
              best = option;
              bestPreferred = preferred;
              bestMixedCount = xd;
              bestTypes = [
                ...List.filled(wd, MatchType.femaleDoubles),
                ...List.filled(xd, MatchType.mixedDoubles),
                ...List.filled(md, MatchType.maleDoubles),
                ...List.filled(fd, MatchType.fixedDoubles),
              ];
            }
          }
        }
      }
      if (best != null) {
        return AutoMatchRecommendation._(
          matchTypes: bestTypes,
          option: best,
          attendance: attendance,
          pool: pool,
        );
      }
    }
    return null;
  }

  AutoMatchRecommendation? evaluate(
      PlayerStatsPool pool, List<MatchType> types) {
    if (types.isEmpty) return null;
    final slots = types.length * 4;
    final attendance = _Attendance(pool, slots);
    final option = attendance.bestFor(
      slots,
      types.requiredPlayerCount(isMale: true),
      types.requiredPlayerCount(isMale: false),
    );
    if (option == null) return null;
    return AutoMatchRecommendation._(
      matchTypes: types,
      option: option,
      attendance: attendance,
      pool: pool,
    );
  }
}

class _Attendance {
  final _Counts participants;
  final _Counts totals;
  final Map<_Counts, _Selection> selections;

  factory _Attendance(PlayerStatsPool pool, int slots) {
    final participants =
        pool.active.all.where((p) => !p.player.isEarlyDeparture).toList();
    final men = participants.where((p) => p.player.gender == Gender.male);
    final women = participants.where((p) => p.player.gender == Gender.female);
    return _Attendance._(
      (men: men.length, women: women.length),
      (men: _totalMatches(men), women: _totalMatches(women)),
      _search(participants.where((p) => !p.player.isMustRest).toList(), slots),
    );
  }

  _Attendance._(this.participants, this.totals, this.selections);

  static int _totalMatches(Iterable<PlayerWithStats> players) =>
      players.fold(0, (sum, p) => sum + p.stats.totalMatches);

  _AttendanceOption? bestFor(int slots, int minimumMen, int minimumWomen) {
    _AttendanceOption? best;
    for (var men = minimumMen; men <= slots - minimumWomen; men++) {
      final counts = (men: men, women: slots - men);
      final selection = selections[counts];
      if (selection == null) continue;
      final option = (counts: counts, selection: selection);
      if (best == null || compare(option, best) < 0) best = option;
    }
    return best;
  }

  int compare(_AttendanceOption a, _AttendanceOption b) {
    final rests = a.selection.compareRests(b.selection);
    if (rests != 0) return rests;
    return _averageGap(a.counts).compareTo(_averageGap(b.counts));
  }

  int _averageGap(_Counts assigned) {
    if (participants.men == 0 || participants.women == 0) return 0;
    // The denominator is shared by every option, so compare exact integers.
    return ((totals.men + assigned.men) * participants.women -
            (totals.women + assigned.women) * participants.men)
        .abs();
  }

  static Map<_Counts, _Selection> _search(
    List<PlayerWithStats> available,
    int slots,
  ) {
    final byId = {for (final player in available) player.id: player};
    final conflicts = {for (final id in byId.keys) id: <String>{}};
    for (final player in available) {
      final partner = player.player.excludedPartnerId;
      if (partner == null ||
          partner == player.id ||
          !byId.containsKey(partner)) {
        continue;
      }
      conflicts[player.id]!.add(partner);
      conflicts[partner]!.add(player.id);
    }

    // Process linked players together so equivalent partial selections merge
    // as soon as their remaining conflicts and gender totals are identical.
    final order = <String>[];
    final visited = <String>{};
    for (final start in byId.keys) {
      final pending = [start];
      while (pending.isNotEmpty) {
        final id = pending.removeLast();
        if (!visited.add(id)) continue;
        order.add(id);
        pending.addAll(conflicts[id]!);
      }
    }
    final indices = {for (var i = 0; i < order.length; i++) order[i]: i};
    var states = {
      (men: 0, women: 0, blocked: ''): (
        blocked: <int>[],
        selection: const _Selection([], [], 0),
      ),
    };

    for (var i = 0; i < order.length; i++) {
      final player = byId[order[i]]!;
      final futureConflicts = conflicts[player.id]!
          .map((id) => indices[id]!)
          .where((index) => index > i)
          .toList();
      final next = <({int men, int women, String blocked}),
          ({List<int> blocked, _Selection selection})>{};

      void add(int men, int women, List<int> blocked, _Selection selection) {
        final key = (men: men, women: women, blocked: blocked.join(','));
        final previous = next[key]?.selection;
        if (previous == null || selection.compareTo(previous) < 0) {
          next[key] = (blocked: blocked, selection: selection);
        }
      }

      for (final entry in states.entries) {
        final state = entry.value;
        final blocked = state.blocked.where((index) => index > i).toList();
        final men = entry.key.men;
        final women = entry.key.women;
        add(men, women, blocked, state.selection.rest(player));
        if (men + women < slots && !state.blocked.contains(i)) {
          final male = player.player.gender == Gender.male;
          add(
            men + (male ? 1 : 0),
            women + (male ? 0 : 1),
            {...blocked, ...futureConflicts}.toList()..sort(),
            state.selection.play(player),
          );
        }
      }
      states = next;
    }

    return {
      for (final entry in states.entries)
        (men: entry.key.men, women: entry.key.women): entry.value.selection,
    };
  }
}

typedef _AttendanceOption = ({_Counts counts, _Selection selection});

class _Selection {
  final List<String> ids;
  final List<int> restStreaks;
  final int totalMatches;

  const _Selection(this.ids, this.restStreaks, this.totalMatches);

  _Selection rest(PlayerWithStats player) {
    final streak = player.stats.consecutiveRests + 1;
    if (streak < 2) return this;
    return _Selection(
      ids,
      [...restStreaks, streak]..sort((a, b) => b.compareTo(a)),
      totalMatches,
    );
  }

  _Selection play(PlayerWithStats player) => _Selection([...ids, player.id],
      restStreaks, totalMatches + player.stats.totalMatches);

  int compareRests(_Selection other) =>
      compareConsecutiveRestStreaks(restStreaks, other.restStreaks);

  int compareTo(_Selection other) {
    final rests = compareRests(other);
    return rests == 0 ? totalMatches.compareTo(other.totalMatches) : rests;
  }
}
