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
    
    return AnimatedBuilder(
      animation: widget.notifier,
      builder: (context, _) {
        final sessions = widget.notifier.sessions;
        final bool isEmpty = sessions.isEmpty;

        if (isEmpty) {
          _currentIndex = null;
        } else if (_currentIndex == null || _currentIndex! >= sessions.length) {
          _currentIndex = sessions.length - 1;
        }

        final session = !isEmpty ? sessions[_currentIndex!] : null;
        final pool = widget.notifier.playerStatsPool;
        final bool isSwapping = _selectedPlayer != null;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            toolbarHeight: 56,
            backgroundColor: isSwapping ? Colors.orange : theme.colorScheme.primary,
            foregroundColor: isSwapping ? Colors.white : theme.colorScheme.onPrimary,
            title: isEmpty 
                ? const Text('試合履歴', style: TextStyle(fontWeight: FontWeight.w900))
                : (!isSwapping
                    ? _buildNormalHeaderContent(theme, session!, sessions.length)
                    : _buildSwapHeaderContent(_selectedPlayer!)),
            actions: !isSwapping ? [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: isEmpty ? null : () => _showClearConfirmDialog(context),
                tooltip: '履歴をクリア',
              ),
              const SizedBox(width: 8),
            ] : null,
          ),
          body: isEmpty 
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('試合履歴がありません', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final double screenWidth = constraints.maxWidth;
                    final double screenHeight = constraints.maxHeight;
                    final int gameCount = session!.games.length;

                    double scale = (screenWidth / 900.0).clamp(1.1, 1.8);
                    if (gameCount >= 4) scale *= 0.85;
                    if (screenHeight < 700) scale *= 0.85;

                    return Container(
                      color: theme.colorScheme.surface,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(16 * scale, 16 * scale, 16 * scale, 120),
                        child: Column(
                          children: [
                            _buildGamesArea(session, pool, scale, screenWidth),
                            SizedBox(height: 32 * scale),
                            if (session.restingPlayers.isNotEmpty)
                              _buildRestingContainer(session, theme, scale, screenWidth),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isEmpty) ...[
                FloatingActionButton.small(
                  heroTag: 'recalc',
                  onPressed: widget.notifier.isGenerating ? null : () => _showSettingsAndGenerate(context, isRecalculate: true),
                  tooltip: '再生成',
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: const Icon(Icons.refresh),
                ),
                const SizedBox(height: 12),
              ],
              FloatingActionButton.extended(
                heroTag: 'add',
                onPressed: widget.notifier.isGenerating ? null : () => _showSettingsAndGenerate(context, isRecalculate: false),
                tooltip: isEmpty ? '最初の試合を生成' : '次の試合を生成',
                icon: Icon(isEmpty ? Icons.play_arrow : Icons.add),
                label: Text(isEmpty ? '試合を生成' : '次を生成'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGamesArea(Session session, PlayerStatsPool pool, double scale, double screenWidth) {
    final int gameCount = session.games.length;
    int crossAxisCount = 1;
    if (gameCount == 4) {
      crossAxisCount = screenWidth > 850 ? 2 : 1;
    } else if (screenWidth > 1300 && gameCount >= 3) {
      crossAxisCount = 3;
    } else if (screenWidth > 800 && gameCount >= 2) {
      crossAxisCount = 2;
    }

    final double spacing = 16 * scale;
    final double cardWidth = (screenWidth - (spacing * (crossAxisCount + 1))) / crossAxisCount;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: session.games.asMap().entries.map((entry) {
        return SizedBox(
          width: cardWidth,
          child: _buildGameCard(context, entry.key, entry.value, Theme.of(context), pool, scale, session),
        );
      }).toList(),
    );
  }

  Widget _buildNormalHeaderContent(ThemeData theme, Session session, int total) {
    final onPrimary = theme.colorScheme.onPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 32),
          onPressed: _currentIndex! > 0 ? () {
            setState(() {
              _currentIndex = _currentIndex! - 1;
              _selectedPlayer = null;
            });
          } : null,
          color: onPrimary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('第 ${session.index} 試合', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('$total 試合中', style: TextStyle(fontSize: 10, color: onPrimary.withOpacity(0.7), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 32),
          onPressed: _currentIndex! < total - 1 ? () {
            setState(() {
              _currentIndex = _currentIndex! + 1;
              _selectedPlayer = null;
            });
          } : null,
          color: onPrimary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildSwapHeaderContent(Player selected) {
    return Row(
      children: [
        const Icon(Icons.swap_horizontal_circle, color: Colors.white, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('入れ替えモード', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold)),
              Text('${selected.name} と入れ替える', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _selectedPlayer = null),
          child: const Text('中止', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildGameCard(BuildContext context, int index, Game game, ThemeData theme, PlayerStatsPool pool, double scale, Session session) {
    final pairCountA = _getPairCountFromPool(pool, game.teamA);
    final pairCountB = _getPairCountFromPool(pool, game.teamB);

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16 * scale),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 8 * scale),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16 * scale)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events, size: 18 * scale, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('コート ${index + 1}', style: TextStyle(color: theme.colorScheme.primary, fontSize: 16 * scale, fontWeight: FontWeight.w900)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Text(_matchTypeName(game.type), style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10 * scale, 12 * scale, 10 * scale, 10 * scale),
            child: Row(
              children: [
                Expanded(child: _buildTeamColumn(session, game.teamA, pairCountA, scale)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                  child: Column(
                    children: [
                      Text('VS', style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w900, color: theme.colorScheme.outline.withOpacity(0.3))),
                      Container(width: 1.5, height: 50 * scale, color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
                    ],
                  ),
                ),
                Expanded(child: _buildTeamColumn(session, game.teamB, pairCountB, scale)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamColumn(Session session, Team team, int pairCount, double scale) {
    return Column(
      children: [
        _PlayerTag(
          player: team.player1,
          isSelected: _selectedPlayer?.id == team.player1.id,
          onTap: () => _handlePlayerTap(session, team.player1),
          onLongPress: () => _handlePlayerLongPress(team.player1),
          onDoubleTap: () => _handlePlayerLongPress(team.player1),
          scale: scale,
        ),
        SizedBox(height: 8 * scale),
        _PlayerTag(
          player: team.player2,
          isSelected: _selectedPlayer?.id == team.player2.id,
          onTap: () => _handlePlayerTap(session, team.player2),
          onLongPress: () => _handlePlayerLongPress(team.player2),
          onDoubleTap: () => _handlePlayerLongPress(team.player2),
          scale: scale,
        ),
        const SizedBox(height: 6),
        _PairInfoLabel(count: pairCount, team: team, scale: scale),
      ],
    );
  }

  Widget _buildRestingContainer(Session session, ThemeData theme, double scale, double maxWidth) {
    final restingScale = (scale * 0.85).clamp(1.0, 1.5);
    final males = session.restingPlayers.where((p) => p.gender == Gender.male).toList();
    final females = session.restingPlayers.where((p) => p.gender == Gender.female).toList();

    return Container(
      width: maxWidth,
      padding: EdgeInsets.all(16 * restingScale),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20 * restingScale),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('お休み中', style: TextStyle(fontSize: 14 * restingScale, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('計 ${session.restingPlayers.length} 名', style: TextStyle(fontSize: 10 * restingScale, color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (males.isNotEmpty)
                Expanded(
                  child: _RestingSubSection(label: '男性', players: males, color: Colors.blue, onPlayerTap: (p) => _handlePlayerTap(session, p), onPlayerLongPress: (p) => _handlePlayerLongPress(p), selectedPlayerId: _selectedPlayer?.id, scale: restingScale),
                ),
              if (males.isNotEmpty && females.isNotEmpty)
                SizedBox(width: 16 * restingScale),
              if (females.isNotEmpty)
                Expanded(
                  child: _RestingSubSection(label: '女性', players: females, color: Colors.pink, onPlayerTap: (p) => _handlePlayerTap(session, p), onPlayerLongPress: (p) => _handlePlayerLongPress(p), selectedPlayerId: _selectedPlayer?.id, scale: restingScale),
                ),
            ],
          ),
        ],
      ),
    );
  }

  int _getPairCountFromPool(PlayerStatsPool pool, Team team) {
    try {
      final p1WithStats = pool.all.firstWhere((p) => p.player.id == team.player1.id);
      return p1WithStats.stats.partnerCounts[team.player2.id] ?? 0;
    } catch (_) { return 0; }
  }

  String _matchTypeName(MatchType type) {
    switch (type) {
      case MatchType.menDoubles: return '男子W';
      case MatchType.womenDoubles: return '女子W';
      case MatchType.mixedDoubles: return '混合W';
    }
  }

  void _handlePlayerLongPress(Player player) => setState(() => _selectedPlayer = player);

  Future<void> _handlePlayerTap(Session currentSession, Player clickedPlayer) async {
    if (_selectedPlayer == null) return;
    if (_selectedPlayer!.id == clickedPlayer.id) { setState(() => _selectedPlayer = null); return; }

    final p1 = _selectedPlayer!;
    setState(() => _selectedPlayer = null);
    await _swapPlayers(currentSession, p1, clickedPlayer);
  }

  Future<void> _swapPlayers(Session session, Player p1, Player p2) async {
    List<Game> newGames = session.games.map((game) {
      Team newTeamA = _swapInTeam(game.teamA, p1, p2);
      Team newTeamB = _swapInTeam(game.teamB, p1, p2);
      return game.copyWith(teamA: newTeamA, teamB: newTeamB);
    }).toList();
    List<Player> newResting = session.restingPlayers.map((p) {
      if (p.id == p1.id) return p2; else if (p.id == p2.id) return p1; return p;
    }).toList();

    await widget.notifier.updateSession(session.copyWith(games: newGames, restingPlayers: newResting));
    if (mounted) setState(() {});
  }

  Team _swapInTeam(Team team, Player p1, Player p2) {
    Player newP1 = team.player1; Player newP2 = team.player2;
    if (team.player1.id == p1.id) newP1 = p2; else if (team.player1.id == p2.id) newP1 = p1;
    if (team.player2.id == p1.id) newP2 = p2; else if (team.player2.id == p2.id) newP2 = p1;
    return team.copyWith(player1: newP1, player2: newP2);
  }

  void _showSettingsAndGenerate(BuildContext context, {required bool isRecalculate}) {
    widget.notifier.getCurrentSettings().then((currentSettings) {
      if (!mounted) return;
      final sessions = widget.notifier.sessions;
      final currentSession = (isRecalculate && _currentIndex != null && sessions.isNotEmpty) ? sessions[_currentIndex!] : null;
      final initialMatchTypes = currentSession?.games.map((g) => g.type).toList();
      List<MatchType> selectedTypes = initialMatchTypes != null ? List.from(initialMatchTypes) : List.from(currentSettings.matchTypes);

      showDialog(context: context, builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          final res = widget.notifier.checkRequirements(selectedTypes);
          return AlertDialog(
            title: Text(isRecalculate ? '試合の再生成' : '試合の設定'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('マッチタイプを追加:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _TypeButton(label: '男子W', color: Colors.blue, onPressed: () => setState(() => selectedTypes.add(MatchType.menDoubles))),
                _TypeButton(label: '女子W', color: Colors.pink, onPressed: () => setState(() => selectedTypes.add(MatchType.womenDoubles))),
                _TypeButton(label: '混合W', color: Colors.purple, onPressed: () => setState(() => selectedTypes.add(MatchType.mixedDoubles))),
              ]),
              const Divider(height: 32),
              if (selectedTypes.isNotEmpty) ...[
                Wrap(spacing: 8, children: selectedTypes.asMap().entries.map((entry) => Chip(label: Text(_matchTypeName(entry.value).replaceAll('ダブルス', 'W'), style: const TextStyle(fontSize: 12)), onDeleted: () => setState(() => selectedTypes.removeAt(entry.key)), deleteIconColor: Colors.red)).toList()),
                const SizedBox(height: 16),
              ],
              if (!res.canGenerate && selectedTypes.isNotEmpty) Text(res.errorMessage ?? '', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
              ElevatedButton(onPressed: (!res.canGenerate || selectedTypes.isEmpty) ? null : () async {
                Navigator.pop(context);
                if (isRecalculate && currentSession != null) _recalculateSession(currentSession.index, CourtSettings(selectedTypes));
                else _generateWithSettings(CourtSettings(selectedTypes));
              }, child: Text(isRecalculate ? '再生成' : '生成')),
            ],
          );
        });
      });
    });
  }

  Future<void> _recalculateSession(int sessionIndex, CourtSettings settings) async {
    try {
      await widget.notifier.recalculateSession(sessionIndex, settings);
      if (!mounted) return;
      final idx = widget.notifier.sessions.indexWhere((s) => s.index == sessionIndex);
      if (idx != -1) setState(() => _currentIndex = idx);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('再生成しました'), duration: Duration(seconds: 1)));
    } catch (e) { if (mounted) _showErrorDialog(e.toString()); }
  }

  Future<void> _generateWithSettings(CourtSettings settings) async {
    try {
      await widget.notifier.generateSessionWithSettings(settings);
      if (!mounted) return;
      setState(() => _currentIndex = widget.notifier.sessions.length - 1);
    } catch (e) { if (mounted) _showErrorDialog(e.toString()); }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('エラー'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('履歴クリア'), 
      content: const Text('全ての試合履歴を削除しますか？\n（通算成績はリセットされません）'), 
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('戻る')), 
        TextButton(onPressed: () async { 
          Navigator.pop(ctx);
          await widget.notifier.clearHistory(); 
          if (mounted) {
            setState(() { 
              _currentIndex = null; 
              _selectedPlayer = null; 
            }); 
          }
        }, child: const Text('クリア', style: TextStyle(color: Colors.red)))
      ]
    ));
  }
}

class _RestingSubSection extends StatelessWidget {
  final String label; final List<Player> players; final Color color; final Function(Player) onPlayerTap; final Function(Player) onPlayerLongPress; final String? selectedPlayerId; final double scale;
  const _RestingSubSection({required this.label, required this.players, required this.color, required this.onPlayerTap, required this.onPlayerLongPress, this.selectedPlayerId, required this.scale});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: EdgeInsets.only(left: 4, bottom: 8 * scale), child: Row(
        children: [
          Container(width: 4, height: 16 * scale, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w900, color: color.withOpacity(0.85))),
        ],
      )),
      Wrap(spacing: 8 * scale, runSpacing: 8 * scale, children: players.map((p) => _RestingChip(player: p, isSelected: selectedPlayerId == p.id, onTap: () => onPlayerTap(p), onLongPress: () => onPlayerLongPress(p), scale: scale)).toList()),
    ]);
  }
}

class _PairInfoLabel extends StatelessWidget {
  final int count; final Team team; final double scale;
  const _PairInfoLabel({required this.count, required this.team, required this.scale});
  @override
  Widget build(BuildContext context) {
    final isMultiple = count > 1;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 2.5 * scale),
      decoration: BoxDecoration(
          color: isMultiple ? Colors.orange.withOpacity(0.1) : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: isMultiple ? Colors.orange.withOpacity(0.3) : Colors.grey.withValues(alpha: 0.2), width: 1.0)
      ),
      child: Text('ペア $count回目', style: TextStyle(fontSize: 9.5 * scale, color: isMultiple ? Colors.orange : Colors.grey.shade600, fontWeight: isMultiple ? FontWeight.w900 : FontWeight.bold)),
    );
  }
}

class _RestingChip extends StatelessWidget {
  final Player player; final bool isSelected; final VoidCallback onTap; final VoidCallback onLongPress; final double scale;
  const _RestingChip({required this.player, required this.isSelected, required this.onTap, required this.onLongPress, required this.scale});
  @override
  Widget build(BuildContext context) {
    final color = player.gender == Gender.male ? Colors.blue : Colors.pink;
    return GestureDetector(
      onTap: onTap, onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
        decoration: BoxDecoration(
            color: isSelected ? Colors.orange.withOpacity(0.25) : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16 * scale),
            border: Border.all(color: isSelected ? Colors.orange : color.withOpacity(0.3), width: 1.5)
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(player.name, style: TextStyle(fontSize: 14 * scale, color: isSelected ? Colors.orange.shade900 : Colors.black87, fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold))
        ]),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label; final Color color; final VoidCallback onPressed;
  const _TypeButton({required this.label, required this.color, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: color.withOpacity(0.1), foregroundColor: color, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 8)), onPressed: onPressed, child: Text(label, style: const TextStyle(fontSize: 11)));
  }
}

class _PlayerTag extends StatelessWidget {
  final Player player; final bool isSelected; final VoidCallback onTap; final VoidCallback onLongPress; final VoidCallback onDoubleTap; final double scale;
  const _PlayerTag({required this.player, required this.isSelected, required this.onTap, required this.onLongPress, required this.onDoubleTap, required this.scale});
  @override
  Widget build(BuildContext context) {
    final color = player.gender == Gender.male ? Colors.blue : Colors.pink;
    return GestureDetector(
      onTap: onTap, onLongPress: onLongPress, onDoubleTap: onDoubleTap,
      child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 10 * scale),
          decoration: BoxDecoration(
              color: isSelected ? Colors.orange.withOpacity(0.3) : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14 * scale),
              border: Border.all(color: isSelected ? Colors.orange : color.withValues(alpha: 0.5), width: isSelected ? 2.5 : 1.5)
          ),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      player.name,
                      style: TextStyle(
                          fontSize: 20 * scale,
                          color: isSelected ? Colors.orange.shade900 : Colors.black87,
                          fontWeight: FontWeight.w900
                      ),
                    ),
                  ),
                ),
              ]
          )),
    );
  }
}
