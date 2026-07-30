import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../domain/entities/cart_item.dart';
import '../bloc/billing_bloc.dart';

class HomePage extends StatefulWidget {
  final bool isActive;
  const HomePage({super.key, this.isActive = true});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );
  final Map<String, DateTime> _lastScanTimes = {};
  bool _isFlashOn = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      _scannerController.start();
    } else {
      _scannerController.stop();
    }
  }

  Future<void> _submitBarcode(String barcode) async {
    final value = barcode.trim();
    if (value.isEmpty) return;
    final last = _lastScanTimes[value];
    if (last != null && DateTime.now().difference(last).inSeconds < 2) return;
    _lastScanTimes[value] = DateTime.now();
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) Vibration.vibrate();
    if (mounted) context.read<BillingBloc>().add(ScanBarcodeEvent(value));
  }

  Future<void> _showManualProductSearch() async {
    final products = context.read<ProductBloc>().state.products;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No products are available to search.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManualProductSearchSheet(products: products),
    );
    if (!mounted || product == null) return;
    context.read<BillingBloc>().add(AddProductToCartEvent(product));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: BlocListener<BillingBloc, BillingState>(
          listenWhen: (previous, current) =>
              previous.error != current.error && current.error != null,
          listener: (context, state) =>
              ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
          ),
          child: Column(children: [
            SizedBox(
                height: MediaQuery.sizeOf(context).height * .38,
                child: _scannerSection()),
            Expanded(child: _cartPanel()),
          ]),
        ),
        bottomNavigationBar: BlocBuilder<BillingBloc, BillingState>(
          builder: (context, state) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: PrimaryButton(
                onPressed: state.cartItems.isEmpty
                    ? null
                    : () async {
                        await context.push('/checkout');
                        if (mounted) _scannerController.start();
                      },
                icon: Icons.payment,
                label: 'Review order',
              ),
            ),
          ),
        ),
      );

  Widget _scannerSection() => Container(
        color: Colors.black,
        child: Stack(fit: StackFit.expand, children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcode = capture.barcodes
                  .where((item) => item.rawValue != null)
                  .firstOrNull;
              if (barcode != null) _submitBarcode(barcode.rawValue!);
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 72,
            left: 16,
            right: 16,
            bottom: 16,
            child: LayoutBuilder(
              builder: (context, constraints) => Center(
                child: Container(
                  width: math.min(230, constraints.maxWidth),
                  height: math.min(180, constraints.maxHeight),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.greenAccent, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: _storeHeader(),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 68,
            right: 16,
            child: Column(children: [
              _overlayButton(
                _isFlashOn ? Icons.flashlight_off : Icons.flashlight_on,
                () {
                  setState(() => _isFlashOn = !_isFlashOn);
                  _scannerController.toggleTorch();
                },
              ),
              const SizedBox(height: 12),
              _overlayButton(Icons.search_rounded, _showManualProductSearch),
            ]),
          ),
        ]),
      );

  Widget _storeHeader() =>
      BlocBuilder<ShopBloc, ShopState>(builder: (context, state) {
        final name = state is ShopLoaded && state.shop.name.trim().isNotEmpty
            ? state.shop.name.trim()
            : 'Anugrah Ukui';
        final initial = name.characters.first.toUpperCase();
        return Row(children: [
          CircleAvatar(
              backgroundColor: AppTheme.primaryColor, child: Text(initial)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Profile & settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.account_circle_outlined,
                color: Colors.white, size: 30),
          ),
        ]);
      });

  Widget _overlayButton(IconData icon, VoidCallback onPressed) => Container(
        decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24)),
        child: IconButton(
            onPressed: onPressed, icon: Icon(icon, color: Colors.white)),
      );

  Widget _cartPanel() => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child:
            BlocBuilder<BillingBloc, BillingState>(builder: (context, state) {
          final units =
              state.cartItems.fold(0, (sum, item) => sum + item.quantity);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Scanned items',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('$units items',
                              style: const TextStyle(color: Colors.grey)),
                        ]),
                    Text(formatRupiah(state.totalAmount),
                        style: TextStyle(
                            fontSize: 20,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold)),
                  ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: state.cartItems.isEmpty
                  ? const Center(child: Text('Scan an item to begin a sale.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.cartItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) =>
                          _cartItem(state.cartItems[index]),
                    ),
            ),
          ]);
        }),
      );

  Widget _cartItem(CartItem item) => Card(
        child: ListTile(
          title: Text(item.product.name),
          subtitle: Text(
              '${formatRupiah(item.product.price)} • Stock ${item.product.stock}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => context.read<BillingBloc>().add(
                    UpdateQuantityEvent(item.product.id, item.quantity - 1))),
            Text('${item.quantity}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => context.read<BillingBloc>().add(
                    UpdateQuantityEvent(item.product.id, item.quantity + 1))),
          ]),
        ),
      );
}

class _ManualProductSearchSheet extends StatefulWidget {
  final List<Product> products;
  const _ManualProductSearchSheet({required this.products});

  @override
  State<_ManualProductSearchSheet> createState() =>
      _ManualProductSearchSheetState();
}

class _ManualProductSearchSheetState extends State<_ManualProductSearchSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.products
        .where((product) => product.name.toLowerCase().contains(_query))
        .toList();
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * .7,
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
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
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.search_rounded,
                  color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find an item',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Search by product name to add it to the cart',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ]),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Type a product name',
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Text(_query.isEmpty ? 'ALL PRODUCTS' : 'MATCHING PRODUCTS',
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey)),
            const Spacer(),
            Text('${matches.length} found',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: matches.isEmpty
                ? const _EmptyProductSearch()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _ProductSearchResult(product: matches[index]),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _EmptyProductSearch extends StatelessWidget {
  const _EmptyProductSearch();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined, size: 42, color: Colors.grey),
          SizedBox(height: 10),
          Text('No matching products',
              style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Try a different product name.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      );
}

class _ProductSearchResult extends StatelessWidget {
  final Product product;
  const _ProductSearchResult({required this.product});

  @override
  Widget build(BuildContext context) {
    final inStock = product.stock > 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: inStock ? () => Navigator.of(context).pop(product) : null,
        child: Opacity(
          opacity: inStock ? 1 : .55,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 5),
                    Text(formatRupiah(product.price),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: inStock
                      ? const Color(0xFFE8F7EE)
                      : const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                    inStock ? '${product.stock} in stock' : 'Out of stock',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: inStock ? const Color(0xFF198754) : Colors.red)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
