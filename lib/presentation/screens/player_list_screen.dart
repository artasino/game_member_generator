import 'package:flutter/material.dart';

import '../../domain/entities/gender.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_with_stats.dart';
import '../di/app_scope.dart';
import '../notifiers/player_notifier.dart';
import '../notifiers/session_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/player_list_widgets.dart';

const _kUiAnimationDuration = Duration(milliseconds: 180);
const _kUiAnimationCurve = Curves.easeOutCubic;

class PlayerListScreen extends StatefulWidget {
  const PlayerListScreen({super.key});

  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');

  late final PlayerNotifier _playerNotifier;
  late final SessionNotifier _sessionNotifier;
  bool _providersBound = false;
  int? _cachedPoolHash;
  String? _cachedQuery;
  _MemoizedPlayerListData? _cachedPlayerListData;
  List<_PlayerSearchIndexEntry>? _cachedSearchIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_providersBound) return;
    final scope = AppScope.of(context);
    _playerNotifier = scope.playerNotifier;
    _sessionNotifier = scope.sessionNotifier;
    _providersBound = true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  Future<void> _handleExportClipboard() async {
    await _playerNotifier.exportPlayersToClipboard();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('クリップボードにコピーしました')));
    }
  }

  Future<void> _handleImportClipboard() async {
    final message = await _playerNotifier.importPlayersFromClipboard();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _handleExportFile(String format) async {
    await _playerNotifier.exportPlayersToFile(format);
  }

  Future<void> _handleImportFile() async {
    final message = await _playerNotifier.importPlayersFromFile();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showImportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.paste),
              title: const Text('クリップボードから追加'),
              onTap: () {
                Navigator.pop(context);
                _handleImportClipboard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_open),
              title: const Text('ファイルからインポート'),
              onTap: () {
                Navigator.pop(context);
                _handleImportFile();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('クリップボードへコピー'),
              onTap: () {
                Navigator.pop(context);
                _handleExportClipboard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('JSONファイルで保存'),
              onTap: () {
                Navigator.pop(context);
                _handleExportFile('json');
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text('CSVファイルで保存'),
              onTap: () {
                Navigator.pop(context);
                _handleExportFile('csv');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバー'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'import') {
                _showImportOptions(context);
              }
              if (value == 'export') {
                _showExportOptions(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                      leading: Icon(Icons.file_upload_outlined),
                      title: Text('データをインポート'),
                      contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                      leading: Icon(Icons.file_download_outlined),
                      title: Text('データをエクスポート'),
                      contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFixedHeader(theme),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _playerNotifier,
                _sessionNotifier,
                _searchQueryNotifier,
              ]),
              builder: (context, _) {
                final pool = _sessionNotifier.playerStatsPool;
                if (pool.all.isEmpty) {
                  return _buildEmptyState();
                }
                final memoized = _getMemoizedPlayerListData(
                  allPlayers: pool.all,
                  query: _searchQueryNotifier.value,
                );
                return _buildPlayerList(
                  data: memoized,
                  totalCount: pool.all.length,
                  theme: theme,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedHeader(ThemeData theme) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth.clamp(0.0, 1100.0).toDouble();
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchField(theme),
                    const SizedBox(height: 8),
                    _buildSearchMeta(theme),
                    const SizedBox(height: 12),
                    _buildQuickActions(theme),
                    const SizedBox(height: 8),
                    _buildHintChip(theme),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 80, color: colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'メンバーが登録されていません',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'まずはメンバーを1人ずつ登録するか、\n一括登録・インポートを試してみましょう。',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl + AppSpacing.md),
            SizedBox(
              width: 240,
              child: Column(
                children: [
                  FilledButton.icon(
                    onPressed: () => _showAddEditDialog(context),
                    icon: const Icon(Icons.person_add),
                    label: const Text('メンバーを1人登録'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showBulkAddDialog(context),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('複数まとめて登録'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _showImportOptions(context),
                    icon: const Icon(Icons.file_download),
                    label: const Text('ファイル等から読込'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerList({
    required _MemoizedPlayerListData data,
    required int totalCount,
    required ThemeData theme,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool useSingleColumn = screenWidth < 900;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth.clamp(0.0, 1100.0).toDouble();
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                  AppSpacing.lg, AppSpacing.fabBottomOffset + AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTodayMemberHeader(
                      data.activeMales.length, data.activeFemales.length),
                  const SizedBox(height: 12),
                  if (data.activeMales.isNotEmpty ||
                      data.activeFemales.isNotEmpty) ...[
                    useSingleColumn
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data.activeMales.isNotEmpty) ...[
                                GenderLabel(
                                  label: '男性 ${data.activeMales.length}名',
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 8),
                                _buildWrap(data.activeMales, showStats: true),
                                const SizedBox(height: 16),
                              ],
                              if (data.activeFemales.isNotEmpty) ...[
                                GenderLabel(
                                  label: '女性 ${data.activeFemales.length}名',
                                  color: theme.colorScheme.secondary,
                                ),
                                const SizedBox(height: 8),
                                _buildWrap(data.activeFemales, showStats: true),
                              ],
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (data.activeMales.isNotEmpty) ...[
                                      GenderLabel(
                                        label: '男性 ${data.activeMales.length}名',
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildWrap(data.activeMales,
                                          showStats: true),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (data.activeFemales.isNotEmpty) ...[
                                      GenderLabel(
                                        label: '女性 ${data.activeFemales.length}名',
                                        color: theme.colorScheme.secondary,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildWrap(data.activeFemales,
                                          showStats: true),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Divider(),
                    ),
                  ],
                  _buildAllMembersHeader(
                    hitCount: data.filteredPool.length,
                    totalCount: totalCount,
                    query: _searchQueryNotifier.value,
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: _kUiAnimationDuration,
                    reverseDuration: _kUiAnimationDuration,
                    switchInCurve: _kUiAnimationCurve,
                    switchOutCurve: _kUiAnimationCurve,
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0.0, 0.03),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: data.filteredPool.isEmpty
                        ? Padding(
                            key: const ValueKey('empty-search-result'),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xl + AppSpacing.sm,
                            ),
                            child: Center(
                              child: Text(
                                '該当するメンバーが見つかりません',
                                style: TextStyle(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          )
                        : data.hasSearchQuery
                            ? _buildWrap(
                                data.filteredPool,
                                key: const ValueKey('search-results-list'),
                                showCheckbox: true,
                              )
                            : _buildGroupedMembersSection(
                                useSingleColumn: useSingleColumn,
                                groupedMales: data.groupedMales,
                                maleLabels: data.maleLabels,
                                groupedFemales: data.groupedFemales,
                                femaleLabels: data.femaleLabels,
                                theme: theme,
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 12, // 横の間隔
        runSpacing: 8, // 折り返し時の縦の間隔
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ActionChip(
            icon: Icons.playlist_add_outlined,
            label: '登録',
            onPressed: () => _showAddMemberTypeSelector(context),
          ),
          _ActionChip(
            icon: Icons.playlist_remove_outlined,
            label: '削除',
            onPressed: () => _showBulkDeleteDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHintChip(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'タップで本日の参加切替、⋯ボタン/長押しでメンバー編集',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return ValueListenableBuilder<String>(
      valueListenable: _searchQueryNotifier,
      builder: (context, searchQuery, _) {
        return TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: '名前・よみがなで検索...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            suffixIcon: searchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _searchQueryNotifier.value = '';
                    },
                    icon: const Icon(Icons.close),
                    tooltip: '検索をクリア',
                  ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.35),
          ),
          onChanged: (value) {
            _searchQueryNotifier.value = value.trim();
          },
        );
      },
    );
  }


  Widget _buildSearchMeta(ThemeData theme) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _playerNotifier,
        _sessionNotifier,
        _searchQueryNotifier,
      ]),
      builder: (context, _) {
        final allPlayers = _sessionNotifier.playerStatsPool.all;
        final data = _getMemoizedPlayerListData(
          allPlayers: allPlayers,
          query: _searchQueryNotifier.value,
        );
        final hitCount = data.filteredPool.length;
        final totalCount = allPlayers.length;
        final hasNoResult = hitCount == 0;

        return Row(
          children: [
            Expanded(
              child: Text(
                '検索ヒット件数: $hitCount / 全$totalCount件',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: hasNoResult
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddMemberTypeSelector(context),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(hasNoResult ? '該当なし→新規追加' : '新規追加'),
            ),
          ],
        );
      },
    );
  }

  List<_PlayerSearchIndexEntry> _buildSearchIndex(
    List<PlayerWithStats> allPlayers,
    int poolHash,
  ) {
    if (_cachedPoolHash == poolHash && _cachedSearchIndex != null) {
      return _cachedSearchIndex!;
    }

    final index = allPlayers
        .map(
          (playerWithStats) => _PlayerSearchIndexEntry(
            playerWithStats: playerWithStats,
            nameIndex: _normalizeSearchText(playerWithStats.player.name),
            yomiganaIndex: _normalizeSearchText(playerWithStats.player.yomigana),
          ),
        )
        .toList(growable: false);
    _cachedSearchIndex = index;
    return index;
  }

  int _calculateMatchScore({
    required String normalizedQuery,
    required String nameIndex,
    required String yomiganaIndex,
  }) {
    int scoreForTarget(String target) {
      if (target.isEmpty || normalizedQuery.isEmpty) return 0;
      if (target.startsWith(normalizedQuery)) {
        return 200 + normalizedQuery.length;
      }
      if (target.contains(normalizedQuery)) {
        return 100 + normalizedQuery.length;
      }
      return 0;
    }

    final nameScore = scoreForTarget(nameIndex);
    final yomiganaScore = scoreForTarget(yomiganaIndex);
    if (nameScore == 0 && yomiganaScore == 0) return 0;
    final bothMatchBonus = nameScore > 0 && yomiganaScore > 0 ? 10 : 0;
    return (nameScore > yomiganaScore ? nameScore : yomiganaScore) +
        bothMatchBonus;
  }

  String _normalizeSearchText(String input) {
    if (input.isEmpty) return '';

    final widthNormalized = input
        .replaceAllMapped(RegExp(r'[！-～]'),
            (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) - 0xFEE0))
        .replaceAll('　', ' ')
        .toLowerCase();

    final kanaNormalized = String.fromCharCodes(
      widthNormalized.runes.map((rune) {
        if (rune >= 0x30A1 && rune <= 0x30F6) {
          return rune - 0x60;
        }
        return rune;
      }),
    );

    return kanaNormalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  _MemoizedPlayerListData _getMemoizedPlayerListData({
    required List<PlayerWithStats> allPlayers,
    required String query,
  }) {
    final poolHash = Object.hashAll(allPlayers);
    if (_cachedPoolHash == poolHash &&
        _cachedQuery == query &&
        _cachedPlayerListData != null) {
      return _cachedPlayerListData!;
    }

    final normalizedQuery = _normalizeSearchText(query);
    final searchIndex = _buildSearchIndex(allPlayers, poolHash);

    final filteredPlayers = normalizedQuery.isEmpty
        ? (List<PlayerWithStats>.from(allPlayers)
          ..sort((a, b) => a.player.yomigana.compareTo(b.player.yomigana)))
        : (searchIndex
            .map(
              (entry) => (
                playerWithStats: entry.playerWithStats,
                score: _calculateMatchScore(
                  normalizedQuery: normalizedQuery,
                  nameIndex: entry.nameIndex,
                  yomiganaIndex: entry.yomiganaIndex,
                ),
              ),
            )
            .where((entry) => entry.score > 0)
            .toList(growable: false)
          ..sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);
            if (scoreCompare != 0) return scoreCompare;
            return a.playerWithStats.player.yomigana
                .compareTo(b.playerWithStats.player.yomigana);
          }))
            .map((entry) => entry.playerWithStats)
            .toList(growable: false);

    final activeMales = filteredPlayers
        .where((p) => p.player.isActive && p.player.gender == Gender.male)
        .toList()
      ..sort((a, b) => a.player.yomigana.compareTo(b.player.yomigana));
    final activeFemales = filteredPlayers
        .where((p) => p.player.isActive && p.player.gender == Gender.female)
        .toList()
      ..sort((a, b) => a.player.yomigana.compareTo(b.player.yomigana));

    final groupedMales = _getGrouped(
      filteredPlayers.where((p) => p.player.gender == Gender.male).toList(),
    );
    final groupedFemales = _getGrouped(
      filteredPlayers.where((p) => p.player.gender == Gender.female).toList(),
    );

    final maleLabels = groupedMales.keys.toList()
      ..sort((a, b) => _labelOrder(a).compareTo(_labelOrder(b)));
    final femaleLabels = groupedFemales.keys.toList()
      ..sort((a, b) => _labelOrder(a).compareTo(_labelOrder(b)));

    final memoized = _MemoizedPlayerListData(
      filteredPool: filteredPlayers,
      activeMales: activeMales,
      activeFemales: activeFemales,
      groupedMales: groupedMales,
      groupedFemales: groupedFemales,
      maleLabels: maleLabels,
      femaleLabels: femaleLabels,
      hasSearchQuery: normalizedQuery.isNotEmpty,
    );
    _cachedPoolHash = poolHash;
    _cachedQuery = query;
    _cachedPlayerListData = memoized;
    return memoized;
  }

  Widget _buildAllMembersHeader({
    required int hitCount,
    required int totalCount,
    required String query,
  }) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        const AppSectionHeader(title: '全メンバー', subtitle: '五十音順'),
        Text(
          '$hitCount件 / 全$totalCount件',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: query.isNotEmpty
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Map<String, List<PlayerWithStats>> _getGrouped(
      List<PlayerWithStats> players) {
    final grouped = <String, List<PlayerWithStats>>{};
    for (final p in players) {
      final label = _getIndexLabel(p.player.yomigana);
      grouped.putIfAbsent(label, () => []).add(p);
    }
    return grouped;
  }

  Widget _buildTodayMemberHeader(int activeMalesCount, int activeFemalesCount) {
    final totalCount = activeMalesCount + activeFemalesCount;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        AppSectionHeader(
          title: '本日の参加メンバー',
          subtitle: '計$totalCount名 (男$activeMalesCount 女$activeFemalesCount)',
        ),
        OutlinedButton.icon(
          onPressed: () => _showBulkParticipationTypeSelector(context),
          icon: const Icon(Icons.groups),
          label: const Text('参加を一括変更'),
        ),
      ],
    );
  }

  Widget _buildGroupedList(Map<String, List<PlayerWithStats>> grouped,
      List<String> labels, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: labels.map((label) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  left: AppSpacing.xs, bottom: AppSpacing.sm),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary.withAlpha(153), // alpha 0.6
                ),
              ),
            ),
            _buildWrap(grouped[label]!, showCheckbox: true),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGroupedMembersSection({
    required bool useSingleColumn,
    required Map<String, List<PlayerWithStats>> groupedMales,
    required List<String> maleLabels,
    required Map<String, List<PlayerWithStats>> groupedFemales,
    required List<String> femaleLabels,
    required ThemeData theme,
  }) {
    return AnimatedSwitcher(
      duration: _kUiAnimationDuration,
      reverseDuration: _kUiAnimationDuration,
      switchInCurve: _kUiAnimationCurve,
      switchOutCurve: _kUiAnimationCurve,
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.02),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: useSingleColumn
          ? Column(
              key: const ValueKey('grouped-single-column'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGroupedList(groupedMales, maleLabels, theme),
                const SizedBox(height: 8),
                _buildGroupedList(groupedFemales, femaleLabels, theme),
              ],
            )
          : Row(
              key: const ValueKey('grouped-two-columns'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildGroupedList(groupedMales, maleLabels, theme),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGroupedList(groupedFemales, femaleLabels, theme),
                ),
              ],
            ),
    );
  }

  Widget _buildWrap(
    List<PlayerWithStats> players, {
    Key? key,
    bool showCheckbox = false,
    bool showStats = false,
  }) {
    return Wrap(
      key: key,
      spacing: 10,
      runSpacing: 10,
      children: players.map((p) {
        return PlayerChip(
          playerWithStats: p,
          onTap: () {
            _showActivateDeactivateDialog(context, p.player);
          },
          onLongPress: () {
            _showAddEditDialog(context, player: p.player);
          },
          onOpenMenu: () => _showPlayerQuickMenu(context, p.player),
          showCheckbox: showCheckbox,
          showStats: showStats,
        );
      }).toList(),
    );
  }

  void _showPlayerQuickMenu(BuildContext context, Player player) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('メンバー情報を編集'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddEditDialog(context, player: player);
                },
              ),
              ListTile(
                leading: Icon(
                    player.isActive ? Icons.person_remove : Icons.person_add),
                title: Text(
                    player.isActive ? '本日の参加から外す' : '本日の参加に追加'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showActivateDeactivateDialog(context, player);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text(
                  'メンバーを削除',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDeleteConfirm(context, player);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, Player player) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'メンバー削除',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text('「${player.name}」を削除しますか？'),
        actions: [
          AppActionButton(
            label: 'キャンセル',
            onPressed: () => Navigator.pop(dialogContext),
            isPrimary: false,
          ),
          AppActionButton(
            label: '削除',
            onPressed: () {
              _playerNotifier.removePlayer(player.id);
              Navigator.pop(dialogContext);
            },
            isPrimary: true,
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }

  String _getIndexLabel(String yomigana) {
    if (yomigana.isEmpty) return '#';
    final firstChar = yomigana.substring(0, 1);
    const mapping = {
      'あ': 'あ',
      'い': 'あ',
      'う': 'あ',
      'え': 'あ',
      'お': 'あ',
      'か': 'か',
      'き': 'か',
      'く': 'か',
      'け': 'か',
      'こ': 'か',
      'さ': 'さ',
      'し': 'さ',
      'す': 'さ',
      'せ': 'さ',
      'そ': 'さ',
      'た': 'た',
      'ち': 'た',
      'つ': 'た',
      'て': 'た',
      'と': 'た',
      'な': 'な',
      'に': 'な',
      'ぬ': 'な',
      'ね': 'な',
      'の': 'な',
      'は': 'は',
      'ひ': 'は',
      'ふ': 'は',
      'へ': 'は',
      'ほ': 'は',
      'ま': 'ま',
      'み': 'ま',
      'む': 'ま',
      'め': 'ま',
      'も': 'ま',
      'や': 'や',
      'ゆ': 'や',
      'よ': 'や',
      'ら': 'ら',
      'り': 'ら',
      'る': 'ら',
      'れ': 'ら',
      'ろ': 'ら',
      'わ': 'わ',
      'を': 'わ',
      'ん': 'わ',
      'が': 'か',
      'ぎ': 'か',
      'ぐ': 'か',
      'げ': 'か',
      'ご': 'か',
      'ざ': 'さ',
      'じ': 'さ',
      'ず': 'さ',
      'ぜ': 'さ',
      'ぞ': 'さ',
      'だ': 'た',
      'ぢ': 'た',
      'づ': 'た',
      'で': 'た',
      'ど': 'た',
      'ば': 'は',
      'び': 'は',
      'ぶ': 'は',
      'べ': 'は',
      'ぼ': 'は',
      'ぱ': 'は',
      'ぴ': 'は',
      'ぷ': 'は',
      'ぺ': 'は',
      'ぽ': 'は',
    };
    return mapping[firstChar] ??
        (RegExp(r'^[a-zA-Z]').hasMatch(firstChar)
            ? firstChar.toUpperCase()
            : '#');
  }

  int _labelOrder(String label) {
    const order = 'あかさたなはまやらわ';
    final index = order.indexOf(label);
    if (index != -1) return index;
    if (RegExp(r'^[A-Z]$').hasMatch(label)) return 100 + label.codeUnitAt(0);
    return 1000;
  }

  void _showActivateDeactivateDialog(BuildContext context, Player player) {
    final isToActivate = !player.isActive;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("参加メンバー設定",
              style: TextStyle(fontWeight: FontWeight.w900)),
          content:
              Text(isToActivate ? '今日の参加メンバーに登録しますか？' : '今日の参加メンバーから削除しますか？'),
          actions: [
            AppActionButton(
              label: 'キャンセル',
              onPressed: () => Navigator.pop(context),
              isPrimary: false,
            ),
            AppActionButton(
              label: 'OK',
              onPressed: () async {
                await _playerNotifier.toggleActive(player);
                if (context.mounted) Navigator.pop(context);
              },
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }

  void _showAddEditDialog(BuildContext context, {Player? player}) {
    final isEdit = player != null;
    final nameController = TextEditingController(text: player?.name ?? '');
    final yomiganaController =
        TextEditingController(text: player?.yomigana ?? '');
    Gender selectedGender = player?.gender ?? Gender.male;
    bool isMustRest = player?.isMustRest ?? false;
    String? currentExcludedPartnerId = player?.excludedPartnerId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? 'メンバー編集' : 'メンバー登録',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: !isEdit,
                      decoration: InputDecoration(
                        labelText: '名前',
                        hintText: '例: 山田 太郎',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: yomiganaController,
                      decoration: InputDecoration(
                        labelText: 'よみがな',
                        hintText: '例: やまだ たろう',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('性別',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<Gender>(
                        segments: const <ButtonSegment<Gender>>[
                          ButtonSegment<Gender>(
                            value: Gender.male,
                            icon: Icon(Icons.male),
                            tooltip: '男性',
                          ),
                          ButtonSegment<Gender>(
                            value: Gender.female,
                            icon: Icon(Icons.female),
                            tooltip: '女性',
                          ),
                        ],
                        selected: <Gender>{selectedGender},
                        onSelectionChanged: (Set<Gender> newSelection) {
                          setState(() {
                            selectedGender = newSelection.first;
                          });
                        },
                      ),
                    ),
                    const Divider(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('同時出場制限',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        currentExcludedPartnerId != null
                            ? Icons.link
                            : Icons.link_off,
                        color: currentExcludedPartnerId != null
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      title: Text(
                        currentExcludedPartnerId != null
                            ? 'ペア: ${_playerNotifier.getPlayerNameById(currentExcludedPartnerId!)}'
                            : 'ペア相手を設定していません',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text('子連れ夫婦など、同時出場させない相手を選択',
                          style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _showPartnerSelector(
                          context,
                          player?.id,
                          nameController.text.isEmpty
                              ? '新規メンバー'
                              : nameController.text,
                          selectedGender,
                          currentExcludedPartnerId,
                          (newId) {
                            setState(() => currentExcludedPartnerId = newId);
                          },
                        );
                      },
                    ),
                    const Divider(height: 32),
                    SwitchListTile(
                      title: const Text('次の試合は必ず休み',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('選出から除外します',
                          style: TextStyle(fontSize: 12)),
                      value: isMustRest,
                      onChanged: (v) {
                        setState(() => isMustRest = v);
                      },
                      activeThumbColor: Theme.of(context).colorScheme.tertiary,
                    ),
                  ],
                ),
              ),
              actions: [
                AppActionButton(
                  label: 'キャンセル',
                  onPressed: () => Navigator.pop(context),
                  isPrimary: false,
                ),
                if (isEdit) ...[
                  AppActionButton(
                    label: '削除',
                    onPressed: () {
                      _playerNotifier.removePlayer(player.id);
                      Navigator.pop(context);
                    },
                    isPrimary: false,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
                AppActionButton(
                  label: isEdit ? '更新' : '登録',
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final yomigana = yomiganaController.text.trim();
                    if (name.isEmpty || yomigana.isEmpty) return;

                    String finalPlayerId;
                    if (isEdit) {
                      finalPlayerId = player.id;
                      await _playerNotifier.updatePlayer(player.copyWith(
                        name: name,
                        yomigana: yomigana,
                        gender: selectedGender,
                        isMustRest: isMustRest,
                      ));
                    } else {
                      finalPlayerId =
                          DateTime.now().millisecondsSinceEpoch.toString();
                      await _playerNotifier.addPlayer(Player(
                        id: finalPlayerId,
                        name: name,
                        yomigana: yomigana,
                        gender: selectedGender,
                        isMustRest: isMustRest,
                      ));
                    }

                    final originalPartnerId = player?.excludedPartnerId;
                    if (currentExcludedPartnerId != originalPartnerId) {
                      if (currentExcludedPartnerId == null) {
                        await _playerNotifier.unlinkPartner(finalPlayerId);
                      } else {
                        await _playerNotifier.linkPartner(
                            finalPlayerId, currentExcludedPartnerId!);
                      }
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  isPrimary: true,
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPartnerSelector(
    BuildContext context,
    String? currentPlayerId,
    String currentPlayerName,
    Gender currentGender,
    String? currentPartnerId,
    ValueChanged<String?> onSelected,
  ) {
    final allPlayers = _playerNotifier.players;
    final TextEditingController selectorSearchController =
        TextEditingController();
    String selectorQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              final candidates = allPlayers.where((p) {
                if (currentPlayerId != null && p.id == currentPlayerId) {
                  return false;
                }
                if (p.excludedPartnerId != null &&
                    p.excludedPartnerId != currentPlayerId) {
                  return false;
                }

                if (selectorQuery.isNotEmpty) {
                  return p.name.contains(selectorQuery) ||
                      p.yomigana.contains(selectorQuery);
                }
                return true;
              }).toList()
                ..sort((a, b) {
                  if (a.gender != b.gender) {
                    return a.gender != currentGender ? -1 : 1;
                  }
                  return a.yomigana.compareTo(b.yomigana);
                });

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Text(
                          '同時出場制限ペアの設定',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: selectorSearchController,
                          decoration: InputDecoration(
                            hintText: 'ペア候補を検索...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg),
                          ),
                          onChanged: (v) {
                            setSheetState(() => selectorQuery = v.trim());
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (currentPartnerId != null && selectorQuery.isEmpty) ...[
                    ListTile(
                      leading: Icon(Icons.link_off,
                          color: Theme.of(context).colorScheme.error),
                      title: Text('現在のペア設定を解除する',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      onTap: () {
                        onSelected(null);
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(height: 1),
                  ],
                  Expanded(
                    child: candidates.isEmpty
                        ? Center(
                            child: Text('候補者が見つかりません',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.outline)))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: candidates.length,
                            itemBuilder: (context, index) {
                              final candidate = candidates[index];
                              final isCurrentPartner =
                                  currentPartnerId == candidate.id;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      candidate.gender == Gender.male
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.1)
                                          : Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withValues(alpha: 0.1),
                                  child: Icon(
                                    candidate.gender == Gender.male
                                        ? Icons.male
                                        : Icons.female,
                                    size: 16,
                                    color: candidate.gender == Gender.male
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                  ),
                                ),
                                title: Text(candidate.name),
                                subtitle: Text(
                                  candidate.yomigana,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                trailing: isCurrentPartner
                                    ? Icon(Icons.check_circle,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)
                                    : null,
                                onTap: () {
                                  onSelected(candidate.id);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        });
      },
    );
  }

  void _showBulkAddDialog(BuildContext context) {
    final rows = List<_BulkAddRowInput>.generate(3, (_) => _BulkAddRowInput());
    bool isMustRest = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('複数メンバーを登録',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('登録したいメンバーを入力してください'),
                    const SizedBox(height: 12),
                    ...rows.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md - 2),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text('メンバー ${index + 1}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  if (rows.length > 1)
                                    IconButton(
                                      icon: Icon(Icons.close,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error),
                                      onPressed: () {
                                        setState(() {
                                          rows.removeAt(index).dispose();
                                        });
                                      },
                                      tooltip: 'この行を削除',
                                    ),
                                ],
                              ),
                              TextField(
                                controller: row.nameController,
                                decoration: InputDecoration(
                                  labelText: '名前',
                                  hintText: '例: 山田 太郎',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: row.yomiganaController,
                                decoration: InputDecoration(
                                  labelText: 'よみがな',
                                  hintText: '例: やまだ たろう',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<Gender>(
                                  segments: const <ButtonSegment<Gender>>[
                                    ButtonSegment<Gender>(
                                      value: Gender.male,
                                      icon: Icon(Icons.male),
                                      tooltip: '男性',
                                    ),
                                    ButtonSegment<Gender>(
                                      value: Gender.female,
                                      icon: Icon(Icons.female),
                                      tooltip: '女性',
                                    ),
                                  ],
                                  selected: <Gender>{row.selectedGender},
                                  onSelectionChanged:
                                      (Set<Gender> newSelection) {
                                    setState(() {
                                      row.selectedGender = newSelection.first;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() => rows.add(_BulkAddRowInput()));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('入力行を追加'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('次の試合は必ず休み',
                          style: TextStyle(fontSize: 14)),
                      value: isMustRest,
                      onChanged: (v) => setState(() => isMustRest = v),
                      activeThumbColor: Theme.of(context).colorScheme.tertiary,
                    ),
                  ],
                ),
              ),
              actions: [
                AppActionButton(
                  label: 'キャンセル',
                  onPressed: () => Navigator.pop(context),
                  isPrimary: false,
                ),
                AppActionButton(
                  label: '登録',
                  onPressed: () async {
                    final players = <Player>[];
                    for (final row in rows) {
                      final name = row.nameController.text.trim();
                      final yomigana = row.yomiganaController.text.trim();
                      if (name.isEmpty || yomigana.isEmpty) continue;
                      players.add(Player(
                        id: '${DateTime.now().microsecondsSinceEpoch}_${players.length}',
                        name: name,
                        yomigana: yomigana,
                        gender: row.selectedGender,
                        isMustRest: isMustRest,
                      ));
                    }

                    if (players.isEmpty) return;
                    final result =
                        await _playerNotifier.addPlayersBulk(players);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('${result.$1}名を登録しました（重複スキップ: ${result.$2}名）'),
                      ),
                    );
                  },
                  isPrimary: true,
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      for (final row in rows) {
        row.dispose();
      }
    });
  }

  void _showAddMemberTypeSelector(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('登録方法を選択',
              style: TextStyle(fontWeight: FontWeight.w900)),
          contentPadding: const EdgeInsets.only(top: 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('1人ずつ登録'),
                subtitle: const Text('個別に登録します'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddEditDialog(parentContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('複数人をまとめて登録'),
                subtitle: const Text('入力フォームで一括登録します'),
                onTap: () {
                  Navigator.pop(context);
                  _showBulkAddDialog(parentContext);
                },
              ),
            ],
          ),
          actions: [
            AppActionButton(
              label: '閉じる',
              isPrimary: false,
              onPressed: () => Navigator.pop(context),
            )
          ],
        );
      },
    );
  }

  void _showBulkDeleteDialog(BuildContext context) {
    final queryController = TextEditingController();
    final selectedIds = <String>{};
    String query = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final candidates = _playerNotifier.players.where((p) {
              if (query.isEmpty) return true;
              return p.name.contains(query) || p.yomigana.contains(query);
            }).toList()
              ..sort((a, b) => a.yomigana.compareTo(b.yomigana));

            return AlertDialog(
              title: const Text('複数メンバーを削除',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: queryController,
                      decoration: InputDecoration(
                        hintText: '名前・よみがなで検索',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => query = v.trim()),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '削除対象: ${selectedIds.length}名',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: candidates.isEmpty
                          ? Center(
                              child: Text('対象メンバーが見つかりません',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: candidates.length,
                              itemBuilder: (context, index) {
                                final p = candidates[index];
                                final checked = selectedIds.contains(p.id);
                                final isMale = p.gender == Gender.male;
                                final genderColor = isMale
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.secondary;

                                return CheckboxListTile(
                                  dense: true,
                                  value: checked,
                                  title: Row(
                                    children: [
                                      Text(p.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: genderColor.withValues(
                                              alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: genderColor.withValues(
                                                  alpha: 0.5)),
                                        ),
                                        child: Text(
                                          isMale ? '男' : '女',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: genderColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(p.yomigana),
                                  activeColor: genderColor,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        selectedIds.add(p.id);
                                      } else {
                                        selectedIds.remove(p.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                AppActionButton(
                  label: 'キャンセル',
                  onPressed: () => Navigator.pop(context),
                  isPrimary: false,
                ),
                AppActionButton(
                  label: '削除',
                  color: Theme.of(context).colorScheme.error,
                  isPrimary: false,
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () async {
                          final removed = await _playerNotifier
                              .removePlayersBulk(selectedIds.toList());
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$removed名を削除しました')),
                          );
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBulkParticipationDialog(BuildContext context,
      {required bool isToActivate}) {
    final queryController = TextEditingController();
    final selectedIds = <String>{};
    String query = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final candidates = _playerNotifier.players.where((p) {
              if (p.isActive == isToActivate) return false;
              if (query.isEmpty) return true;
              return p.name.contains(query) || p.yomigana.contains(query);
            }).toList()
              ..sort((a, b) => a.yomigana.compareTo(b.yomigana));

            return AlertDialog(
              title: Text(isToActivate ? '参加メンバーに複数登録' : '参加メンバーを複数解除',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: queryController,
                      decoration: InputDecoration(
                        hintText: '名前・よみがなで検索',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => query = v.trim()),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${isToActivate ? '登録対象' : '解除対象'}: ${selectedIds.length}名',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: candidates.isEmpty
                          ? Center(
                              child: Text(
                                isToActivate
                                    ? '登録可能なメンバーがいません'
                                    : '解除可能なメンバーがいません',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.outline),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: candidates.length,
                              itemBuilder: (context, index) {
                                final p = candidates[index];
                                final checked = selectedIds.contains(p.id);
                                final isMale = p.gender == Gender.male;
                                final genderColor = isMale
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.secondary;

                                return CheckboxListTile(
                                  dense: true,
                                  value: checked,
                                  title: Row(
                                    children: [
                                      Text(p.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: genderColor.withValues(
                                              alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: genderColor.withValues(
                                                  alpha: 0.5)),
                                        ),
                                        child: Text(
                                          isMale ? '男' : '女',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: genderColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(p.yomigana),
                                  activeColor: genderColor,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        selectedIds.add(p.id);
                                      } else {
                                        selectedIds.remove(p.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                AppActionButton(
                  label: 'キャンセル',
                  onPressed: () => Navigator.pop(context),
                  isPrimary: false,
                ),
                AppActionButton(
                  label: isToActivate ? '登録' : '解除',
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () async {
                          final updated = await _playerNotifier.setActiveBulk(
                              selectedIds.toList(), isToActivate);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isToActivate
                                  ? '$updated名を参加メンバーに登録しました'
                                  : '$updated名を参加メンバーから解除しました'),
                            ),
                          );
                        },
                  isPrimary: true,
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBulkParticipationTypeSelector(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('参加メンバーを一括設定',
              style: TextStyle(fontWeight: FontWeight.w900)),
          contentPadding: const EdgeInsets.only(top: 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('複数登録'),
                subtitle: const Text('選択したメンバーを参加にします'),
                onTap: () {
                  Navigator.pop(context);
                  _showBulkParticipationDialog(parentContext,
                      isToActivate: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_remove),
                title: const Text('複数解除'),
                subtitle: const Text('選択したメンバーを不参加にします'),
                onTap: () {
                  Navigator.pop(context);
                  _showBulkParticipationDialog(parentContext,
                      isToActivate: false);
                },
              ),
            ],
          ),
          actions: [
            AppActionButton(
              label: '閉じる',
              isPrimary: false,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }
}

class _MemoizedPlayerListData {
  final List<PlayerWithStats> filteredPool;
  final List<PlayerWithStats> activeMales;
  final List<PlayerWithStats> activeFemales;
  final Map<String, List<PlayerWithStats>> groupedMales;
  final Map<String, List<PlayerWithStats>> groupedFemales;
  final List<String> maleLabels;
  final List<String> femaleLabels;
  final bool hasSearchQuery;

  const _MemoizedPlayerListData({
    required this.filteredPool,
    required this.activeMales,
    required this.activeFemales,
    required this.groupedMales,
    required this.groupedFemales,
    required this.maleLabels,
    required this.femaleLabels,
    required this.hasSearchQuery,
  });
}

class _PlayerSearchIndexEntry {
  const _PlayerSearchIndexEntry({
    required this.playerWithStats,
    required this.nameIndex,
    required this.yomiganaIndex,
  });

  final PlayerWithStats playerWithStats;
  final String nameIndex;
  final String yomiganaIndex;
}

class _BulkAddRowInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController yomiganaController = TextEditingController();
  Gender selectedGender = Gender.male;

  void dispose() {
    nameController.dispose();
    yomiganaController.dispose();
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      onPressed: onPressed,
      // Webでのレンダリング差異（フォント幅の計算誤差）を吸収するために
      // paddingを十分に確保し、labelPaddingを調整する
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelPadding: const EdgeInsets.only(left: 4, right: 8),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      side: BorderSide(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}
