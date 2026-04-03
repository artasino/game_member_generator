import 'package:flutter/material.dart';
import 'package:game_member_generator/presentation/notifiers/player_notifier.dart';
import 'package:game_member_generator/presentation/notifiers/session_notifier.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/shuttle_stock.dart';
import '../../domain/entities/shuttle_usage_record.dart';
import '../../domain/repository/shuttle_stock_repository.dart';
import '../../domain/repository/shuttle_usage_repository.dart';
import '../widgets/shuttle_history_dialog.dart';
import '../widgets/shuttle_stock_dialog.dart';

enum ExpenseType {
  shuttle('消耗品', Symbols.badminton, Colors.orange),
  court('場所代', Icons.stadium, Colors.blue),
  other('その他', Icons.more_horiz, Colors.teal);

  final String label;
  final IconData icon;
  final Color color;

  const ExpenseType(this.label, this.icon, this.color);
}

enum SplitTarget {
  all('全員'),
  male('男子'),
  female('女子');

  final String label;

  const SplitTarget(this.label);
}

class ExpenseEntry {
  String name;
  ExpenseType type;
  double amount;
  double pricePerDozens;
  int shuttleCount;
  String? payerId;
  SplitTarget target;

  ExpenseEntry({
    required this.name,
    required this.type,
    this.amount = 0,
    this.pricePerDozens = 0,
    this.shuttleCount = 0,
    this.payerId,
    this.target = SplitTarget.all,
  });

  double get total {
    if (type == ExpenseType.shuttle) {
      return (pricePerDozens / 12) * shuttleCount;
    }
    return amount;
  }
}

class ShuttleCalculationScreen extends StatefulWidget {
  final PlayerNotifier playerNotifier;
  final SessionNotifier sessionNotifier;
  final ShuttleUsageRepository shuttleRepository;
  final ShuttleStockRepository stockRepository;

  const ShuttleCalculationScreen({
    super.key,
    required this.playerNotifier,
    required this.sessionNotifier,
    required this.shuttleRepository,
    required this.stockRepository,
  });

  @override
  State<StatefulWidget> createState() => ShuttleCalculationPageState();
}

class ShuttleCalculationPageState extends State<ShuttleCalculationScreen> {
  final List<ExpenseEntry> _entries = [];

  bool _useGenderSplit = false; // true: 男女ごとに計算, false: 全体化
  bool _showCompactDetails = false;

  Future<void> _saveRecord() async {
    final sessions = widget.sessionNotifier.sessions;
    final Map<MatchType, int> typeCounts = {};
    for (var s in sessions) {
      for (var g in s.games) {
        typeCounts[g.type] = (typeCounts[g.type] ?? 0) + 1;
      }
    }

    final totalShuttles = _entries
        .where((e) => e.type == ExpenseType.shuttle)
        .fold(0, (sum, e) => sum + e.shuttleCount);

    if (totalShuttles == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('シャトルの使用数が0です')),
      );
      return;
    }

    await widget.shuttleRepository.save(ShuttleUsageRecord(
      date: DateTime.now(),
      totalShuttles: totalShuttles,
      matchTypeCounts: typeCounts,
    ));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('消費記録を保存しました')),
    );
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (context) =>
          ShuttleHistoryDialog(repository: widget.shuttleRepository),
    );
  }

  void _showStockManager() {
    showDialog(
      context: context,
      builder: (context) => ShuttleStockDialog(
        repository: widget.stockRepository,
        activePlayers:
            widget.playerNotifier.players.where((p) => p.isActive).toList(),
      ),
    );
  }

  Future<void> _selectFromStock(int index) async {
    final ShuttleStock? selected = await _pickStock();
    if (selected != null) {
      setState(() {
        _entries[index].name = selected.name;
        _entries[index].pricePerDozens = selected.pricePerDozens;
        _entries[index].payerId = selected.payerId;
      });
    }
  }

  Future<ShuttleStock?> _pickStock() async {
    final activePlayers =
        widget.playerNotifier.players.where((p) => p.isActive).toList();
    return showDialog<ShuttleStock>(
      context: context,
      builder: (context) => ShuttleStockDialog(
        repository: widget.stockRepository,
        activePlayers: activePlayers,
        isSelectionMode: true,
      ),
    );
  }

  void _showAddExpenseTypeSelector() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('費用種別を選択',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
              ),
              ...ExpenseType.values.map((type) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: type.color.withOpacity(0.1),
                    child: Icon(type.icon, color: type.color),
                  ),
                  title: Text(type.label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _addExpenseType(type);
                  },
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addExpenseType(ExpenseType type) async {
    if (type != ExpenseType.shuttle) {
      setState(() {
        _entries.add(ExpenseEntry(
          name: type.label,
          type: type,
          pricePerDozens: 0,
          shuttleCount: 0,
        ));
      });
      return;
    }

    final bool? useStock = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('シャトル/ボール追加',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('在庫から選択'),
                subtitle: const Text('名称・単価・支払人を自動入力'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text('新規で入力'),
                subtitle: const Text('名称・単価を手動で入力'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );

    if (useStock == null) return;

    if (useStock) {
      final selected = await _pickStock();
      if (selected == null) return;
      setState(() {
        _entries.add(ExpenseEntry(
          name: selected.name,
          type: ExpenseType.shuttle,
          pricePerDozens: selected.pricePerDozens,
          shuttleCount: 0,
          payerId: selected.payerId,
        ));
      });
      return;
    }

    setState(() {
      _entries.add(ExpenseEntry(
        name: ExpenseType.shuttle.label,
        type: ExpenseType.shuttle,
        pricePerDozens: 0,
        shuttleCount: 0,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable:
            Listenable.merge([widget.playerNotifier, widget.sessionNotifier]),
        builder: (context, _) {
          final theme = Theme.of(context);
          final screenWidth = MediaQuery.sizeOf(context).width;
          final bool useCompactLayout = screenWidth < 860;
          final activePlayers =
              widget.playerNotifier.players.where((p) => p.isActive).toList();
          final maleCount =
              activePlayers.where((p) => p.gender == Gender.male).length;
          final femaleCount =
              activePlayers.where((p) => p.gender == Gender.female).length;
          final totalCount = maleCount + femaleCount;

          // --- 試合数と有効試合数の計算 ---
          final sessions = widget.sessionNotifier.sessions;
          final Map<MatchType, int> typeCounts = {};
          double maleEffectiveGames = 0;
          double femaleEffectiveGames = 0;

          for (var s in sessions) {
            for (var g in s.games) {
              typeCounts[g.type] = (typeCounts[g.type] ?? 0) + 1;
              if (g.type == MatchType.menDoubles) {
                maleEffectiveGames += 1.0;
              } else if (g.type == MatchType.womenDoubles) {
                femaleEffectiveGames += 1.0;
              } else {
                maleEffectiveGames += 0.5;
                femaleEffectiveGames += 0.5;
              }
            }
          }
          final totalGames = sessions.fold(0, (sum, s) => sum + s.games.length);

          // --- シャトル消費スピード計算 ---
          double totalShuttles = 0;
          double maleShuttles = 0;
          double femaleShuttles = 0;

          for (var entry
              in _entries.where((e) => e.type == ExpenseType.shuttle)) {
            final count = entry.shuttleCount.toDouble();
            totalShuttles += count;
            if (entry.target == SplitTarget.male) {
              maleShuttles += count;
            } else if (entry.target == SplitTarget.female) {
              femaleShuttles += count;
            } else {
              maleShuttles += count * 0.5;
              femaleShuttles += count * 0.5;
            }
          }

          final speedTotal = totalGames > 0 ? totalShuttles / totalGames : 0.0;
          final speedMale =
              maleEffectiveGames > 0 ? maleShuttles / maleEffectiveGames : 0.0;
          final speedFemale = femaleEffectiveGames > 0
              ? femaleShuttles / femaleEffectiveGames
              : 0.0;

          // --- 費用計算ロジック ---
          double totalAmount =
              _entries.fold(0, (sum, item) => sum + item.total);
          double maleShare = 0;
          double femaleShare = 0;

          if (!_useGenderSplit) {
            final perPerson = totalCount > 0 ? totalAmount / totalCount : 0.0;
            maleShare = perPerson;
            femaleShare = perPerson;
          } else {
            for (var entry in _entries) {
              final amount = entry.total;
              switch (entry.target) {
                case SplitTarget.all:
                  if (totalCount > 0) {
                    final share = amount / totalCount;
                    maleShare += share;
                    femaleShare += share;
                  }
                case SplitTarget.male:
                  if (maleCount > 0) {
                    maleShare += amount / maleCount;
                  }
                case SplitTarget.female:
                  if (femaleCount > 0) {
                    femaleShare += amount / femaleCount;
                  }
              }
            }
          }

          return Scaffold(
            backgroundColor: theme.colorScheme.surfaceContainerLow,
            appBar: AppBar(
              title: const Text('EXPENSE CALC',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              centerTitle: true,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.inventory_2_outlined),
                  tooltip: 'シャトル/ボール在庫管理',
                  onPressed: _showStockManager,
                ),
                IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: '保存',
                  onPressed: _saveRecord,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'history') _showHistory();
                    if (value == 'stock') _showStockManager();
                    if (value == 'reset') {
                      setState(() {
                        _entries.clear();
                        _entries.add(ExpenseEntry(
                            name: 'シャトル/ボール',
                            type: ExpenseType.shuttle,
                            pricePerDozens: 0,
                            shuttleCount: 0));
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'stock',
                        child: ListTile(
                            leading: Icon(Icons.inventory_2_outlined),
                            title: Text('シャトル/ボール在庫管理'),
                            contentPadding: EdgeInsets.zero)),
                    const PopupMenuItem(
                        value: 'history',
                        child: ListTile(
                            leading: Icon(Icons.history),
                            title: Text('履歴を表示'),
                            contentPadding: EdgeInsets.zero)),
                    const PopupMenuItem(
                        value: 'reset',
                        child: ListTile(
                            leading: Icon(Icons.refresh),
                            title: Text('リセット'),
                            contentPadding: EdgeInsets.zero)),
                  ],
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final bool showSideSummary = !useCompactLayout;
                final contentWidth = constraints.maxWidth
                    .clamp(0.0, showSideSummary ? 1320.0 : 1100.0)
                    .toDouble();

                Widget inputArea({required EdgeInsets listPadding}) {
                  return Column(
                    children: [
                      _buildInfoBar(maleCount, femaleCount, totalCount),
                      _buildModeSelectorHeader(),
                      _buildConsumptionSpeedBanner(totalGames, typeCounts,
                          speedTotal, speedMale, speedFemale),
                      Expanded(
                        child: ListView.builder(
                          padding: listPadding,
                          itemCount: _entries.length,
                          itemBuilder: (context, index) => _buildExpenseCard(
                              index, activePlayers, useCompactLayout),
                        ),
                      ),
                    ],
                  );
                }

                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: contentWidth,
                    child: showSideSummary
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: inputArea(
                                  listPadding:
                                      const EdgeInsets.fromLTRB(16, 4, 12, 16),
                                ),
                              ),
                              SizedBox(
                                width: 360,
                                child: _buildSideSummaryPanel(totalAmount,
                                    maleShare, femaleShare, activePlayers),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: inputArea(
                                  listPadding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                ),
                              ),
                              _buildSummaryPanel(totalAmount, maleShare,
                                  femaleShare, useCompactLayout, activePlayers),
                            ],
                          ),
                  ),
                );
              },
            ),
            bottomSheet: null,
            floatingActionButton: FloatingActionButton(
              onPressed: _showAddExpenseTypeSelector,
              tooltip: '費用を追加',
              child: const Icon(Icons.add),
            ),
          );
        });
  }

  Widget _buildInfoBar(int m, int f, int t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          _countChip("男子", m, Colors.blue),
          _countChip("女子", f, Colors.pink),
          _countChip("合計", t, Colors.grey.shade700),
        ],
      ),
    );
  }

  Widget _buildModeSelectorHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        width: double.infinity,
        height: 36,
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: false,
                label: Text('均等に割り勘',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ButtonSegment(
                value: true,
                label: Text('男女別に計算',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          selected: {_useGenderSplit},
          onSelectionChanged: (v) => setState(() => _useGenderSplit = v.first),
        ),
      ),
    );
  }

  Widget _buildConsumptionSpeedBanner(int games, Map<MatchType, int> typeCounts,
      double total, double male, double female) {
    final theme = Theme.of(context);

    final matchTypeSummary = MatchType.values
        .where((t) => (typeCounts[t] ?? 0) > 0)
        .map((t) => '${t.displayName}:${typeCounts[t]}')
        .join(', ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.speed, color: theme.colorScheme.secondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('消費スピード ($games 試合)',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary)),
                    if (matchTypeSummary.isNotEmpty)
                      Text('($matchTypeSummary)',
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 2),
                if (!_useGenderSplit)
                  Text('${total.toStringAsFixed(2)} 個 / 試合',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900))
                else
                  Row(
                    children: [
                      Text('男: ${male.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.blue.shade800)),
                      const SizedBox(width: 12),
                      Text('女: ${female.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.pink.shade800)),
                      const Spacer(),
                      Text('計: ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(
      int index, List<Player> activePlayers, bool useCompactLayout) {
    final entry = _entries[index];
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 10),
        child: Column(
          children: [
            Row(
              children: [
                Icon(entry.type.icon, size: 18, color: entry.type.color),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: _NameField(
                      key: ValueKey('name_${index}_${entry.name}'),
                      initialValue: entry.name,
                      onChanged: (v) => entry.name = v,
                    ),
                  ),
                ),
                if (entry.type == ExpenseType.shuttle)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.inventory_2_outlined,
                        size: 18, color: Colors.blue),
                    tooltip: '在庫から選択',
                    onPressed: () => _selectFromStock(index),
                  ),
                if (_useGenderSplit) _buildSplitTargetDropdown(entry),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                  onPressed: () => setState(() => _entries.removeAt(index)),
                ),
              ],
            ),
            const Divider(height: 1, thickness: 0.8),
            const SizedBox(height: 8),
            useCompactLayout
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      entry.type == ExpenseType.shuttle
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _compactTextField(
                                        key: ValueKey('price_$index'),
                                        label: '単価/ダース',
                                        suffix: '円',
                                        initialValue: entry.pricePerDozens > 0
                                            ? entry.pricePerDozens
                                                .toStringAsFixed(0)
                                            : '',
                                        onChanged: (v) => entry.pricePerDozens =
                                            double.tryParse(v) ?? 0,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      flex: 2,
                                      child: _compactTextField(
                                        key: ValueKey('count_$index'),
                                        label: '数',
                                        suffix: '個',
                                        initialValue: entry.shuttleCount > 0
                                            ? entry.shuttleCount.toString()
                                            : '',
                                        onChanged: (v) => entry.shuttleCount =
                                            int.tryParse(v) ?? 0,
                                      ),
                                    ),
                                  ],
                                ),
                                if (entry.shuttleCount > 0 &&
                                    entry.pricePerDozens > 0)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 6, left: 4),
                                    child: Text(
                                      '(¥${(entry.pricePerDozens / 12).toStringAsFixed(1)}/個 × ${entry.shuttleCount}個) = ',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ),
                              ],
                            )
                          : _compactTextField(
                              key: ValueKey('amount_$index'),
                              label: '金額',
                              suffix: '円',
                              initialValue: entry.amount > 0
                                  ? entry.amount.toStringAsFixed(0)
                                  : '',
                              onChanged: (v) =>
                                  entry.amount = double.tryParse(v) ?? 0,
                            ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _buildPayerDropdown(entry, activePlayers)),
                          const SizedBox(width: 8),
                          Text(
                            '¥${entry.total.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 入力エリア (左側)
                      Expanded(
                        flex: 65,
                        child: entry.type == ExpenseType.shuttle
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _compactTextField(
                                          key: ValueKey('price_$index'),
                                          label: '単価/ダース',
                                          suffix: '円',
                                          initialValue: entry.pricePerDozens > 0
                                              ? entry.pricePerDozens
                                                  .toStringAsFixed(0)
                                              : '',
                                          onChanged: (v) =>
                                              entry.pricePerDozens =
                                                  double.tryParse(v) ?? 0,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        flex: 2,
                                        child: _compactTextField(
                                          key: ValueKey('count_$index'),
                                          label: '数',
                                          suffix: '個',
                                          initialValue: entry.shuttleCount > 0
                                              ? entry.shuttleCount.toString()
                                              : '',
                                          onChanged: (v) => entry.shuttleCount =
                                              int.tryParse(v) ?? 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (entry.shuttleCount > 0 &&
                                      entry.pricePerDozens > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 6, left: 4),
                                      child: Text(
                                        '(¥${(entry.pricePerDozens / 12).toStringAsFixed(1)}/個 × ${entry.shuttleCount}個) = ',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                ],
                              )
                            : _compactTextField(
                                key: ValueKey('amount_$index'),
                                label: '金額',
                                suffix: '円',
                                initialValue: entry.amount > 0
                                    ? entry.amount.toStringAsFixed(0)
                                    : '',
                                onChanged: (v) =>
                                    entry.amount = double.tryParse(v) ?? 0,
                              ),
                      ),
                      const SizedBox(width: 8),
                      // 支払人・小計エリア (右側)
                      Expanded(
                        flex: 35,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildPayerDropdown(entry, activePlayers),
                            const SizedBox(height: 4),
                            Text(
                              '¥${entry.total.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitTargetDropdown(ExpenseEntry entry) {
    return Container(
      height: 24,
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButton<SplitTarget>(
        value: entry.target,
        underline: const SizedBox(),
        isDense: true,
        items: SplitTarget.values
            .map((t) => DropdownMenuItem(
                value: t,
                child: Text(t.label,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold))))
            .toList(),
        onChanged: (v) => setState(() {
          if (v != null) entry.target = v;
        }),
      ),
    );
  }

  Widget _buildPayerDropdown(ExpenseEntry entry, List<Player> activePlayers) {
    return SizedBox(
      height: 20,
      child: DropdownButton<String>(
        value: entry.payerId,
        underline: const SizedBox(),
        isExpanded: true,
        alignment: Alignment.centerRight,
        hint: const Text('支払人なし',
            style: TextStyle(fontSize: 9), textAlign: TextAlign.right),
        icon: const Icon(Icons.arrow_drop_down, size: 12),
        items: [
          const DropdownMenuItem<String>(
              value: null, child: Text('なし', style: TextStyle(fontSize: 10))),
          ...activePlayers.map((p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.name,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis)))
        ],
        onChanged: (v) => setState(() => entry.payerId = v),
      ),
    );
  }

  Widget _compactTextField({
    Key? key,
    required String label,
    required String suffix,
    required String initialValue,
    required Function(String) onChanged,
  }) {
    return SizedBox(
      height: 46,
      child: TextFormField(
        key: key,
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8))),
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        keyboardType: TextInputType.number,
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    );
  }

  Widget _buildSummaryPanel(double total, double mShare, double fShare,
      bool useCompactLayout, List<Player> activePlayers) {
    final theme = Theme.of(context);
    final mRound = (mShare / 100).ceil() * 100;
    final fRound = (fShare / 100).ceil() * 100;

    final Map<ExpenseType, double> typeTotals = {};
    for (var entry in _entries) {
      typeTotals[entry.type] = (typeTotals[entry.type] ?? 0) + entry.total;
    }
    final payerTotals = _buildPayerTotals(activePlayers);

    return Container(
      margin: const EdgeInsets.only(bottom: 76),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              useCompactLayout
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildSummaryTotal(theme, total)),
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _showCompactDetails = !_showCompactDetails;
                              }),
                              icon: Icon(
                                _showCompactDetails
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 16,
                              ),
                              label: Text(
                                _showCompactDetails ? '内訳を隠す' : '内訳を見る',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (_showCompactDetails) ...[
                          const SizedBox(height: 8),
                          _buildSummaryBreakdown(theme, typeTotals),
                          const SizedBox(height: 10),
                          _buildPayerSummary(theme, payerTotals),
                        ],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // カテゴリ別内訳
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryBreakdown(theme, typeTotals),
                              const SizedBox(height: 10),
                              _buildPayerSummary(theme, payerTotals),
                            ],
                          ),
                        ),
                        Container(
                            height: 30,
                            width: 1,
                            color: theme.colorScheme.outlineVariant,
                            margin: const EdgeInsets.symmetric(horizontal: 16)),
                        // 合計費用
                        Expanded(
                          flex: 4,
                          child: _buildSummaryTotal(theme, total),
                        ),
                      ],
                    ),
              const SizedBox(height: 12),
              if (!_useGenderSplit)
                _resultBox("集金額 (一人あたり)", mRound, theme.colorScheme.primary,
                    isLarge: true)
              else
                Row(
                  children: [
                    Expanded(
                        child:
                            _resultBox("男子集金", mRound, Colors.blue.shade800)),
                    const SizedBox(width: 12),
                    Expanded(
                        child:
                            _resultBox("女子集金", fRound, Colors.pink.shade800)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideSummaryPanel(double total, double mShare, double fShare,
      List<Player> activePlayers) {
    final theme = Theme.of(context);
    final mRound = (mShare / 100).ceil() * 100;
    final fRound = (fShare / 100).ceil() * 100;

    final Map<ExpenseType, double> typeTotals = {};
    for (var entry in _entries) {
      typeTotals[entry.type] = (typeTotals[entry.type] ?? 0) + entry.total;
    }
    final payerTotals = _buildPayerTotals(activePlayers);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 16, 84),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 230,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!_useGenderSplit)
                    _resultBox(
                        "集金額 (一人あたり)", mRound, theme.colorScheme.primary,
                        isLarge: true)
                  else
                    Row(
                      children: [
                        Expanded(
                            child: _resultBox(
                                "男子集金", mRound, Colors.blue.shade800)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _resultBox(
                                "女子集金", fRound, Colors.pink.shade800)),
                      ],
                    ),
                  const SizedBox(height: 10),
                  _buildSummaryTotal(theme, total, alignEnd: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryBreakdown(theme, typeTotals),
          const SizedBox(height: 10),
          _buildPayerSummary(theme, payerTotals),
        ],
      ),
    );
  }

  Widget _resultBox(String label, int value, Color color,
      {bool isLarge = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.8))),
          Text("¥$value",
              style: TextStyle(
                  fontSize: isLarge ? 26 : 20,
                  fontWeight: FontWeight.w900,
                  color: color)),
        ],
      ),
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text("$label: $count",
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.8))),
    );
  }

  Widget _buildSummaryBreakdown(
      ThemeData theme, Map<ExpenseType, double> typeTotals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("内訳",
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        ...ExpenseType.values
            .where((t) => (typeTotals[t] ?? 0) > 0)
            .map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Row(
                    children: [
                  Icon(t.icon, size: 9, color: t.color.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                      Expanded(
                          child: Text(t.label,
                              style: const TextStyle(fontSize: 10))),
                      Text("¥${typeTotals[t]!.toStringAsFixed(0)}",
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
      ],
    );
  }

  Widget _buildSummaryTotal(ThemeData theme, double total,
      {bool alignEnd = true}) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        const Text("総額",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text("¥${total.toStringAsFixed(0)}",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Map<String, double> _buildPayerTotals(List<Player> activePlayers) {
    final nameById = {for (final p in activePlayers) p.id: p.name};
    final Map<String, double> payerTotals = {};

    for (final entry in _entries) {
      final payerName = nameById[entry.payerId] ?? 'なし';
      payerTotals[payerName] = (payerTotals[payerName] ?? 0) + entry.total;
    }

    return Map.fromEntries(
      payerTotals.entries.toList()
        ..sort((a, b) {
          if (a.key == 'なし') return 1;
          if (b.key == 'なし') return -1;
          return a.key.compareTo(b.key);
        }),
    );
  }

  Widget _buildPayerSummary(ThemeData theme, Map<String, double> payerTotals) {
    if (payerTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("支払人別",
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        ...payerTotals.entries
            .where((entry) => entry.value > 0)
            .map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(entry.key,
                              style: const TextStyle(fontSize: 10))),
                      Text("¥${entry.value.toStringAsFixed(0)}",
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
      ],
    );
  }
}

class _NameField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _NameField({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _NameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _controller.selection =
          TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
        border: InputBorder.none,
        hintText: '項目名',
      ),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      onChanged: widget.onChanged,
      onTap: () {
        _controller.selection =
            TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      },
    );
  }
}
