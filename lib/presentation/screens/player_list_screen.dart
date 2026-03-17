import 'package:flutter/material.dart';

import '../../domain/entities/gender.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_with_stats.dart';
import '../notifiers/player_notifier.dart';
import '../notifiers/session_notifier.dart';
import '../widgets/player_list_widgets.dart';

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
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim());
                },
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
          _buildPopupMenu(),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([widget.notifier, widget.sessionNotifier]),
        builder: (context, _) {
          final pool = widget.sessionNotifier.playerStatsPool;
          if (pool.all.isEmpty) {
            return _buildEmptyState();
          }

          final filteredPool = _searchQuery.isEmpty
              ? pool.all
              : pool.all
                  .where((p) =>
                      p.player.name.contains(_searchQuery) ||
                      p.player.yomigana.contains(_searchQuery))
                  .toList();

          return _buildPlayerList(filteredPool, theme);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddEditDialog(context);
        },
        tooltip: 'メンバを追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPopupMenu() {
    return PopupMenuButton<String>(
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
            leading: Icon(Icons.copy),
            title: Text('クリップボードへコピー'),
          ),
        ),
        const PopupMenuItem(
          value: 'import_clipboard',
          child: ListTile(
            leading: Icon(Icons.paste),
            title: Text('クリップボードから追加'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'export_json',
          child: ListTile(
            leading: Icon(Icons.save_alt),
            title: Text('JSONファイルで保存'),
          ),
        ),
        const PopupMenuItem(
          value: 'export_csv',
          child: ListTile(
            leading: Icon(Icons.grid_on),
            title: Text('CSVファイルで保存'),
          ),
        ),
        const PopupMenuItem(
          value: 'import_file',
          child: ListTile(
            leading: Icon(Icons.file_open),
            title: Text('ファイルからインポート'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
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

  Widget _buildPlayerList(List<PlayerWithStats> filteredPool, ThemeData theme) {
    final activeMales = filteredPool
        .where((p) => p.player.isActive && p.player.gender == Gender.male)
        .toList()
      ..sort((a, b) => a.player.yomigana.compareTo(b.player.yomigana));

    final activeFemales = filteredPool
        .where((p) => p.player.isActive && p.player.gender == Gender.female)
        .toList()
      ..sort((a, b) => a.player.yomigana.compareTo(b.player.yomigana));

    final groupedMales = _getGrouped(
        filteredPool.where((p) => p.player.gender == Gender.male).toList());
    final groupedFemales = _getGrouped(
        filteredPool.where((p) => p.player.gender == Gender.female).toList());

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
            SectionHeader(
              title: '本日の参加メンバ',
              subtitle:
                  '計${activeMales.length + activeFemales.length}名 (男${activeMales.length} 女${activeFemales.length})',
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activeMales.isNotEmpty) ...[
                        GenderLabel(
                          label: '男性 ${activeMales.length}名',
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        _buildWrap(activeMales),
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
                        GenderLabel(
                          label: '女性 ${activeFemales.length}名',
                          color: Colors.pink,
                        ),
                        const SizedBox(height: 8),
                        _buildWrap(activeFemales),
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
          const SectionHeader(title: '全メンバ', subtitle: '五十音順'),
          const SizedBox(height: 16),
          if (maleLabels.isEmpty && femaleLabels.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('該当するメンバが見つかりません',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          ] else ...[
            Row(
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
          ],
        ],
      ),
    );
  }

  Map<String, List<PlayerWithStats>> _getGrouped(
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

  Widget _buildWrap(List<PlayerWithStats> players,
      {bool showCheckbox = false}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: players.map((p) {
        return PlayerChip(
          playerWithStats: p,
          onTap: () {
            widget.notifier.toggleActive(p.player);
          },
          onLongPress: () {
            _showAddEditDialog(context, player: p.player);
          },
          showCheckbox: showCheckbox,
        );
      }).toList(),
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
                    const SizedBox(height: 8),
                    // SegmentedButtonを使用してRadioGroupの警告を完全に回避
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<Gender>(
                        segments: const <ButtonSegment<Gender>>[
                          ButtonSegment<Gender>(
                            value: Gender.male,
                            label: Text('男性'),
                            icon: Icon(Icons.male),
                          ),
                          ButtonSegment<Gender>(
                            value: Gender.female,
                            label: Text('女性'),
                            icon: Icon(Icons.female),
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
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      title: Text(
                        currentExcludedPartnerId != null
                            ? 'ペア: ${widget.notifier.getPlayerNameById(currentExcludedPartnerId!)}'
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
                              ? '新規メンバ'
                              : nameController.text,
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
                if (isEdit) ...[
                  TextButton(
                    onPressed: () {
                      widget.notifier.removePlayer(player.id);
                      Navigator.pop(context);
                    },
                    child:
                        const Text('削除', style: TextStyle(color: Colors.red)),
                  ),
                ],
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final yomigana = yomiganaController.text.trim();
                    if (name.isEmpty || yomigana.isEmpty) return;

                    String finalPlayerId;
                    if (isEdit) {
                      finalPlayerId = player.id;
                      await widget.notifier.updatePlayer(player.copyWith(
                        name: name,
                        yomigana: yomigana,
                        gender: selectedGender,
                        isMustRest: isMustRest,
                      ));
                    } else {
                      finalPlayerId =
                          DateTime.now().millisecondsSinceEpoch.toString();
                      await widget.notifier.addPlayer(Player(
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
                        await widget.notifier.unlinkPartner(finalPlayerId);
                      } else {
                        await widget.notifier.linkPartner(
                            finalPlayerId, currentExcludedPartnerId!);
                      }
                    }

                    if (context.mounted) Navigator.pop(context);
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

  void _showPartnerSelector(BuildContext context,
      String? currentPlayerId,
      String currentPlayerName,
      String? currentPartnerId,
      ValueChanged<String?> onSelected,) {
    final allPlayers = widget.notifier.players;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            final candidates = allPlayers.where((p) {
              if (currentPlayerId != null && p.id == currentPlayerId)
                return false;
              if (p.excludedPartnerId == null) return true;
              if (currentPlayerId != null &&
                  p.excludedPartnerId == currentPlayerId) return true;
              return false;
            }).toList();

            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        '同時出場制限ペアの設定',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '「$currentPlayerName」と同じ試合・回に出さない相手を選択してください',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (currentPartnerId != null) ...[
                  ListTile(
                    leading: const Icon(Icons.link_off, color: Colors.red),
                    title: const Text('現在のペア設定を解除する',
                        style: TextStyle(color: Colors.red)),
                    onTap: () {
                      onSelected(null);
                      Navigator.pop(context);
                    },
                  ),
                ],
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      final isCurrentPartner = currentPartnerId == candidate.id;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: candidate.gender == Gender.male
                              ? Colors.blue.withAlpha(26) // alpha 0.1
                              : Colors.pink.withAlpha(26),
                          child: Icon(
                            candidate.gender == Gender.male
                                ? Icons.male
                                : Icons.female,
                            size: 16,
                            color: candidate.gender == Gender.male
                                ? Colors.blue
                                : Colors.pink,
                          ),
                        ),
                        title: Text(candidate.name),
                        subtitle: Text(candidate.yomigana,
                            style: const TextStyle(fontSize: 11)),
                        trailing: isCurrentPartner
                            ? const Icon(Icons.check_circle, color: Colors.blue)
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
      },
    );
  }
}