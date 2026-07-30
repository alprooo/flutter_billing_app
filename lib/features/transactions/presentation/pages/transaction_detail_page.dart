import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/sale_transaction.dart';

class TransactionDetailPage extends StatelessWidget {
  final SaleTransaction transaction;
  const TransactionDetailPage({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Transaction details')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(DateFormat('d MMM y, HH:mm').format(transaction.completedAt)),
            const SizedBox(height: 4),
            Text('Staff: ${transaction.staffName}'),
            const Divider(height: 32),
            ...transaction.items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.productName),
                  subtitle: Text(
                      '${item.quantity} × ${formatRupiah(item.unitPrice)}'),
                  trailing: Text(formatRupiah(item.total),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
            const Divider(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('TOTAL',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(formatRupiah(transaction.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20)),
            ]),
          ],
        ),
      );
}
