import 'package:flutter/material.dart';

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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(stock == null ? '在庫を登録' : '在庫を編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    hintText: '例: ヨネックス エアロセンサ 700',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('価格設定',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: '価格',
                          suffixText: '円',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPayerId,
                  decoration: const InputDecoration(
                    labelText: '購入者 (支払人)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('未指定')),
                    ...widget.activePlayers.map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.name))),
                  ],
                  onChanged: (v) => setDialogState(() => selectedPayerId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル')),
            FilledButton(
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
                if (mounted) {
                  Navigator.pop(context);
                  _refresh();
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('シャトル在庫', style: TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
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
                        size: 48, color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 16),
                    Text('登録された在庫はありません',
                        style: TextStyle(color: theme.colorScheme.outline)),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: stocks.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final stock = stocks[index];
                final payerName = widget.activePlayers
                        .where((p) => p.id == stock.payerId)
                        .map((p) => p.name)
                        .firstOrNull ??
                    '未指定';

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  title: Text(stock.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '¥${stock.unitPrice.toStringAsFixed(0)}/${stock.isPerDozen ? 'ダース' : '個'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('支払: $payerName',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      if (!stock.isPerDozen)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                              ' (1ダースあたり ¥${(stock.unitPrice * 12).toStringAsFixed(0)})',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.outline)),
                        ),
                    ],
                  ),
                  onTap: widget.isSelectionMode
                      ? () => Navigator.pop(context, stock)
                      : () => _showAddEditDialog(stock: stock),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!widget.isSelectionMode)
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
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
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('削除',
                                          style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true && stock.id != null) {
                              await widget.repository.delete(stock.id!);
                              _refresh();
                            }
                          },
                        ),
                      if (widget.isSelectionMode)
                        const Icon(Icons.chevron_right, color: Colors.blue),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
      ],
    );
  }
}
