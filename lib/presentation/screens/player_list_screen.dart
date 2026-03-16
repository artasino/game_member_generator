import 'package:flutter/material.dart';

import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_with_stats.dart';
import '../notifiers/player_notifier.dart';
import '../notifiers/session_notifier.dart';

class PlayerListScreen extends StatefulWidget {
  final PlayerNotifier notifier;
  final SessionNotifier sessionNotifier;

  const PlayerListScreen({
    super.key,
    required this.notifier,
    required this.sessionNotifier,
  });

  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '名前・よみがなで検索...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
              )
            : const Text('メンバ一覧'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              String? message;
              if (value == 'export_clipboard') {
                await widget.notifier.exportPlayersToClipboard();
                message = 'クリップボードにコピーしました';
              } else if (value == 'import_clipboard') {
                message = await widget.notifier.importPlayersFromClipboard();
              } else if (value == 'export_json') {
                await widget.notifier.exportPlayersToFile('json');
              } else if (value == 'export_csv') {
                await widget.notifier.exportPlayersToFile('csv');
              } else if (value == 'import_file') {
                message = await widget.notifier.importPlayersFromFile();
              }

              if (message != null && mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'export_clipboard',
                  child: ListTile(
                      leading: Icon(Icons.copy), title: Text('クリップボードへコピー'))),
              const PopupMenuItem(
                  value: 'import_clipboard',
                  child: ListTile(
                      leading: Icon(Icons.paste), title: Text('クリップボードから追加'))),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'export_json',
                  child: ListTile(
                      leading: Icon(Icons.save_alt),
                      title: Text('JSONファイルで保存'))),
              const PopupMenuItem(
                  value: 'export_csv',
                  child: ListTile(
                      leading: Icon(Icons.grid_on), title: Text('CSVファイルで保存'))),
              const PopupMenuItem(
                  value: 'import_file',
                  child: ListTile(
                      leading: Icon(Icons.file_open),
                      title: Text('ファイルからインポート'))),
            ],
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([widget.notifier, widget.sessionNotifier]),
        builder: (context, _) {
          final pool = widget.sessionNotifier.playerStatsPool;
          if (pool.all.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('メンバを登録してください', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final filteredPool = _searchQuery.isEmpty
              ? pool.all
              : pool.all
                  .where((p) =>
                      p.player.name.contains(_searchQuery) ||
                      p.player.yomigana.contains(_searchQuery))
                  .toList();

          final activeMales = filteredPool
              .where((p) => p.player.isActive && p.player.gender == Gender.male)
              .toList()
            ..sort((a, b) => a.player.yomigana.compareTo(b.player.yomigana));

          final activeFemales = filteredPool
              .where(
                  (p) => p.player.isActive && p.player.gender == Gender.female)
              .toList()
            ..sort((a, b) => a.player.yomigana.compareTo(b.player.yomigana));

          // 性別ごとに分けてグループ化
          Map<String, List<PlayerWithStats>> getGrouped(
              List<PlayerWithStats> players) {
            final grouped = <String, List<PlayerWithStats>>{};
            final sorted = List<PlayerWithStats>.from(players)
              ..sort((a, b) => a.player.yomigana.compareTo(b.player.yomigana));
            for (var p in sorted) {
              final label = _getIndexLabel(p.player.yomigana);
              grouped.putIfAbsent(label, () => []).add(p);
            }
            return grouped;
          }

          final malePlayers = filteredPool
              .where((p) => p.player.gender == Gender.male)
              .toList();
          final femalePlayers = filteredPool
              .where((p) => p.player.gender == Gender.female)
              .toList();

          final groupedMales = getGrouped(malePlayers);
          final groupedFemales = getGrouped(femalePlayers);

          final maleLabels = groupedMales.keys.toList()
            ..sort((a, b) => _labelOrder(a).compareTo(_labelOrder(b)));
          final femaleLabels = groupedFemales.keys.toList()
            ..sort((a, b) => _labelOrder(a).compareTo(_labelOrder(b)));

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeMales.isNotEmpty || activeFemales.isNotEmpty) ...[
                  _buildSectionHeader(context, '本日の参加メンバ',
                      '計${activeMales.length + activeFemales.length}名 (男${activeMales.length} 女${activeFemales.length})'),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (activeMales.isNotEmpty) ...[
                              _GenderLabel(
                                  label: '男性 ${activeMales.length}名',
                                  color: Colors.blue),
                              const SizedBox(height: 8),
                              _buildWrap(activeMales, theme),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (activeFemales.isNotEmpty) ...[
                              _GenderLabel(
                                  label: '女性 ${activeFemales.length}名',
                                  color: Colors.pink),
                              const SizedBox(height: 8),
                              _buildWrap(activeFemales, theme),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(),
                  ),
                ],
                _buildSectionHeader(context, '全メンバ', '五十音順'),
                const SizedBox(height: 16),
                if (maleLabels.isEmpty && femaleLabels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                        child: Text('該当するメンバが見つかりません',
                            style: TextStyle(color: Colors.grey))),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child:
                            _buildGroupedList(groupedMales, maleLabels, theme),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGroupedList(
                            groupedFemales, femaleLabels, theme),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context),
        tooltip: 'メンバを追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        Text(subtitle,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: Colors.grey.shade600)),
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
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
            _buildWrap(grouped[label]!, theme, showCheckbox: true),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildWrap(List<PlayerWithStats> players, ThemeData theme,
      {bool showCheckbox = false}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: players
          .map((p) =>
              _buildPlayerChip(context, p, theme, showCheckbox: showCheckbox))
          .toList(),
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

  Widget _buildPlayerChip(
      BuildContext context, PlayerWithStats pWithStats, ThemeData theme,
      {bool showCheckbox = false}) {
    final player = pWithStats.player;
    final stats = pWithStats.stats;
    final genderColor =
        player.gender == Gender.male ? Colors.blue : Colors.pink;

    // 性別に応じた履歴
    final sameGenderCount = player.gender == Gender.male
        ? (stats.typeCounts[MatchType.menDoubles] ?? 0)
        : (stats.typeCounts[MatchType.womenDoubles] ?? 0);
    final mxCount = stats.typeCounts[MatchType.mixedDoubles] ?? 0;

    return InkWell(
      onTap: () => widget.notifier.toggleActive(player),
      onLongPress: () => _showAddEditDialog(context, player: player),
      onDoubleTap: () => _showAddEditDialog(context, player: player),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: player.isActive ? 1.0 : 0.6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: player.isActive
                ? genderColor.withValues(alpha: 0.12)
                : genderColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: player.isActive
                  ? genderColor.withValues(alpha: 0.5)
                  : genderColor.withValues(alpha: 0.2),
              width: player.isActive ? 1.5 : 1.0,
            ),
          ),
          child: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCheckbox) ...[
                  Icon(
                    player.isActive
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: player.isActive
                        ? genderColor
                        : genderColor.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 6),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          player.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: player.isActive
                                ? Colors.black87
                                : Colors.black54,
                          ),
                        ),
                        if (player.isMustRest) ...[
                          const SizedBox(width: 3),
                          const Icon(Icons.coffee_outlined,
                              size: 13, color: Colors.orange),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCountBadge(
                            '出${stats.totalMatches}', Colors.indigo,
                            isActive: player.isActive),
                        const SizedBox(width: 4),
                        _buildCountBadge(
                            '休${stats.totalRests}', Colors.deepOrange,
                            isActive: player.isActive),
                        const SizedBox(width: 8),
                        Text(
                          '${player.gender == Gender.male ? "男" : "女"}$sameGenderCount 混$mxCount',
                          style: TextStyle(
                            fontSize: 10,
                            color: player.isActive
                                ? Colors.black54
                                : Colors.grey.shade600,
                            fontWeight: player.isActive
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountBadge(String label, Color color, {required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActive
              ? color.withValues(alpha: 0.4)
              : color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: isActive ? color : color.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, {Player? player}) {
    final isEdit = player != null;
    final nameController = TextEditingController(text: player?.name ?? '');
    final yomiganaController =
        TextEditingController(text: player?.yomigana ?? '');
    Gender selectedGender = player?.gender ?? Gender.male;
    bool isMustRest = player?.isMustRest ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? 'メンバ編集' : 'メンバ登録'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: !isEdit,
                      decoration: const InputDecoration(
                        labelText: '名前',
                        hintText: '例: 山田 太郎',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: yomiganaController,
                      decoration: const InputDecoration(
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
                    RadioGroup<Gender>(
                      groupValue: selectedGender,
                      onChanged: (v) {
                        if (v != null) setState(() => selectedGender = v);
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<Gender>(
                              title: const Text('男性'),
                              value: Gender.male,
                              // groupValue と onChanged は不要（親から継承される）
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<Gender>(
                              title: const Text('女性'),
                              value: Gender.female,
                              // groupValue と onChanged は不要
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 32),
                    SwitchListTile(
                      title: const Text('次の試合は必ず休み',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('選出から除外します',
                          style: TextStyle(fontSize: 12)),
                      value: isMustRest,
                      onChanged: (v) => setState(() => isMustRest = v),
                      activeThumbColor: Colors.orange,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                if (isEdit)
                  TextButton(
                    onPressed: () {
                      widget.notifier.removePlayer(player.id);
                      Navigator.pop(context);
                    },
                    child:
                        const Text('削除', style: TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final yomigana = yomiganaController.text.trim();
                    if (name.isEmpty || yomigana.isEmpty) return;
                    if (isEdit) {
                      widget.notifier.updatePlayer(player.copyWith(
                        name: name,
                        yomigana: yomigana,
                        gender: selectedGender,
                        isMustRest: isMustRest,
                      ));
                    } else {
                      widget.notifier.addPlayer(Player(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        yomigana: yomigana,
                        gender: selectedGender,
                        isMustRest: isMustRest,
                      ));
                    }
                    Navigator.pop(context);
                  },
                  child: Text(isEdit ? '更新' : '登録'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _GenderLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _GenderLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
