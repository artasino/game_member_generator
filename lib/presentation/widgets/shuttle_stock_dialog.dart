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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(stock == null ? '在庫を登録' : '在庫を編集',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  if (stock != null)
                    IconButton(
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
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '名称',
                  hintText: '例: ヨネックス エアロセンサ 700',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.05),
                ),
              ),
              const SizedBox(height: 20),
              const Text('価格設定',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: '価格',
                        suffixText: '円',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: true,
                            label: Text('ダース', style: TextStyle(fontSize: 13))),
                        ButtonSegment(
                            value: false,
                            label: Text('1個', style: TextStyle(fontSize: 13))),
                      ],
                      selected: {isPerDozen},
                      onSelectionChanged: (v) =>
                          setDialogState(() => isPerDozen = v.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('購入者 (支払人)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedPayerId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('未指定')),
                  ...widget.activePlayers.map((p) =>
                      DropdownMenuItem(value: p.id, child: Text(p.name))),
                ],
                onChanged: (v) => setDialogState(() => selectedPayerId = v),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
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
                  child: const Text('保存',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Text('シャトル在庫', style: TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.add_circle,
                color: theme.colorScheme.primary, size: 28),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48,
                              color: theme.colorScheme.outlineVariant),
                          const SizedBox(height: 16),
                          Text('登録された在庫はありません',
                              style:
                                  TextStyle(color: theme.colorScheme.outline)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: stocks.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final stock = stocks[index];
                      final payer = widget.activePlayers
                          .where((p) => p.id == stock.payerId)
                          .firstOrNull;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(Symbols.badminton,
                              size: 20, color: theme.colorScheme.primary),
                        ),
                        title: Text(stock.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '¥${stock.unitPrice.toStringAsFixed(0)}/${stock.isPerDozen ? 'ダース' : '個'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (payer != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      payer.name,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: theme
                                              .colorScheme.onSurfaceVariant),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: widget.isSelectionMode
                            ? const Icon(Icons.check_circle_outline,
                                color: Colors.blue)
                            : Icon(Icons.edit_outlined,
                                size: 20, color: theme.colorScheme.outline),
                        onTap: widget.isSelectionMode
                            ? () => Navigator.pop(context, stock)
                            : () => _showAddEditDialog(stock: stock),
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
}
