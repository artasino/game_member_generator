import 'package:flutter/material.dart';

import '../../domain/entities/court_settings.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/session.dart';
import '../notifiers/session_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/match_history_widgets.dart';

const _kSessionAnimationDuration = Duration(milliseconds: 180);
const _kSessionAnimationCurve = Curves.easeOutCubic;

extension LayoutScale on BoxConstraints {
  /// 画面サイズに基づいた動的なスケール値を計算
  double calculateMatchScale(int gameCount) {
    // 基準幅 900.0 をベースに、1.0〜1.8 の範囲でスケーリング
    double scale = (maxWidth / 900.0).clamp(1.0, 1.8);

    // 試合数が多い（4試合など）場合は要素を 15% 縮小して全体のバランスを取る
    if (gameCount >= 4) {
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
            scrolledUnderElevation: 2,
            automaticallyImplyLeading: false,
            centerTitle: true,
            toolbarHeight: 56,
            backgroundColor:
                isSwapping ? colorScheme.tertiary : colorScheme.primary,
            foregroundColor:
                isSwapping ? colorScheme.onPrimary : colorScheme.onPrimary,
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
                    _buildPopupMenu(),
                  ],
          ),
          body: AnimatedSwitcher(
            duration: _kSessionAnimationDuration,
            reverseDuration: _kSessionAnimationDuration,
            switchInCurve: _kSessionAnimationCurve,
            switchOutCurve: _kSessionAnimationCurve,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0.0, 0.025),
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
            child: session == null
                ? KeyedSubtree(
                    key: const ValueKey('empty-history'),
                    child: _buildEmpty(colorScheme),
                  )
                : KeyedSubtree(
                    key: ValueKey('session-${session.index}'),
                    child: _buildContent(session),
                  ),
          ),
          floatingActionButton: _buildFABs(session, colorScheme),
        );
      },
    );
  }

  Widget _buildPopupMenu() {
    final canUndo = widget.notifier.canUndo;
    return PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'clear_history') {
            await _showClearConfirm(context);
          } else if (value == 'delete_session') {
            final session = _currentSessionOrNull();
            if (session != null) {
              await _showDeleteSessionConfirm(context, session.index);
            }
          } else if (value == 'undo_last') {
            await _showUndoLastConfirm(context);
          }
        },
        itemBuilder: (context) => [
              PopupMenuItem(
                value: 'undo_last',
                enabled: canUndo,
                child: ListTile(
                  leading: Icon(Icons.undo_rounded),
                  title: Text('一個前の状態に戻す'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete_session',
                child: ListTile(
                  leading: Icon(Icons.delete_forever_outlined),
                  title: Text('このセッションを削除'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear_history',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('全履歴を削除'),
                ),
              ),
            ]);
  }

  Widget _buildEmpty(ColorScheme colorScheme) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded,
                size: 64, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              '試合履歴がありません',
              style: TextStyle(
                  color: colorScheme.outline,
                  fontSize: 18,
                  fontWeight: FontWeight.w900), // 統一
            ),
          ],
        ),
      );

  Session? _currentSessionOrNull() {
    final sessions = widget.notifier.sessions;
    if (_currentIndex == null ||
        _currentIndex! < 0 ||
        _currentIndex! >= sessions.length) {
      return null;
    }
    return sessions[_currentIndex!];
  }

  Widget _buildContent(Session session) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.calculateMatchScale(session.games.length);
          final scopedPool =
              widget.notifier.getPlayerStatsPoolUpToSession(session.index);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
                  child: GamesArea(
                    session: session,
                    pool: scopedPool,
                    scale: scale,
                    screenWidth: (constraints.maxWidth -
                            MatchHistoryLayoutTokens.contentHorizontalPadding)
                        .clamp(0, double.infinity),
                    selectedPlayer: _selectedPlayer,
                    onPlayerTap: (p) => _handleTap(session, p),
                    onPlayerLongPress: (p) =>
                        setState(() => _selectedPlayer = p),
                  ),
                ),
              ),
              if (session.restingPlayers.isNotEmpty)
                RestingContainer(
                  session: session,
                  scale: scale,
                  maxWidth: constraints.maxWidth,
                  selectedPlayerId: _selectedPlayer?.id,
                  onPlayerTap: (p) => _handleTap(session, p),
                  onPlayerLongPress: (p) => setState(() => _selectedPlayer = p),
                  pool: scopedPool,
                ),
            ],
          );
        },
      );

  Widget _buildFABs(Session? session, ColorScheme colorScheme) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.fabBottomOffset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (session != null) ...[
              FloatingActionButton.small(
                heroTag: 'recalc',
                tooltip: 'このセッションを再作成',
                elevation: 2,
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                onPressed: widget.notifier.isGenerating
                    ? null
                    : () => _showSettings(true),
                child: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(height: 12),
            ],
            FloatingActionButton(
              heroTag: 'add',
              elevation: 4,
              tooltip: '試合を作成',
              onPressed: widget.notifier.isGenerating
                  ? null
                  : () => _showSettings(false),
              child: Icon(session == null
                  ? Icons.play_arrow_rounded
                  : Icons.add_rounded),
            ),
          ],
        ),
      );

  void _handleTap(Session session, Player p) async {
    if (_selectedPlayer == null) return;
    if (_selectedPlayer!.id != p.id) {
      await widget.notifier.swapPlayers(session, _selectedPlayer!, p);
    }
    setState(() => _selectedPlayer = null);
  }

  void _showSettings(bool isRecalc) async {
    final settings = await showDialog<CourtSettings>(
      context: context,
      builder: (context) => MatchSettingsDialog(
        notifier: widget.notifier,
        isRecalc: isRecalc,
        currentSession:
            isRecalc ? widget.notifier.sessions[_currentIndex!] : null,
      ),
    );
    if (settings == null) return;

    try {
      if (isRecalc) {
        await widget.notifier.recalculateSession(
          widget.notifier.sessions[_currentIndex!].index,
          settings,
        );
        _updateIndexSafely(targetIndex: _currentIndex);
      } else {
        await widget.notifier.generateSessionWithSettings(settings);
        _updateIndexSafely();
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String m) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
              SizedBox(width: 12),
              Text('エラー', style: TextStyle(fontWeight: FontWeight.w900))
            ],
          ),
          content: Text(m),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 18)))
          ],
        ),
      );

  Future<void> _showClearConfirm(BuildContext context) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('全履歴を削除',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text('これまでの全ての試合履歴が削除されます。よろしいですか？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _showFinalClearConfirm(context);
              },
              child: Text(
                'クリアする',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w900,
                    fontSize: 18),
              ),
            ),
          ],
        ),
      );

  Future<void> _showFinalClearConfirm(BuildContext context) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              const Text('最終確認', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: const Text(
            '本当に全ての履歴を削除してよろしいですか？',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('やめる',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () async {
                Navigator.pop(ctx); // ダイアログを閉じる
                await widget.notifier.clearHistory();
                _updateIndexSafely();
              },
              child: const Text(
                '削除',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
      );

  Future<void> _showDeleteSessionConfirm(
    BuildContext context,
    int sessionIndex,
  ) =>
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'このセッションを削除',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text('MATCH $sessionIndex を削除します。よろしいですか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'キャンセル',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _showFinalDeleteSessionConfirm(context, sessionIndex);
              },
              child: Text(
                '削除する',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _showFinalDeleteSessionConfirm(
    BuildContext context,
    int sessionIndex,
  ) =>
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              const Text('最終確認', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Text(
            'MATCH $sessionIndex を本当に削除してよろしいですか？',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'やめる',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.notifier.deleteSession(sessionIndex);
                _updateIndexSafely(targetIndex: _currentIndex);
              },
              child: const Text(
                '削除',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
      );

  Future<void> _showUndoLastConfirm(BuildContext context) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            '一個前の状態に戻す',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            '本当に戻していいですか？\n直前の操作（削除・生成・編集など）を取り消します。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'キャンセル',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.notifier.revertToPreviousState();
                _updateIndexSafely();
              },
              child: Text(
                '戻す',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      );
}
