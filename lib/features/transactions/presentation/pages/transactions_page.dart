import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../bloc/transaction_bloc.dart';
import 'transaction_detail_page.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  Future<void> _pickDate(BuildContext context, DateTime selectedDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && context.mounted) {
      context.read<TransactionBloc>().add(LoadTransactions(date));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Transactions',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    TextButton.icon(
                      onPressed: () => _pickDate(context, state.selectedDate),
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                          DateFormat('d MMM y').format(state.selectedDate)),
                    ),
                  ],
                ),
              ),
              _KpiRow(
                count: state.transactionCount,
                units: state.unitsSold,
                gross: state.grossSales,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: state.status == TransactionStatus.loading
                    ? const Center(child: CircularProgressIndicator())
                    : state.status == TransactionStatus.error
                        ? Center(
                            child: Text(state.message ??
                                'Could not load transactions.'))
                        : state.transactions.isEmpty
                            ? const Center(
                                child: Text('No transactions for this day.'))
                            : RefreshIndicator(
                                onRefresh: () async => context
                                    .read<TransactionBloc>()
                                    .add(LoadTransactions(state.selectedDate)),
                                child: ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                  itemCount: state.transactions.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final transaction =
                                        state.transactions[index];
                                    return Card(
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                            child: Icon(Icons.receipt_long)),
                                        title: Text(
                                            formatRupiah(transaction.total),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        subtitle: Text(
                                            '${transaction.unitsSold} items • ${DateFormat('HH:mm').format(transaction.completedAt)}\n${transaction.staffName}'),
                                        isThreeLine: true,
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () => Navigator.of(context)
                                            .push(MaterialPageRoute(
                                          builder: (_) => TransactionDetailPage(
                                              transaction: transaction),
                                        )),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final int count;
  final int units;
  final double gross;
  const _KpiRow(
      {required this.count, required this.units, required this.gross});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _card('Sales', '$count'),
            const SizedBox(width: 8),
            _card('Units', '$units'),
            const SizedBox(width: 8),
            _card('Gross', formatRupiah(gross)),
          ],
        ),
      );

  Widget _card(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}
