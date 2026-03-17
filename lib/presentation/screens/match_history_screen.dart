import 'package:flutter/material.dart';

import '../../domain/entities/court_settings.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/session.dart';
import '../notifiers/session_notifier.dart';
import '../widgets/match_history_widgets.dart';

extension LayoutScale on BoxConstraints {
  /// 画面サイズに基づいた動的なスケール値を計算（視認性と安定性のバランス）
  double calculateMatchScale(int gameCount) {
    // 基準幅を上げ、スケール範囲を 1.2〜2.0 に設定
    double scale = (maxWidth / 1000.0).clamp(1.2, 2.0);

    // 試合数が多い場合は少し縮小して全体を見やすくする
    if (gameCount >= 4) {
      scale *= 0.8;
    }
    return scale;
  }
}

class MatchHistoryScreen extends StatefulWidget {
  final SessionNotifier notifier;

  const MatchHistoryScreen({super.key, required this.notifier});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  int? _currentIndex;
  Player? _selectedPlayer;

  void _updateIndexSafely({int? targetIndex}) {
    if (!mounted) return;
    setState(() {
      final count = widget.notifier.sessions.length;
      if (count == 0) {
        _currentIndex = null;
      } else {
        _currentIndex = (targetIndex ?? count - 1).clamp(0, count - 1);
      }
      _selectedPlayer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.notifier,
      builder: (context, _) {
        final sessions = widget.notifier.sessions;

        if (sessions.isEmpty) {
          _currentIndex = null;
        } else if (_currentIndex == null || _currentIndex! >= sessions.length) {
          _currentIndex = sessions.length - 1;
        }

        final session = sessions.isNotEmpty ? sessions[_currentIndex!] : null;
        final bool isSwapping = _selectedPlayer != null;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 4,
            automaticallyImplyLeading: false,
            centerTitle: true,
            toolbarHeight: 64,
            backgroundColor:
                isSwapping ? colorScheme.primary : colorScheme.surface,
            foregroundColor:
                isSwapping ? colorScheme.onPrimary : colorScheme.onSurface,
            title: MatchHistoryHeader(
              isSwapping: isSwapping,
              session: session,
              total: sessions.length,
              currentIndex: _currentIndex,
              selectedPlayer: _selectedPlayer,
              onIndexChange: (idx) => _updateIndexSafely(targetIndex: idx),
              onCancelSwap: () => setState(() => _selectedPlayer = null),
              onMaximize: session != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullscreenMatchView(
                            session: session,
                            pool: widget.notifier.playerStatsPool,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            actions: isSwapping
                ? null
                : [
                    if (session != null)
                      IconButton(
                        tooltip: '履歴をクリア',
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 24),
                        onPressed: () => _showClearConfirm(context),
                      ),
                    const SizedBox(width: 8),
                  ],
          ),
          body: session == null
              ? _buildEmpty(colorScheme)
              : _buildContent(session),
          floatingActionButton: _buildFABs(session, colorScheme),
        );
      },
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded,
                size: 80, color: colorScheme.outlineVariant),
            const SizedBox(height: 20),
            Text(
              '試合履歴がありません',
              style: TextStyle(
                  color: colorScheme.outline,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );

  Widget _buildContent(Session session) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.calculateMatchScale(session.games.length);

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                EdgeInsets.fromLTRB(12 * scale, 12 * scale, 12 * scale, 180),
            child: Column(
              children: [
                // 試合エリア (3試合なら横に並ぶように内部で計算)
                GamesArea(
                  session: session,
                  pool: widget.notifier.playerStatsPool,
                  scale: scale,
                  screenWidth: constraints.maxWidth,
                  selectedPlayer: _selectedPlayer,
                  onPlayerTap: (p) => _handleTap(session, p),
                  onPlayerLongPress: (p) => setState(() => _selectedPlayer = p),
                ),
                // 休憩エリア (常に下側)
                if (session.restingPlayers.isNotEmpty) ...[
                  SizedBox(height: 32 * scale),
                  RestingContainer(
                    session: session,
                    scale: scale,
                    maxWidth: constraints.maxWidth,
                    selectedPlayerId: _selectedPlayer?.id,
                    onPlayerTap: (p) => _handleTap(session, p),
                    onPlayerLongPress: (p) =>
                        setState(() => _selectedPlayer = p),
                  ),
                ]
              ],
            ),
          );
        },
      );

  Widget _buildFABs(Session? session, ColorScheme colorScheme) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (session != null) ...[
            FloatingActionButton.small(
              heroTag: 'recalc',
              elevation: 4,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              onPressed: widget.notifier.isGenerating
                  ? null
                  : () => _showSettings(true),
              child: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(height: 16),
          ],
          FloatingActionButton.extended(
            heroTag: 'add',
            elevation: 6,
            onPressed: widget.notifier.isGenerating
                ? null
                : () => _showSettings(false),
            icon: Icon(
                session == null ? Icons.play_arrow_rounded : Icons.add_rounded),
            label: Text(
              session == null ? '試合を開始' : '次の試合へ',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
          ),
        ],
      );

  void _handleTap(Session session, Player p) async {
    if (_selectedPlayer == null) return;
    if (_selectedPlayer!.id != p.id) {
      await widget.notifier.swapPlayers(session, _selectedPlayer!, p);
    }
    setState(() => _selectedPlayer = null);
  }

  void _showSettings(bool isRecalc) async {
    final types = await showDialog<List<MatchType>>(
      context: context,
      builder: (context) => MatchSettingsDialog(
        notifier: widget.notifier,
        isRecalc: isRecalc,
        currentSession:
            isRecalc ? widget.notifier.sessions[_currentIndex!] : null,
      ),
    );
    if (types == null) return;

    try {
      if (isRecalc) {
        await widget.notifier.recalculateSession(
          widget.notifier.sessions[_currentIndex!].index,
          CourtSettings(types),
        );
        _updateIndexSafely(targetIndex: _currentIndex);
      } else {
        await widget.notifier.generateSessionWithSettings(CourtSettings(types));
        _updateIndexSafely();
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String m) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 12),
              Text('エラー')
            ],
          ),
          content: Text(m),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
          ],
        ),
      );

  void _showClearConfirm(BuildContext context) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('履歴をクリア'),
          content: const Text('これまでの全ての試合履歴が削除されます。よろしいですか？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.notifier.clearHistory();
                _updateIndexSafely();
              },
              child: Text(
                'クリアする',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
}
