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
        TextEditingController(text: stock?.pricePerDozens.toStringAsFixed(0));
    String? selectedPayerId = stock?.payerId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(stock == null ? 'シャトル/ボール在庫を登録' : '在庫を編集'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: '名称 (例: エアロセンサ700)'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                    labelText: '1打あたりの価格', suffixText: '円'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedPayerId,
                decoration: const InputDecoration(labelText: '購入者 (支払人)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('未指定')),
                  ...widget.activePlayers.map((p) =>
                      DropdownMenuItem(value: p.id, child: Text(p.name))),
                ],
                onChanged: (v) => setDialogState(() => selectedPayerId = v),
              ),
            ],
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
                  pricePerDozens: price,
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
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('シャトル/ボール在庫一覧',
              style: TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: FutureBuilder<List<ShuttleStock>>(
          future: _stocksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final stocks = snapshot.data ?? [];
            if (stocks.isEmpty) {
              return const Center(child: Text('登録された在庫はありません'));
            }

            return ListView.separated(
              itemCount: stocks.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final stock = stocks[index];
                final payerName = widget.activePlayers
                        .where((p) => p.id == stock.payerId)
                        .map((p) => p.name)
                        .firstOrNull ??
                    '未指定';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(stock.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '¥${stock.pricePerDozens.toStringAsFixed(0)} / 打 | 支払: $payerName'),
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
                            if (stock.id != null) {
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
