import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/inventory_provider.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติสต็อก'),
        actions: [
          IconButton(
            onPressed: () => provider.loadHistory(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: provider.historyFilter,
              decoration: const InputDecoration(
                labelText: 'กรองประวัติ',
                border: OutlineInputBorder(),
              ),
              items: kHistoryFilters.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  provider.loadHistory(value);
                }
              },
            ),
          ),
          Expanded(
            child: provider.historyItems.isEmpty
                ? const Center(child: Text('ยังไม่มีประวัติการเคลื่อนไหว'))
                : ListView.builder(
                    itemCount: provider.historyItems.length,
                    itemBuilder: (context, index) {
                      final tx = provider.historyItems[index];
                      final isPositive = tx.quantity >= 0;

                      return ListTile(
                        leading: Icon(
                          isPositive
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                        title: Text(tx.itemName),
                        subtitle: Text(
                          '${kTxLabels[tx.txType] ?? tx.txType}\n'
                          '${tx.createdAt}\n'
                          '${tx.note}',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          '${isPositive ? '+' : ''}'
                          '${tx.quantity.toStringAsFixed(2)}\n'
                          'คงเหลือ ${tx.balanceAfter.toStringAsFixed(2)}',
                          textAlign: TextAlign.end,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
