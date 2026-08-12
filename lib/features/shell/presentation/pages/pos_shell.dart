import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../billing/presentation/pages/home_page.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../product/presentation/pages/product_list_page.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';

class PosShell extends StatefulWidget {
  final AppUser user;
  const PosShell({super.key, required this.user});

  @override
  State<PosShell> createState() => _PosShellState();
}

class _PosShellState extends State<PosShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<ProductBloc>().add(LoadProducts());
    context.read<TransactionBloc>().add(LoadTransactions(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(isActive: _selectedIndex == 0),
      const ProductListPage(embedded: true),
      const TransactionsPage(),
    ];
    return Scaffold(
      // The scanner and cart are nested inside this shell. Let dialogs and
      // sheets manage the keyboard so the shell does not squeeze the active
      // page into an overflow while editing a cart quantity.
      resizeToAvoidBottomInset: false,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.qr_code_scanner), label: 'Pindai'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), label: 'Stok'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Transaksi'),
        ],
      ),
    );
  }
}
