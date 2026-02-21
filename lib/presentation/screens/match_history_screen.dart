import 'package:flutter/material.dart';
import '../../domain/entities/court_settings.dart';
import '../../domain/entities/game.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/team.dart';
import '../notifiers/session_notifier.dart';

class MatchHistoryScreen extends StatefulWidget {
  final SessionNotifier notifier;

  const MatchHistoryScreen({Key? key, required this.notifier}) : super(key: key);

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  int? _currentIndex;
  Player? _selectedPlayer; // 入れ替えのために選択されたプレイヤー

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('試合履歴'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _showClearConfirmDialog(context),
            tooltip: '履歴をクリア',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.notifier,
        builder: (context, _) {
          final sessions = widget.notifier.sessions;

          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('試合履歴がありません', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          if (_currentIndex == null || _currentIndex! >= sessions.length) {
            _currentIndex = sessions.length - 1;
          }

          final session = sessions[_currentIndex!];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_left, size: 40),
                      onPressed: _currentIndex! > 0
                          ? () {
                              setState(() {
                                _currentIndex = _currentIndex! - 1;
                                _selectedPlayer = null;
                              });
                            }
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '第 ${session.index} 試合',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_right, size: 40),
                      onPressed: _currentIndex! < sessions.length - 1
                          ? () {
                              setState(() {
                                _currentIndex = _currentIndex! + 1;
                                _selectedPlayer = null;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              if (_selectedPlayer != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    '${_selectedPlayer!.name} と入れ替えるメンバを選択してください',
                    style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...session.games.asMap().entries.map((entry) {
                            final gameIndex = entry.key;
                            final game = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _PlayerTag(
                                          player: game.teamA.player1,
                                          isSelected: _selectedPlayer?.id == game.teamA.player1.id,
                                          onTap: () => _handlePlayerTap(session, game.teamA.player1),
                                          onLongPress: () => _handlePlayerLongPress(game.teamA.player1),
                                        ),
                                        const SizedBox(height: 4),
                                        _PlayerTag(
                                          player: game.teamA.player2,
                                          isSelected: _selectedPlayer?.id == game.teamA.player2.id,
                                          onTap: () => _handlePlayerTap(session, game.teamA.player2),
                                          onLongPress: () => _handlePlayerLongPress(game.teamA.player2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text('vs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _PlayerTag(
                                          player: game.teamB.player1,
                                          isSelected: _selectedPlayer?.id == game.teamB.player1.id,
                                          onTap: () => _handlePlayerTap(session, game.teamB.player1),
                                          onLongPress: () => _handlePlayerLongPress(game.teamB.player1),
                                        ),
                                        const SizedBox(height: 4),
                                        _PlayerTag(
                                          player: game.teamB.player2,
                                          isSelected: _selectedPlayer?.id == game.teamB.player2.id,
                                          onTap: () => _handlePlayerTap(session, game.teamB.player2),
                                          onLongPress: () => _handlePlayerLongPress(game.teamB.player2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          if (session.restingPlayers.isNotEmpty) ...[
                            const Divider(height: 32),
                            const Text(
                              'お休み',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: session.restingPlayers.map((p) {
                                return _RestingChip(
                                  player: p,
                                  isSelected: _selectedPlayer?.id == p.id,
                                  onTap: () => _handlePlayerTap(session, p),
                                  onLongPress: () => _handlePlayerLongPress(p),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSettingsAndGenerate(context),
        tooltip: '試合を生成',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _handlePlayerLongPress(Player player) {
    setState(() {
      _selectedPlayer = player;
    });
  }

  void _handlePlayerTap(Session currentSession, Player clickedPlayer) {
    if (_selectedPlayer == null) return;

    if (_selectedPlayer!.id == clickedPlayer.id) {
      setState(() {
        _selectedPlayer = null;
      });
      return;
    }

    // 入れ替え処理
    _swapPlayers(currentSession, _selectedPlayer!, clickedPlayer);
    setState(() {
      _selectedPlayer = null;
    });
  }

  void _swapPlayers(Session session, Player p1, Player p2) {
    // Session内の全てのPlayerを走査して入れ替える
    List<Game> newGames = session.games.map((game) {
      Team newTeamA = _swapInTeam(game.teamA, p1, p2);
      Team newTeamB = _swapInTeam(game.teamB, p1, p2);
      return game.copyWith(teamA: newTeamA, teamB: newTeamB);
    }).toList();

    List<Player> newResting = session.restingPlayers.map((p) {
      if (p.id == p1.id) return p2;
      if (p.id == p2.id) return p1;
      return p;
    }).toList();

    widget.notifier.updateSession(session.copyWith(
      games: newGames,
      restingPlayers: newResting,
    ));
  }

  Team _swapInTeam(Team team, Player p1, Player p2) {
    Player newP1 = team.player1;
    Player newP2 = team.player2;

    if (team.player1.id == p1.id) newP1 = p2;
    else if (team.player1.id == p2.id) newP1 = p1;

    if (team.player2.id == p1.id) newP2 = p2;
    else if (team.player2.id == p2.id) newP2 = p1;

    return team.copyWith(player1: newP1, player2: newP2);
  }

  void _showSettingsAndGenerate(BuildContext context) {
    final currentSettings = widget.notifier.getCurrentSettings();
    List<MatchType> selectedTypes = List.from(currentSettings.matchTypes);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('次の試合の設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('マッチタイプを追加:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TypeButton(
                        label: '男子W',
                        color: Colors.blue,
                        onPressed: () => setState(() => selectedTypes.add(MatchType.menDoubles)),
                      ),
                      _TypeButton(
                        label: '女子W',
                        color: Colors.pink,
                        onPressed: () => setState(() => selectedTypes.add(MatchType.womenDoubles)),
                      ),
                      _TypeButton(
                        label: '混合W',
                        color: Colors.purple,
                        onPressed: () => setState(() => selectedTypes.add(MatchType.mixedDoubles)),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text('生成する試合:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (selectedTypes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('試合が選択されていません', style: TextStyle(fontSize: 14)),
                    ),
                  Wrap(
                    spacing: 8,
                    children: selectedTypes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final type = entry.value;
                      return Chip(
                        label: Text(_matchTypeName(type), style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setState(() => selectedTypes.removeAt(index)),
                        deleteIconColor: Colors.red,
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: selectedTypes.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(context);
                          _generateWithSettings(context, CourtSettings(selectedTypes));
                        },
                  child: const Text('生成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _matchTypeName(MatchType type) {
    switch (type) {
      case MatchType.menDoubles: return '男子W';
      case MatchType.womenDoubles: return '女子W';
      case MatchType.mixedDoubles: return '混合W';
    }
  }

  Future<void> _generateWithSettings(BuildContext context, CourtSettings settings) async {
    try {
      await widget.notifier.generateSessionWithSettings(settings);
      setState(() {
        _currentIndex = widget.notifier.sessions.length - 1;
        _selectedPlayer = null;
      });
    } catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('生成エラー'),
          content: Text(e.toString()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('履歴のクリア'),
        content: const Text('全ての試合履歴を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              widget.notifier.clearHistory();
              setState(() {
                _currentIndex = null;
                _selectedPlayer = null;
              });
              Navigator.pop(ctx);
            },
            child: const Text('クリア', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _RestingChip extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RestingChip({
    required this.player,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = player.gender == Gender.male ? Colors.blue : Colors.pink;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withOpacity(0.2) : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange : color.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(player.gender == Gender.male ? Icons.male : Icons.female, size: 14, color: isSelected ? Colors.orange : color.withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(
              player.name,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.orange.shade900 : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _TypeButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _PlayerTag extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PlayerTag({
    required this.player,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = player.gender == Gender.male ? Colors.blue : Colors.pink;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withOpacity(0.2) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.orange : color.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          player.name,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.orange.shade900 : color,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
