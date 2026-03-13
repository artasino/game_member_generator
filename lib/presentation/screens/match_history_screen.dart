import 'package:flutter/material.dart';

import '../../domain/entities/court_settings.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/session.dart';
import '../notifiers/session_notifier.dart';
import '../widgets/match_history_widgets.dart';

extension LayoutScale on BoxConstraints {
  /// 画面サイズと試合数に基づいた動的なスケール値を計算
  double calculateMatchScale(int gameCount) {
    // 基本幅 900.0 を基準に 1.1〜1.8 倍でスケーリング
    double scale = (maxWidth / 900.0).clamp(1.1, 1.8);

    // 試合数が多い、または高さが低いデバイスでは要素を 15% 縮小して視認性を確保
    if (gameCount >= 4 || maxHeight < 700) {
      scale *= 0.85;
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

  /// インデックスを安全に更新するためのメソッド
  void _updateIndexSafely({int? targetIndex}) {
    if (!mounted) return;
    setState(() {
      final count = widget.notifier.sessions.length;
      if (count == 0) {
        _currentIndex = null;
      } else {
        // 引数があればそれを使用、なければ最後の要素を指す
        _currentIndex = (targetIndex ?? count - 1).clamp(0, count - 1);
      }
      _selectedPlayer = null; // ページ移動や更新時は選択を解除
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.notifier,
      builder: (context, _) {
        final sessions = widget.notifier.sessions;

        // データの整合性チェック
        if (sessions.isEmpty) {
          _currentIndex = null;
        } else if (_currentIndex == null || _currentIndex! >= sessions.length) {
          _currentIndex = sessions.length - 1;
        }

        final session = sessions.isNotEmpty ? sessions[_currentIndex!] : null;
        final bool isSwapping = _selectedPlayer != null;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            backgroundColor:
                isSwapping ? Colors.orange : theme.colorScheme.primary,
            foregroundColor:
                isSwapping ? Colors.white : theme.colorScheme.onPrimary,
            title: MatchHistoryHeader(
              isSwapping: isSwapping,
              session: session,
              total: sessions.length,
              currentIndex: _currentIndex,
              selectedPlayer: _selectedPlayer,
              onIndexChange: (idx) => _updateIndexSafely(targetIndex: idx),
              onCancelSwap: () => setState(() => _selectedPlayer = null),
            ),
            actions: isSwapping
                ? null
                : [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: session == null
                          ? null
                          : () => _showClearConfirm(context),
                    ),
                    const SizedBox(width: 8),
                  ],
          ),
          body: session == null ? _buildEmpty() : _buildContent(session),
          floatingActionButton: _buildFABs(session),
        );
      },
    );
  }

  Widget _buildEmpty() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('試合履歴がありません', style: TextStyle(color: Colors.grey))
          ],
        ),
      );

  Widget _buildContent(Session session) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.calculateMatchScale(session.games.length);

          return Container(
            color: Theme.of(context).colorScheme.surface,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  16.0 * scale, 16.0 * scale, 16.0 * scale, 120),
              child: Column(
                children: [
                  GamesArea(
                session: session,
                pool: widget.notifier.playerStatsPool,
                scale: scale,
                screenWidth: constraints.maxWidth,
                selectedPlayer: _selectedPlayer,
                onPlayerTap: (p) => _handleTap(session, p),
                onPlayerLongPress: (p) => setState(() => _selectedPlayer = p),
              ),
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
            ),
          );
        },
      );

  Widget _buildFABs(Session? session) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session != null) ...[
            FloatingActionButton.small(
              heroTag: 'recalc',
              onPressed: widget.notifier.isGenerating
                  ? null
                  : () => _showSettings(true),
              child: const Icon(Icons.refresh),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: widget.notifier.isGenerating
                ? null
                : () => _showSettings(false),
            icon: Icon(session == null ? Icons.play_arrow : Icons.add),
            label: Text(session == null ? '試合を生成' : '次を生成'),
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
        _updateIndexSafely(targetIndex: _currentIndex); // 現在の場所を維持
      } else {
        await widget.notifier.generateSessionWithSettings(CourtSettings(types));
        _updateIndexSafely(); // 最新（末尾）へ移動
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String m) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('エラー'),
          content: Text(m),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );

  void _showClearConfirm(BuildContext context) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('履歴クリア'),
          content: const Text('全ての試合履歴を削除しますか？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('戻る')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.notifier.clearHistory();
                _updateIndexSafely(); // 0になるので null になる
              },
              child: const Text('クリア', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
}