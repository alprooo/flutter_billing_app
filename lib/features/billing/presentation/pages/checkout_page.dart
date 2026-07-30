import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../bloc/billing_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../../../product/presentation/bloc/product_bloc.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _checkoutRequested = false;
  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E5EA);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<TransactionBloc, TransactionState>(
        listener: (context, transactionState) {
          if (!_checkoutRequested) return;
          if (transactionState.status == TransactionStatus.completed) {
            _checkoutRequested = false;
            context.read<BillingBloc>().add(ClearCartEvent());
            context.read<ProductBloc>().add(LoadProducts());
            context
                .read<TransactionBloc>()
                .add(LoadTransactions(DateTime.now()));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Checkout complete'),
                backgroundColor: Colors.green));
            context.go('/');
          } else if (transactionState.status == TransactionStatus.error) {
            _checkoutRequested = false;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(transactionState.message ?? 'Checkout failed'),
                backgroundColor: Colors.red));
          }
        },
        child: BlocBuilder<BillingBloc, BillingState>(
          builder: (context, billingState) {
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Column(
                      children: [
                        // Table
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Table(
                              border: const TableBorder(
                                horizontalInside:
                                    BorderSide(color: borderColor),
                                bottom: BorderSide(color: borderColor),
                              ),
                              children: [
                                // Header row
                                TableRow(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    border: Border(
                                        bottom: BorderSide(color: borderColor)),
                                  ),
                                  children: [
                                    _buildHeaderCell(
                                        'Product Name', TextAlign.left),
                                    _buildHeaderCell('Price', TextAlign.right),
                                    _buildHeaderCell('Total', TextAlign.right),
                                  ],
                                ),
                                // Items rows
                                ...billingState.cartItems.map((item) {
                                  return TableRow(
                                    children: [
                                      _buildDataCell(
                                        '${item.quantity} x ${item.product.name}',
                                        TextAlign.left,
                                      ),
                                      _buildDataCell(
                                          formatRupiah(item.product.price),
                                          TextAlign.right,
                                          isSubtitle: true),
                                      _buildDataCell(formatRupiah(item.total),
                                          TextAlign.right,
                                          isBold: true),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const SizedBox(
                            height: 120), // padding for bottom fixed bar
                      ],
                    ),
                  ),
                ),

                // Bottom Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(24), right: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'GRAND TOTAL',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[400],
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  formatRupiah(billingState.totalAmount),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      BlocBuilder<TransactionBloc, TransactionState>(
                        builder: (context, transactionState) => PrimaryButton(
                          onPressed: transactionState.status ==
                                  TransactionStatus.completing
                              ? null
                              : () {
                                  _checkoutRequested = true;
                                  final shopState =
                                      context.read<ShopBloc>().state;
                                  context
                                      .read<TransactionBloc>()
                                      .add(CompleteCheckout(
                                        clientTransactionId: const Uuid().v4(),
                                        items: billingState.cartItems,
                                        shopName: shopState is ShopLoaded
                                            ? shopState.shop.name
                                            : null,
                                      ));
                                },
                          label: 'Checkout',
                          icon: transactionState.status ==
                                  TransactionStatus.completing
                              ? Icons.hourglass_top
                              : Icons.check_circle_outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, TextAlign align,
      {bool isBold = false, bool isSubtitle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isSubtitle ? 12 : 14,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: isSubtitle ? Colors.grey[500] : Colors.black87,
        ),
      ),
    );
  }
}
