import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/sale_transaction.dart';
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

  void _showSalesByUser(BuildContext context, TransactionState state) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SalesByUserSheet(
        transactions: state.transactions,
        date: state.selectedDate,
      ),
    );
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
                      child: Text('Transaksi',
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
                onSalesTap: () => _showSalesByUser(context, state),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: state.status == TransactionStatus.loading
                    ? const Center(child: CircularProgressIndicator())
                    : state.status == TransactionStatus.error
                        ? Center(
                            child: Text(state.message ??
                                'Tidak dapat memuat transaksi.'))
                        : state.transactions.isEmpty
                            ? const Center(
                                child:
                                    Text('Tidak ada transaksi pada hari ini.'))
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
                                            '${transaction.unitsSold} barang • ${DateFormat('HH:mm').format(transaction.completedAt)}\n${transaction.staffName}'),
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
  final VoidCallback onSalesTap;
  const _KpiRow(
      {required this.count,
      required this.units,
      required this.gross,
      required this.onSalesTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _card('Penjualan', '$count', onTap: onSalesTap),
            const SizedBox(width: 8),
            _card('Barang', '$units'),
            const SizedBox(width: 8),
            _card('Total', formatRupiah(gross)),
          ],
        ),
      );

  Widget _card(String label, String value, {VoidCallback? onTap}) => Expanded(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
            ),
          ),
        ),
      );
}

class _SalesByUserSheet extends StatelessWidget {
  final List<SaleTransaction> transactions;
  final DateTime date;
  const _SalesByUserSheet({required this.transactions, required this.date});

  @override
  Widget build(BuildContext context) {
    final summaries = <String, _UserSalesSummary>{};
    for (final transaction in transactions) {
      final existing = summaries[transaction.staffId];
      summaries[transaction.staffId] = _UserSalesSummary(
        name: transaction.staffName,
        transactionCount: (existing?.transactionCount ?? 0) + 1,
        total: (existing?.total ?? 0) + transaction.total,
      );
    }
    final sorted = summaries.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return SafeArea(
      top: false,
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .65),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            const CircleAvatar(child: Icon(Icons.groups_outlined)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Penjualan per pengguna',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(DateFormat('d MMMM y').format(date),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ]),
          const SizedBox(height: 16),
          Flexible(
            child: sorted.isEmpty
                ? const Center(
                    child: Text('Tidak ada penjualan pada hari ini.'))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final summary = sorted[index];
                      final initial = summary.name.isEmpty
                          ? '?'
                          : summary.name.characters.first.toUpperCase();
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(children: [
                          CircleAvatar(child: Text(initial)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(summary.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text('${summary.transactionCount} penjualan',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ]),
                          ),
                          Text(formatRupiah(summary.total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class _UserSalesSummary {
  final String name;
  final int transactionCount;
  final double total;
  const _UserSalesSummary({
    required this.name,
    required this.transactionCount,
    required this.total,
  });
}
