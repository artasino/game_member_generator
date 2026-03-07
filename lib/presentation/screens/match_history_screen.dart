import 'package:flutter/material.dart';
import '../../domain/entities/court_settings.dart';
import '../../domain/entities/game.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_stats_pool.dart';
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
  Player? _selectedPlayer;

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
          final pool = widget.notifier.playerStatsPool;

          final restingMales = session.restingPlayers.where((p) => p.gender == Gender.male).toList();
          final restingFemales = session.restingPlayers.where((p) => p.gender == Gender.female).toList();

          return Column(
            children: [
              _buildNavigation(theme, session, sessions.length),
              
              if (_selectedPlayer != null)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.orange.withValues(alpha: 0.1),
                  width: double.infinity,
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horizontal_circle, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedPlayer!.name} と入れ替えるメンバを選択',
                        style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _selectedPlayer = null),
                        child: const Text('キャンセル', style: TextStyle(fontSize: 12)),
                      )
                    ],
                  ),
                ),
                
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth > 700;
                    
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isWide)
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: session.games.asMap().entries.map((entry) {
                                return SizedBox(
                                  width: (constraints.maxWidth - 36) / 2,
                                  child: _buildGameCard(context, entry.key, entry.value, session, pool, theme),
                                );
                              }).toList(),
                            )
                          else
                            ...session.games.asMap().entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildGameCard(context, entry.key, entry.value, session, pool, theme),
                              );
                            }).toList(),
                          
                          if (session.restingPlayers.isNotEmpty) 
                            _buildRestingContainer(session, restingMales, restingFemales, theme),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            onPressed: () => _showSettingsAndGenerate(context, isRecalculate: true),
            tooltip: 'この試合を再生成',
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: () => _showSettingsAndGenerate(context, isRecalculate: false),
            tooltip: '新しい試合を生成',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation(ThemeData theme, Session session, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 32),
            onPressed: _currentIndex! > 0 ? () => setState(() { _currentIndex = _currentIndex! - 1; _selectedPlayer = null; }) : null,
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              Text('第 ${session.index} 試合', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              Text('全 $total セッション', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 32),
            onPressed: _currentIndex! < total - 1 ? () => setState(() { _currentIndex = _currentIndex! + 1; _selectedPlayer = null; }) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, int index, Game game, Session session, PlayerStatsPool pool, ThemeData theme) {
    final pairCountA = _getPairCountFromPool(pool, game.teamA);
    final pairCountB = _getPairCountFromPool(pool, game.teamB);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                  child: Text('コート ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Text(_matchTypeName(game.type), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: _buildTeamColumn(session, game.teamA, pairCountA)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Text('VS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: theme.colorScheme.primary.withValues(alpha: 0.2))),
                      Container(width: 1, height: 40, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
                Expanded(child: _buildTeamColumn(session, game.teamB, pairCountB)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamColumn(Session session, Team team, int pairCount) {
    return Column(
      children: [
        _PlayerTag(
          player: team.player1,
          isSelected: _selectedPlayer?.id == team.player1.id,
          onTap: () => _handlePlayerTap(session, team.player1),
          onLongPress: () => _handlePlayerLongPress(team.player1),
          onDoubleTap: () => _handlePlayerLongPress(team.player1),
        ),
        const SizedBox(height: 6),
        _PlayerTag(
          player: team.player2,
          isSelected: _selectedPlayer?.id == team.player2.id,
          onTap: () => _handlePlayerTap(session, team.player2),
          onLongPress: () => _handlePlayerLongPress(team.player2),
          onDoubleTap: () => _handlePlayerLongPress(team.player2),
        ),
        const SizedBox(height: 4),
        _PairInfoLabel(count: pairCount, team: team),
      ],
    );
  }

  Widget _buildRestingContainer(Session session, List<Player> males, List<Player> females, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons. coffee_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text('お休み中のメンバ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (males.isNotEmpty) ...[
            _RestingSection(label: '男性', players: males, color: Colors.blue, onPlayerTap: (p) => _handlePlayerTap(session, p), onPlayerLongPress: (p) => _handlePlayerLongPress(p), selectedPlayerId: _selectedPlayer?.id),
            const SizedBox(height: 12),
          ],
          if (females.isNotEmpty) ...[
            _RestingSection(label: '女性', players: females, color: Colors.pink, onPlayerTap: (p) => _handlePlayerTap(session, p), onPlayerLongPress: (p) => _handlePlayerLongPress(p), selectedPlayerId: _selectedPlayer?.id),
          ],
        ],
      ),
    );
  }

  int _getPairCountFromPool(PlayerStatsPool pool, Team team) {
    try {
      final p1WithStats = pool.all.firstWhere((p) => p.player.id == team.player1.id);
      return p1WithStats.stats.partnerCounts[team.player2.id] ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String _matchTypeName(MatchType type) {
    switch (type) {
      case MatchType.menDoubles: return '男子ダブルス';
      case MatchType.womenDoubles: return '女子ダブルス';
      case MatchType.mixedDoubles: return '混合ダブルス';
    }
  }

  void _handlePlayerLongPress(Player player) {
    setState(() {
      _selectedPlayer = player;
    });
  }

  void _handlePlayerTap(Session currentSession, Player clickedPlayer) {
    if (_selectedPlayer == null) return;
    if (_selectedPlayer!.id == clickedPlayer.id) {
      setState(() => _selectedPlayer = null);
      return;
    }
    _swapPlayers(currentSession, _selectedPlayer!, clickedPlayer);
    setState(() => _selectedPlayer = null);
  }

  void _swapPlayers(Session session, Player p1, Player p2) {
    List<Game> newGames = session.games.map((game) {
      Team newTeamA = _swapInTeam(game.teamA, p1, p2);
      Team newTeamB = _swapInTeam(game.teamB, p1, p2);
      return game.copyWith(teamA: newTeamA, teamB: newTeamB);
    }).toList();
    List<Player> newResting = session.restingPlayers.map((p) {
      if (p.id == p1.id) {
        return p2;
      } else if (p.id == p2.id) {
        return p1;
      }
      return p;
    }).toList();
    widget.notifier.updateSession(session.copyWith(games: newGames, restingPlayers: newResting));
  }

  Team _swapInTeam(Team team, Player p1, Player p2) {
    Player newP1 = team.player1;
    Player newP2 = team.player2;
    if (team.player1.id == p1.id) {
      newP1 = p2;
    } else if (team.player1.id == p2.id) {
      newP1 = p1;
    }
    if (team.player2.id == p1.id) {
      newP2 = p2;
    } else if (team.player2.id == p2.id) {
      newP2 = p1;
    }
    return team.copyWith(player1: newP1, player2: newP2);
  }

  void _showSettingsAndGenerate(BuildContext context, {required bool isRecalculate}) {
    widget.notifier.getCurrentSettings().then((currentSettings) {
      if (!context.mounted) return;
      final sessions = widget.notifier.sessions;
      final currentSession = (isRecalculate && _currentIndex != null && sessions.isNotEmpty) ? sessions[_currentIndex!] : null;
      final initialMatchTypes = currentSession?.games.map((g) => g.type).toList();
      
      List<MatchType> selectedTypes = initialMatchTypes != null ? List.from(initialMatchTypes) : List.from(currentSettings.matchTypes);

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Text(isRecalculate ? '試合の再生成' : '次の試合の設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('マッチタイプを追加:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TypeButton(label: '男子W', color: Colors.blue, onPressed: () => setState(() => selectedTypes.add(MatchType.menDoubles))),
                      _TypeButton(label: '女子W', color: Colors.pink, onPressed: () => setState(() => selectedTypes.add(MatchType.womenDoubles))),
                      _TypeButton(label: '混合W', color: Colors.purple, onPressed: () => setState(() => selectedTypes.add(MatchType.mixedDoubles))),
                    ],
                  ),
                  const Divider(height: 32),
                  Wrap(
                    spacing: 8,
                    children: selectedTypes.asMap().entries.map((entry) {
                      return Chip(
                        label: Text(_matchTypeName(entry.value).replaceAll('ダブルス', 'W'), style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setState(() => selectedTypes.removeAt(entry.key)),
                        deleteIconColor: Colors.red,
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
                ElevatedButton(
                  onPressed: selectedTypes.isEmpty ? null : () async {
                    Navigator.pop(context);
                    if (isRecalculate && currentSession != null) {
                      _recalculateSession(context, currentSession.index, CourtSettings(selectedTypes));
                    } else {
                      _generateWithSettings(context, CourtSettings(selectedTypes));
                    }
                  },
                  child: Text(isRecalculate ? '再生成' : '生成'),
                ),
              ],
            );
          });
        },
      );
    });
  }

  Future<void> _recalculateSession(BuildContext context, int sessionIndex, CourtSettings settings) async {
    try {
      await widget.notifier.recalculateSession(sessionIndex, settings);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('試合を再生成しました'), duration: Duration(seconds: 1)));
    } catch (e) { _showErrorDialog(context, e.toString()); }
  }

  Future<void> _generateWithSettings(BuildContext context, CourtSettings settings) async {
    try {
      await widget.notifier.generateSessionWithSettings(settings);
      setState(() { _currentIndex = widget.notifier.sessions.length - 1; _selectedPlayer = null; });
    } catch (e) { _showErrorDialog(context, e.toString()); }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('エラー'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('履歴のクリア'), content: const Text('全ての試合履歴を削除しますか？'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')), TextButton(onPressed: () { widget.notifier.clearHistory(); setState(() { _currentIndex = null; _selectedPlayer = null; }); Navigator.pop(ctx); }, child: const Text('クリア', style: TextStyle(color: Colors.red)))]));
  }
}

class _RestingSection extends StatelessWidget {
  final String label;
  final List<Player> players;
  final Color color;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;
  final String? selectedPlayerId;

  const _RestingSection({required this.label, required this.players, required this.color, required this.onPlayerTap, required this.onPlayerLongPress, this.selectedPlayerId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8))),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: players.map((p) => _RestingChip(
            player: p,
            isSelected: selectedPlayerId == p.id,
            onTap: () => onPlayerTap(p),
            onLongPress: () => onPlayerLongPress(p),
          )).toList(),
        ),
      ],
    );
  }
}

class _PairInfoLabel extends StatelessWidget {
  final int count;
  final Team team;
  const _PairInfoLabel({required this.count, required this.team});
  @override
  Widget build(BuildContext context) {
    // 1回目でも表示されるように条件を削除。
    // 2回目以上の場合は目立つようにオレンジ、1回目は控えめにグレー系の色にする。
    final isMultiple = count > 1;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isMultiple ? Colors.orange.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isMultiple ? Colors.orange.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        'ペア $count回目', 
        style: TextStyle(
          fontSize: 9, 
          color: isMultiple ? Colors.orange : Colors.grey.shade600, 
          fontWeight: isMultiple ? FontWeight.bold : FontWeight.normal
        )
      ),
    );
  }
}

class _RestingChip extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _RestingChip({required this.player, required this.isSelected, required this.onTap, required this.onLongPress});
  @override
  Widget build(BuildContext context) {
    final color = player.gender == Gender.male ? Colors.blue : Colors.pink;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withValues(alpha: 0.2) : color.withValues(alpha: 0.08), 
          borderRadius: BorderRadius.circular(24), 
          border: Border.all(color: isSelected ? Colors.orange : color.withValues(alpha: 0.3), width: isSelected ? 1.5 : 1)
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(player.gender == Gender.male ? Icons.male : Icons.female, size: 14, color: isSelected ? Colors.orange : color), const SizedBox(width: 4), Text(player.name, style: TextStyle(fontSize: 16, color: isSelected ? Colors.orange.shade900 : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500))]),
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
    return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: color.withValues(alpha: 0.1), foregroundColor: color, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 8)), onPressed: onPressed, child: Text(label, style: const TextStyle(fontSize: 11)));
  }
}

class _PlayerTag extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;

  const _PlayerTag(
      {required this.player,
      required this.isSelected,
      required this.onTap,
      required this.onLongPress,
      required this.onDoubleTap});

  @override
  Widget build(BuildContext context) {
    final color = player.gender == Gender.male ? Colors.blue : Colors.pink;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: isSelected
                  ? Colors.orange.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected ? Colors.orange : color.withValues(alpha: 0.6),
                  width: isSelected ? 2.0 : 1.2)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                player.gender == Gender.male ? Icons.male : Icons.female,
                size: 20,
                color: isSelected ? Colors.orange.shade900 : color,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  player.name,
                  style: TextStyle(
                      fontSize: 18,
                      color: isSelected ? Colors.orange.shade900 : Colors.black,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )),
    );
  }
}
