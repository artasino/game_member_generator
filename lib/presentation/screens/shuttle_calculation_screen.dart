import 'package:flutter/material.dart';
import 'package:game_member_generator/presentation/notifiers/player_notifier.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/entities/gender.dart';
import '../../domain/entities/player.dart';

enum ExpenseType {
  shuttle('シャトル', Symbols.badminton, Colors.orange),
  court('場所代', Icons.stadium, Colors.blue),
  other('その他', Icons.more_horiz, Colors.teal);

  final String label;
  final IconData icon;
  final Color color;

  const ExpenseType(this.label, this.icon, this.color);
}

enum SplitTarget {
  all('全員'),
  male('男子のみ'),
  female('女子のみ');

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

  const ShuttleCalculationScreen({super.key, required this.playerNotifier});

  @override
  State<StatefulWidget> createState() => ShuttleCalculationPageState();
}

class ShuttleCalculationPageState extends State<ShuttleCalculationScreen> {
  final List<ExpenseEntry> _entries = [
    ExpenseEntry(
        name: 'シャトル',
        type: ExpenseType.shuttle,
        pricePerDozens: 0,
        shuttleCount: 0)
  ];

  bool _useGenderSplit = false; // true: 男女ごとに計算, false: 全体化

  @override
  Widget build(BuildContext context) {
    final activePlayers =
        widget.playerNotifier.players.where((p) => p.isActive).toList();
    final activeMales =
        activePlayers.where((p) => p.gender == Gender.male).toList();
    final activeFemales =
        activePlayers.where((p) => p.gender == Gender.female).toList();

    final maleCount = activeMales.length;
    final femaleCount = activeFemales.length;
    final totalCount = maleCount + femaleCount;

    double totalAmount = _entries.fold(0, (sum, item) => sum + item.total);

    // 計算ロジック
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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('EXPENSE CALC',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'リセット',
            onPressed: () => setState(() {
              _entries.clear();
              _entries.add(ExpenseEntry(
                  name: 'シャトル',
                  type: ExpenseType.shuttle,
                  pricePerDozens: 0,
                  shuttleCount: 0));
            }),
          )
        ],
      ),
      body: Column(
        children: [
          _buildInfoBar(maleCount, femaleCount, totalCount),
          _buildModeSelectorHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              itemCount: _entries.length,
              itemBuilder: (context, index) =>
                  _buildExpenseCard(index, activePlayers),
            ),
          ),
        ],
      ),
      bottomSheet: _buildSummaryPanel(totalAmount, maleShare, femaleShare),
      floatingActionButton: _buildAddButtonMenu(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildInfoBar(int m, int f, int t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _countChip("男子", m, Colors.blue),
          const SizedBox(width: 12),
          _countChip("女子", f, Colors.pink),
          const SizedBox(width: 12),
          _countChip("合計", t, Colors.grey.shade700),
        ],
      ),
    );
  }

  Widget _buildModeSelectorHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: false, label: Text('全員で均等割り'), icon: Icon(Icons.groups)),
            ButtonSegment(
                value: true,
                label: Text('男女別に計算'),
                icon: Icon(Icons.unfold_more)),
          ],
          selected: {_useGenderSplit},
          onSelectionChanged: (v) => setState(() => _useGenderSplit = v.first),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(int index, List<Player> activePlayers) {
    final entry = _entries[index];
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(entry.type.icon, size: 20, color: entry.type.color),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: entry.name,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: InputBorder.none,
                      hintText: '項目名',
                    ),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    onChanged: (v) => entry.name = v,
                  ),
                ),
                if (_useGenderSplit) _buildSplitTargetDropdown(entry),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 22),
                  onPressed: () => setState(() {
                    if (_entries.length > 1) _entries.removeAt(index);
                  }),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 8,
                  child: entry.type == ExpenseType.shuttle
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _compactTextField(
                                    label: '単価/打',
                                    suffix: '円',
                                    initialValue: entry.pricePerDozens > 0
                                        ? entry.pricePerDozens
                                            .toStringAsFixed(0)
                                        : '',
                                    onChanged: (v) => entry.pricePerDozens =
                                        double.tryParse(v) ?? 0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: _compactTextField(
                                    label: '個数',
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
                                padding: const EdgeInsets.only(top: 6, left: 4),
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
                          label: '合計金額',
                          suffix: '円',
                          initialValue: entry.amount > 0
                              ? entry.amount.toStringAsFixed(0)
                              : '',
                          onChanged: (v) =>
                              entry.amount = double.tryParse(v) ?? 0,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildPayerDropdown(entry, activePlayers),
                      const SizedBox(height: 4),
                      Text(
                        '¥${entry.total.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 22,
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
      height: 30,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
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
                        fontSize: 12, fontWeight: FontWeight.bold))))
            .toList(),
        onChanged: (v) => setState(() {
          if (v != null) entry.target = v;
        }),
      ),
    );
  }

  Widget _buildPayerDropdown(ExpenseEntry entry, List<Player> activePlayers) {
    return SizedBox(
      height: 28,
      child: DropdownButton<String>(
        value: entry.payerId,
        underline: const SizedBox(),
        isExpanded: true,
        alignment: Alignment.centerRight,
        hint: const Text('支払人未指定',
            style: TextStyle(fontSize: 11), textAlign: TextAlign.right),
        icon: const Icon(Icons.person_outline, size: 14, color: Colors.grey),
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        items: [
          const DropdownMenuItem<String>(
              value: null, child: Text('未指定', style: TextStyle(fontSize: 11))),
          ...activePlayers.map((p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.name,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis)))
        ],
        onChanged: (v) => setState(() => entry.payerId = v),
      ),
    );
  }

  Widget _compactTextField(
      {required String label,
      required String suffix,
      required String initialValue,
      required Function(String) onChanged}) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
          labelStyle: const TextStyle(fontSize: 11),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        keyboardType: TextInputType.number,
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    );
  }

  Widget _buildAddButtonMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ExpenseType.values
            .map((t) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _typeAddButton(t),
                ))
            .toList(),
      ),
    );
  }

  Widget _typeAddButton(ExpenseType type) {
    return ActionChip(
      avatar: Icon(type.icon, size: 16, color: type.color),
      label: Text(type.label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: () => setState(() {
        _entries.add(ExpenseEntry(
          name: type.label,
          type: type,
          pricePerDozens: 0,
          shuttleCount: 0,
        ));
      }),
    );
  }

  Widget _buildSummaryPanel(double total, double mShare, double fShare) {
    final theme = Theme.of(context);
    final mRound = (mShare / 100).ceil() * 100;
    final fRound = (fShare / 100).ceil() * 100;

    // カテゴリごとの合計を計算
    final Map<ExpenseType, double> typeTotals = {};
    for (var entry in _entries) {
      typeTotals[entry.type] = (typeTotals[entry.type] ?? 0) + entry.total;
    }

    return Container(
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左側: カテゴリごとの内訳
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("カテゴリ別合計",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary)),
                        const SizedBox(height: 6),
                        ...ExpenseType.values
                            .where((t) => (typeTotals[t] ?? 0) > 0)
                            .map((t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Row(
                                    children: [
                                      Icon(t.icon,
                                          size: 10,
                                          color: t.color.withOpacity(0.7)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                          child: Text(t.label,
                                              style: const TextStyle(
                                                  fontSize: 11))),
                                      Text(
                                          "¥${typeTotals[t]!.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )),
                      ],
                    ),
                  ),
                  Container(
                      height: 40,
                      width: 1,
                      color: theme.colorScheme.outlineVariant,
                      margin: const EdgeInsets.symmetric(horizontal: 20)),
                  // 右側: 合計
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("総額",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        Text("¥${total.toStringAsFixed(0)}",
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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

  Widget _resultBox(String label, int value, Color color,
      {bool isLarge = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color.withOpacity(0.8))),
          Text("¥$value",
              style: TextStyle(
                  fontSize: isLarge ? 32 : 24,
                  fontWeight: FontWeight.w900,
                  color: color)),
        ],
      ),
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text("$label: $count 名",
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.9))),
    );
  }
}
