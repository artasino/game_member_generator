import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_member_generator/presentation/notifiers/player_notifier.dart';
import 'package:game_member_generator/presentation/notifiers/session_notifier.dart';

import '../../domain/entities/expense_item.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/shuttle_stock.dart';
import '../../domain/entities/shuttle_usage_record.dart';
import '../../domain/repository/expense_repository.dart';
import '../../domain/repository/shuttle_stock_repository.dart';
import '../../domain/repository/shuttle_usage_repository.dart';
import '../di/app_scope.dart';
import '../widgets/shuttle_history_dialog.dart';
import '../widgets/shuttle_stock_dialog.dart';

class ShuttleCalculationScreen extends StatefulWidget {
  final ShuttleUsageRepository shuttleRepository;
  final ShuttleStockRepository stockRepository;
  final ExpenseRepository expenseRepository;

  const ShuttleCalculationScreen({
    super.key,
    required this.shuttleRepository,
    required this.stockRepository,
    required this.expenseRepository,
  });

  @override
  State<StatefulWidget> createState() => ShuttleCalculationPageState();
}

class ShuttleCalculationPageState extends State<ShuttleCalculationScreen> {
  List<ExpenseEntry> _entries = [];

  late final PlayerNotifier _playerNotifier;
  late final SessionNotifier _sessionNotifier;
  bool _providersBound = false;
  bool _useGenderSplit = false;
  DateTime _selectedDate = DateTime.now();

  int? _manualMaleCollection;
  int? _manualFemaleCollection;

  Timer? _saveTimer;

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
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final state = await widget.expenseRepository.get();
    if (state != null) {
      setState(() {
        _entries = state.entries;
        _useGenderSplit = state.useGenderSplit;
        _manualMaleCollection = state.manualMaleCollection;
        _manualFemaleCollection = state.manualFemaleCollection;
      });
    } else {
      setState(() {
        _entries = [];
      });
    }
  }

  void _persistState() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      final state = ExpenseCalculationState(
        entries: _entries,
        useGenderSplit: _useGenderSplit,
        manualMaleCollection: _manualMaleCollection,
        manualFemaleCollection: _manualFemaleCollection,
      );
      widget.expenseRepository.save(state);
    });
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _persistState();
  }

  Future<bool> _saveRecord() async {
    final sessions = _sessionNotifier.sessions;
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
      return false;
    }

    try {
      await widget.shuttleRepository.save(ShuttleUsageRecord(
        date: _selectedDate,
        totalShuttles: totalShuttles,
        matchTypeCounts: typeCounts,
      ));
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました。もう一度お試しください')),
      );
      return false;
    }

    if (!mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('消費記録を保存しました')),
    );
    return true;
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
            _playerNotifier.players.where((p) => p.isActive).toList(),
      ),
    );
  }

  Future<ShuttleStock?> _pickStock() async {
    final activePlayers =
        _playerNotifier.players.where((p) => p.isActive).toList();
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('費用を追加',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
              ),
              ...ExpenseType.values.map((type) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: type.color.withValues(alpha: 0.1),
                    child: Icon(type.icon, color: type.color),
                  ),
                  title: Text(type.label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _addExpenseType(type);
                  },
                );
              }),
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
          unitPrice: 0,
          isPerDozen: true,
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
          unitPrice: selected.unitPrice,
          isPerDozen: selected.isPerDozen,
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
        unitPrice: 0,
        isPerDozen: true,
        shuttleCount: 0,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activePlayers =
        _playerNotifier.players.where((p) => p.isActive).toList();

    return ListenableBuilder(
      listenable:
          Listenable.merge([_playerNotifier, _sessionNotifier]),
      builder: (context, _) {
        final totalAmount = _entries.fold(0.0, (sum, item) => sum + item.total);

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            title: InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('費用計算',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2)),
                    Text(
                      '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ),
            centerTitle: true,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.inventory_2_outlined),
                tooltip: '在庫管理',
                onPressed: _showStockManager,
              ),
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: '履歴',
                onPressed: _showHistory,
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'reset') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('リセットの確認'),
                        content: const Text('入力した費用をすべて削除してもよろしいですか？'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('キャンセル')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('リセット',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      setState(() {
                        _entries.clear();
                        _manualMaleCollection = null;
                        _manualFemaleCollection = null;
                      });
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'reset',
                      child: ListTile(
                          leading: Icon(Icons.refresh, color: Colors.red),
                          title: Text('全てリセット',
                              style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero)),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              _buildModeSelectorHeader(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _entries.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                            itemCount: _entries.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _buildExpenseCard(index, activePlayers),
                          ),
                  ),
                ),
              ),
            ],
          ),
          bottomSheet: _entries.isEmpty
              ? null
              : _buildFeeNavigationPanel(totalAmount, activePlayers),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: FloatingActionButton.extended(
              heroTag: 'add_expense',
              onPressed: _showAddExpenseTypeSelector,
              icon: const Icon(Icons.add),
              label: const Text('出費を追加'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.payments_outlined,
            size: 64, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 16),
        Text('出費項目がありません',
            style: TextStyle(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 8),
        const Text('右下のボタンから出費を追加してください',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildModeSelectorHeader() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
            bottom: BorderSide(
                color: theme.colorScheme.outlineVariant, width: 0.5)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: false,
                  label: Text('均等',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13))),
              ButtonSegment(
                  value: true,
                  label: Text('男女',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13))),
            ],
            selected: {_useGenderSplit},
            onSelectionChanged: (v) {
              setState(() {
                _useGenderSplit = v.first;
                _manualMaleCollection = null;
                _manualFemaleCollection = null;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(int index, List<Player> activePlayers) {
    final entry = _entries[index];
    final theme = Theme.of(context);
    final payer = activePlayers.where((p) => p.id == entry.payerId).firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showExpenseDetailEditor(index, activePlayers),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: payer != null
                      ? (payer.gender == Gender.male
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.pink.withValues(alpha: 0.1))
                      : theme.colorScheme.surfaceContainerHighest,
                  child: payer != null
                      ? Text(payer.name.substring(0, 1),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: payer.gender == Gender.male
                                  ? Colors.blue
                                  : Colors.pink))
                      : Icon(Icons.person_outline,
                          size: 22, color: theme.colorScheme.outline),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(
                        payer != null ? '${payer.name}が支払い' : '支払人未設定',
                        style: TextStyle(
                            fontSize: 12,
                            color: payer != null
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${entry.total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (entry.type == ExpenseType.shuttle)
                      Text(
                        '${entry.shuttleCount}個使用',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right,
                    size: 20, color: theme.colorScheme.outlineVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeeNavigationPanel(
      double totalAmount, List<Player> activePlayers) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 両端に配置
        children: [
          // 左側：合計金額
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('合計金額',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              Text('¥${totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                      height: 1.2)),
            ],
          ),

          // 右側：ボタン（幅をコンテンツに合わせる）
          SizedBox(
            height: 50, // 高さを少し抑えてスマートに
            child: FilledButton.icon(
              onPressed: () => _showSettlementSheet(totalAmount, activePlayers),
              icon: const Icon(Icons.calculate_outlined, size: 20),
              label: const Text('支払調整',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                // 文字の横に適切な余白
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettlementSheet(
      double totalAmount, List<Player> activePlayers) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SettlementSheet(
        totalAmount: totalAmount,
        entries: _entries,
        activePlayers: activePlayers,
        useGenderSplit: _useGenderSplit,
        manualMaleCollection: _manualMaleCollection,
        manualFemaleCollection: _manualFemaleCollection,
        onManualCollectionChanged: (m, f) {
          setState(() {
            _manualMaleCollection = m;
            _manualFemaleCollection = f;
          });
        },
        onConfirm: () async {
          final saved = await _saveRecord();
          if (saved && mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showExpenseDetailEditor(int index, List<Player> activePlayers) {
    final entry = _entries[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('出費の編集',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () {
                      setState(() => _entries.removeAt(index));
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: entry.name,
                decoration: const InputDecoration(
                  labelText: '項目名',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => entry.name = v),
              ),
              const SizedBox(height: 16),
              const Text('支払った人',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: activePlayers.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('未設定'),
                          selected: entry.payerId == null,
                          onSelected: (v) => setModalState(
                              () => setState(() => entry.payerId = null)),
                        ),
                      );
                    }
                    final p = activePlayers[i - 1];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: p.gender == Gender.male
                              ? Colors.blue
                              : Colors.pink,
                          child: Text(p.name.substring(0, 1),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: Colors.white)),
                        ),
                        label: Text(p.name),
                        selected: entry.payerId == p.id,
                        onSelected: (v) => setModalState(
                            () => setState(() => entry.payerId = p.id)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (entry.type == ExpenseType.shuttle) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _modalTextField(
                        label: '単価',
                        suffix: '円',
                        initialValue: entry.unitPrice > 0
                            ? entry.unitPrice.toStringAsFixed(0)
                            : '',
                        onChanged: (v) => setModalState(() => setState(() => entry.unitPrice = double.tryParse(v) ?? 0)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                                value: true,
                                label: Text('ダース')),
                            ButtonSegment(
                                value: false,
                                label: Text('個')),
                          ],
                          selected: {entry.isPerDozen},
                          onSelectionChanged: (v) => setModalState(
                              () => setState(() => entry.isPerDozen = v.first)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _modalTextField(
                  label: '使用数',
                  suffix: '個',
                  initialValue: entry.shuttleCount > 0
                      ? entry.shuttleCount.toString()
                      : '',
                  onChanged: (v) => setModalState(() => setState(
                      () => entry.shuttleCount = int.tryParse(v) ?? 0)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: const Text('在庫から単価を読み込む'),
                    onPressed: () async {
                      final s = await _pickStock();
                      if (s != null) {
                        setModalState(() {
                          setState(() {
                            entry.name = s.name;
                            entry.unitPrice = s.unitPrice;
                            entry.isPerDozen = s.isPerDozen;
                            entry.payerId = s.payerId;
                          });
                        });
                      }
                    },
                  ),
                ),
              ] else ...[
                _modalTextField(
                  label: '金額',
                  suffix: '円',
                  initialValue:
                      entry.amount > 0 ? entry.amount.toStringAsFixed(0) : '',
                  onChanged: (v) => setModalState(() =>
                      setState(() => entry.amount = double.tryParse(v) ?? 0)),
                ),
              ],
              if (_useGenderSplit) ...[
                const SizedBox(height: 20),
                const Text('負担する対象',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<SplitTarget>(
                    segments: SplitTarget.values
                        .map((t) =>
                            ButtonSegment(value: t, label: Text(t.label)))
                        .toList(),
                    selected: {entry.target},
                    onSelectionChanged: (v) => setModalState(
                        () => setState(() => entry.target = v.first)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('完了'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalTextField(
      {required String label,
      required String suffix,
      required String initialValue,
      required Function(String) onChanged}) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.05),
      ),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      onChanged: onChanged,
    );
  }
}

class _SettlementSheet extends StatefulWidget {
  final double totalAmount;
  final List<ExpenseEntry> entries;
  final List<Player> activePlayers;
  final bool useGenderSplit;
  final int? manualMaleCollection;
  final int? manualFemaleCollection;
  final Function(int?, int?) onManualCollectionChanged;
  final VoidCallback onConfirm;

  const _SettlementSheet({
    required this.totalAmount,
    required this.entries,
    required this.activePlayers,
    required this.useGenderSplit,
    required this.manualMaleCollection,
    required this.manualFemaleCollection,
    required this.onManualCollectionChanged,
    required this.onConfirm,
  });

  @override
  State<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<_SettlementSheet> {
  late int? _m;
  late int? _f;

  @override
  void initState() {
    super.initState();
    _m = widget.manualMaleCollection;
    _f = widget.manualFemaleCollection;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maleCount =
        widget.activePlayers.where((p) => p.gender == Gender.male).length;
    final femaleCount =
        widget.activePlayers.where((p) => p.gender == Gender.female).length;
    final totalCount = maleCount + femaleCount;

    double maleShare = 0;
    double femaleShare = 0;

    if (!widget.useGenderSplit) {
      final perPerson = totalCount > 0 ? widget.totalAmount / totalCount : 0.0;
      maleShare = perPerson;
      femaleShare = perPerson;
    } else {
      for (var entry in widget.entries) {
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

    final mSuggested = maleShare.ceil();
    final fSuggested = femaleShare.ceil();

    final mCol = _m ?? ((mSuggested / 100).ceil() * 100);
    final fCol = _f ?? ((fSuggested / 100).ceil() * 100);
    final totalCollection = (mCol * maleCount) + (fCol * femaleCount);
    final balance = totalCollection - widget.totalAmount;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('精算・支払調整',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 24),
          _buildSummaryCard(
              theme, widget.totalAmount, totalCollection, balance),
          const SizedBox(height: 32),
          Text('集金額の設定',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildCollectionInput(
            label: widget.useGenderSplit ? '男子の集金額' : '1人あたりの集金額',
            suggested: mSuggested,
            value: mCol,
            color: Colors.blue,
            onChanged: (v) {
              setState(() => _m = int.tryParse(v));
              widget.onManualCollectionChanged(_m, _f);
            },
          ),
          if (widget.useGenderSplit) ...[
            const SizedBox(height: 16),
            _buildCollectionInput(
              label: '女子の集金額',
              suggested: fSuggested,
              value: fCol,
              color: Colors.pink,
              onChanged: (v) {
                setState(() => _f = int.tryParse(v));
                widget.onManualCollectionChanged(_m, _f);
              },
            ),
          ],
          const SizedBox(height: 32),
          _buildPayerList(theme),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: widget.onConfirm,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('支払確定・記録を保存',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      ThemeData theme, double total, int collection, double balance) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _summaryRow('合計出費', '¥${total.toStringAsFixed(0)}', Colors.grey),
          const SizedBox(height: 8),
          _summaryRow('徴収総額', '¥$collection', Colors.grey),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('収支（プラスが利益）',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                balance >= 0
                    ? '+¥${balance.toStringAsFixed(0)}'
                    : '¥${balance.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: balance >= 0 ? Colors.green : Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildCollectionInput({
    required String label,
    required int suggested,
    required int value,
    required Color color,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 4),
                Text('算定額: ¥$suggested',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        )),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: TextFormField(
              initialValue: value.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                suffixText: '円',
                isDense: true,
                border: InputBorder.none,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayerList(ThemeData theme) {
    final Map<String, double> payerTotals = {};
    final nameById = {for (final p in widget.activePlayers) p.id: p.name};
    for (final entry in widget.entries) {
      final payerName = nameById[entry.payerId] ?? '未設定';
      payerTotals[payerName] = (payerTotals[payerName] ?? 0) + entry.total;
    }

    if (payerTotals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('支払人ごとの立替額',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        ...payerTotals.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('¥${e.value.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            )),
      ],
    );
  }
}
