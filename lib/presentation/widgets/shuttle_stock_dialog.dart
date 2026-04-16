import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/entities/player.dart';
import '../../domain/entities/shuttle_stock.dart';
import '../../domain/repository/shuttle_stock_repository.dart';

class ShuttleStockDialog extends StatefulWidget {
  final ShuttleStockRepository repository;
  final List<Player> activePlayers;
  final bool isSelectionMode;

  const ShuttleStockDialog({
    super.key,
    required this.repository,
    required this.activePlayers,
    this.isSelectionMode = false,
  });

  @override
  State<ShuttleStockDialog> createState() => _ShuttleStockDialogState();
}

class _ShuttleStockDialogState extends State<ShuttleStockDialog> {
  late Future<List<ShuttleStock>> _stocksFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _stocksFuture = widget.repository.getAll();
    });
  }

  void _showAddEditDialog({ShuttleStock? stock}) {
    final nameController = TextEditingController(text: stock?.name);
    final priceController =
        TextEditingController(text: stock?.unitPrice.toStringAsFixed(0));
    String? selectedPayerId = stock?.payerId;
    bool isPerDozen = stock?.isPerDozen ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(stock == null ? '在庫を登録' : '在庫を編集',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              )),
                  const Spacer(),
                  if (stock != null)
                    IconButton.filledTonal(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('削除の確認'),
                            content: Text('「${stock.name}」を削除しますか？'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('キャンセル')),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('削除',
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true && stock.id != null) {
                          await widget.repository.delete(stock.id!);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _refresh();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '名称',
                  hintText: '例: ヨネックス エアロセンサ 700',
                  prefixIcon: const Icon(Icons.drive_file_rename_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(context, '価格設定'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.payments_outlined),
                        suffixText: '円',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('ダース')),
                        ButtonSegment(value: false, label: Text('1個')),
                      ],
                      selected: {isPerDozen},
                      onSelectionChanged: (v) =>
                          setDialogState(() => isPerDozen = v.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(context, '購入者 (支払人)'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedPayerId,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  filled: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('未指定')),
                  ...widget.activePlayers.map((p) =>
                      DropdownMenuItem(value: p.id, child: Text(p.name))),
                ],
                onChanged: (v) => setDialogState(() => selectedPayerId = v),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () async {
                  final name = nameController.text;
                  final price = double.tryParse(priceController.text) ?? 0;
                  if (name.isEmpty || price <= 0) return;

                  final newStock = ShuttleStock(
                    id: stock?.id,
                    name: name,
                    unitPrice: price,
                    isPerDozen: isPerDozen,
                    payerId: selectedPayerId,
                    purchaseDate: stock?.purchaseDate ?? DateTime.now(),
                  );

                  await widget.repository.save(newStock);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _refresh();
                },
                icon: const Icon(Icons.check),
                label: const Text('保存する'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2_rounded,
                color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 16),
          const Text('シャトル在庫',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const Spacer(),
          IconButton.filledTonal(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        height: 520,
        child: Column(
          children: [
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<ShuttleStock>>(
                future: _stocksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stocks = snapshot.data ?? [];
                  if (stocks.isEmpty) {
                    return _buildEmptyState(theme);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: stocks.length,
                    itemBuilder: (context, index) {
                      final stock = stocks[index];
                      final payer = widget.activePlayers
                          .where((p) => p.id == stock.payerId)
                          .firstOrNull;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                              color: theme.colorScheme.outlineVariant),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: widget.isSelectionMode
                              ? () => Navigator.pop(context, stock)
                              : () => _showAddEditDialog(stock: stock),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainer,
                                  child: Icon(Symbols.badminton,
                                      size: 24,
                                      color: theme.colorScheme.primary),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(stock.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '¥${stock.unitPrice.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                          Text(
                                            ' / ${stock.isPerDozen ? 'ダース' : '個'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          if (payer != null) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                payer.name,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  widget.isSelectionMode
                                      ? Icons.check_circle_outline
                                      : Icons.chevron_right,
                                  color: widget.isSelectionMode
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる',
                style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined,
                size: 48, color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Text('登録された在庫はありません',
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('右上の「＋」から追加してください',
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
        ],
      ),
    );
  }
}
