import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../transactions/domain/entities/sale_transaction.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';

class WebAdminDashboardPage extends StatefulWidget {
  final AppUser user;

  const WebAdminDashboardPage({super.key, required this.user});

  @override
  State<WebAdminDashboardPage> createState() => _WebAdminDashboardPageState();
}

class _WebAdminDashboardPageState extends State<WebAdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<TransactionBloc>().add(LoadTransactions(DateTime.now()));
  }

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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: BlocBuilder<TransactionBloc, TransactionState>(
          builder: (context, state) {
            final hourly = _buildHourlySummaries(state.transactions);
            final staff = _buildStaffSummaries(state.transactions);
            final products = _buildProductSummaries(state.transactions);
            final averageOrderValue = state.transactionCount == 0
                ? 0.0
                : state.grossSales / state.transactionCount;

            return RefreshIndicator(
              onRefresh: () async => context
                  .read<TransactionBloc>()
                  .add(LoadTransactions(state.selectedDate)),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF163B75), Color(0xFF215EC2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 16,
                      spacing: 16,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard Harian',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pantau transaksi ${DateFormat('EEEE, d MMMM y', 'id_ID').format(state.selectedDate)} untuk ${widget.user.displayName}.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _pickDate(context, state.selectedDate),
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                DateFormat('d MMM y').format(state.selectedDate),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 16),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => context
                                  .read<AuthBloc>()
                                  .add(const AuthSignOutRequested()),
                              icon: const Icon(Icons.logout),
                              label: const Text('Keluar'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF163B75),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _DashboardStatCard(
                        label: 'Total penjualan',
                        value: formatRupiah(state.grossSales),
                        note: '${state.transactionCount} transaksi',
                        accent: const Color(0xFF1D4ED8),
                        icon: Icons.payments_outlined,
                      ),
                      _DashboardStatCard(
                        label: 'Rata-rata transaksi',
                        value: formatRupiah(averageOrderValue),
                        note: 'Nilai per checkout',
                        accent: const Color(0xFF0F766E),
                        icon: Icons.trending_up_outlined,
                      ),
                      _DashboardStatCard(
                        label: 'Barang terjual',
                        value: '${state.unitsSold}',
                        note: '${products.length} produk aktif hari ini',
                        accent: const Color(0xFFB45309),
                        icon: Icons.inventory_2_outlined,
                      ),
                      _DashboardStatCard(
                        label: 'Kasir aktif',
                        value: '${staff.length}',
                        note: staff.isEmpty
                            ? 'Belum ada aktivitas'
                            : '${staff.first.name} tertinggi hari ini',
                        accent: const Color(0xFF7C3AED),
                        icon: Icons.group_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 1160;
                      if (stacked) {
                        return Column(
                          children: [
                            _SectionCard(
                              title: 'Penjualan per jam',
                              subtitle:
                                  'Jam paling ramai dan omzet harian dari transaksi masuk.',
                              child: _HourlySalesChart(hourly: hourly),
                            ),
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Performa kasir',
                              subtitle:
                                  'Siapa yang paling banyak menutup transaksi hari ini.',
                              child: _StaffLeaderboard(staff: staff),
                            ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _SectionCard(
                              title: 'Penjualan per jam',
                              subtitle:
                                  'Jam paling ramai dan omzet harian dari transaksi masuk.',
                              child: _HourlySalesChart(hourly: hourly),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _SectionCard(
                              title: 'Performa kasir',
                              subtitle:
                                  'Siapa yang paling banyak menutup transaksi hari ini.',
                              child: _StaffLeaderboard(staff: staff),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 1160;
                      final transactionSection = _SectionCard(
                        title: 'Transaksi terbaru',
                        subtitle:
                            'Daftar checkout hari ini dengan waktu dan nilai transaksi.',
                        child: _RecentTransactionsTable(
                          transactions: state.transactions,
                          loading: state.status == TransactionStatus.loading,
                          errorMessage:
                              state.status == TransactionStatus.error
                                  ? state.message
                                  : null,
                        ),
                      );
                      final productSection = _SectionCard(
                        title: 'Produk terlaris',
                        subtitle:
                            'Ringkasan produk paling laku berdasarkan jumlah item terjual.',
                        child: _TopProductsList(products: products),
                      );
                      if (stacked) {
                        return Column(
                          children: [
                            transactionSection,
                            const SizedBox(height: 16),
                            productSection,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: transactionSection),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: productSection),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  final Color accent;
  final IconData icon;

  const _DashboardStatCard({
    required this.label,
    required this.value,
    required this.note,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 96) / 4;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 220,
        maxWidth: math.max(260, width),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x110F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const Spacer(),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              note,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _HourlySalesChart extends StatelessWidget {
  final List<_HourSummary> hourly;

  const _HourlySalesChart({required this.hourly});

  @override
  Widget build(BuildContext context) {
    if (hourly.isEmpty) {
      return const _EmptyPanelMessage(
        message: 'Belum ada transaksi untuk divisualisasikan pada tanggal ini.',
      );
    }

    final peakRevenue = hourly
        .map((entry) => entry.revenue)
        .fold<double>(0, (best, value) => math.max(best, value));

    return Column(
      children: hourly
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      '${entry.hour.toString().padLeft(2, '0')}.00',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: peakRevenue == 0 ? 0 : entry.revenue / peakRevenue,
                        minHeight: 14,
                        backgroundColor: const Color(0xFFE5EEF9),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 170,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatRupiah(entry.revenue),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${entry.transactions} transaksi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StaffLeaderboard extends StatelessWidget {
  final List<_StaffSummary> staff;

  const _StaffLeaderboard({required this.staff});

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) {
      return const _EmptyPanelMessage(
        message: 'Belum ada performa kasir karena transaksi masih kosong.',
      );
    }

    return Column(
      children: staff
          .map(
            (summary) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFE0EAFF),
                    foregroundColor: const Color(0xFF1D4ED8),
                    child: Text(summary.initial),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${summary.transactionCount} transaksi • ${summary.unitsSold} barang',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatRupiah(summary.total),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RecentTransactionsTable extends StatelessWidget {
  final List<SaleTransaction> transactions;
  final bool loading;
  final String? errorMessage;

  const _RecentTransactionsTable({
    required this.transactions,
    required this.loading,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && transactions.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMessage != null) {
      return SizedBox(
        height: 220,
        child: Center(child: Text(errorMessage!)),
      );
    }
    if (transactions.isEmpty) {
      return const _EmptyPanelMessage(
        message: 'Tidak ada transaksi pada tanggal yang dipilih.',
      );
    }

    final dateFormat = DateFormat('HH:mm');
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text('Waktu')),
              Expanded(flex: 3, child: Text('Kasir')),
              Expanded(flex: 2, child: Text('Item')),
              Expanded(flex: 2, child: Text('Total')),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...transactions.map(
          (transaction) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(dateFormat.format(transaction.completedAt)),
                ),
                Expanded(flex: 3, child: Text(transaction.staffName)),
                Expanded(
                  flex: 2,
                  child: Text('${transaction.unitsSold} barang'),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatRupiah(transaction.total),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopProductsList extends StatelessWidget {
  final List<_ProductSummary> products;

  const _TopProductsList({required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _EmptyPanelMessage(
        message: 'Belum ada produk terjual pada tanggal ini.',
      );
    }

    return Column(
      children: products
          .take(8)
          .map(
            (product) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${product.quantity} barang • ${product.salesCount} transaksi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatRupiah(product.revenue),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyPanelMessage extends StatelessWidget {
  final String message;

  const _EmptyPanelMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }
}

List<_HourSummary> _buildHourlySummaries(List<SaleTransaction> transactions) {
  final summaries = <int, _HourSummary>{};
  for (final transaction in transactions) {
    final hour = transaction.completedAt.hour;
    final existing = summaries[hour];
    summaries[hour] = _HourSummary(
      hour: hour,
      revenue: (existing?.revenue ?? 0) + transaction.total,
      transactions: (existing?.transactions ?? 0) + 1,
    );
  }
  final ordered = summaries.values.toList()
    ..sort((a, b) => a.hour.compareTo(b.hour));
  return ordered;
}

List<_StaffSummary> _buildStaffSummaries(List<SaleTransaction> transactions) {
  final summaries = <String, _StaffSummary>{};
  for (final transaction in transactions) {
    final existing = summaries[transaction.staffId];
    summaries[transaction.staffId] = _StaffSummary(
      name: transaction.staffName,
      transactionCount: (existing?.transactionCount ?? 0) + 1,
      unitsSold: (existing?.unitsSold ?? 0) + transaction.unitsSold,
      total: (existing?.total ?? 0) + transaction.total,
    );
  }
  final ordered = summaries.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return ordered;
}

List<_ProductSummary> _buildProductSummaries(List<SaleTransaction> transactions) {
  final summaries = <String, _ProductSummary>{};
  for (final transaction in transactions) {
    for (final item in transaction.items) {
      final key = item.productId ?? item.barcode;
      final existing = summaries[key];
      summaries[key] = _ProductSummary(
        name: item.productName,
        quantity: (existing?.quantity ?? 0) + item.quantity,
        salesCount: (existing?.salesCount ?? 0) + 1,
        revenue: (existing?.revenue ?? 0) + item.total,
      );
    }
  }
  final ordered = summaries.values.toList()
    ..sort((a, b) {
      final quantityComparison = b.quantity.compareTo(a.quantity);
      if (quantityComparison != 0) {
        return quantityComparison;
      }
      return b.revenue.compareTo(a.revenue);
    });
  return ordered;
}

class _HourSummary {
  final int hour;
  final double revenue;
  final int transactions;

  const _HourSummary({
    required this.hour,
    required this.revenue,
    required this.transactions,
  });
}

class _StaffSummary {
  final String name;
  final int transactionCount;
  final int unitsSold;
  final double total;

  const _StaffSummary({
    required this.name,
    required this.transactionCount,
    required this.unitsSold,
    required this.total,
  });

  String get initial =>
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
}

class _ProductSummary {
  final String name;
  final int quantity;
  final int salesCount;
  final double revenue;

  const _ProductSummary({
    required this.name,
    required this.quantity,
    required this.salesCount,
    required this.revenue,
  });
}
