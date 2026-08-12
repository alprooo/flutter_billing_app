import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/thousands_separator_input_formatter.dart';
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
        content: Text('Belum ada produk yang dapat dicari.'),
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

  Future<void> _openSettings() async {
    // Settings can open Product Management, which in turn opens its own
    // barcode scanner. Release this page's camera first so Android never has
    // two scanner views competing for it.
    await _scannerController.stop();
    if (!mounted) return;
    await context.push('/settings');
    if (mounted && widget.isActive) {
      await _scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        // Dialogs handle the keyboard themselves. Keeping the POS layout at
        // its normal size prevents the scanner and cart from being compressed
        // behind a quantity dialog.
        resizeToAvoidBottomInset: false,
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
                label: 'Cek Total Belanja',
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
            : 'ANUGRAH FOTO';
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
            tooltip: 'Profil dan pengaturan',
            onPressed: _openSettings,
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
                          const Text('Total Belanja',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('$units barang',
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
                  ? const Center(
                      child: Text('Pindai barang untuk memulai penjualan.'))
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
              '${formatRupiah(item.product.price)} • Stok ${item.product.stock}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => context.read<BillingBloc>().add(
                    UpdateQuantityEvent(item.product.id, item.quantity - 1))),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _editCartQuantity(item),
              child: Container(
                constraints: const BoxConstraints(minWidth: 38),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => context.read<BillingBloc>().add(
                    UpdateQuantityEvent(item.product.id, item.quantity + 1))),
          ]),
        ),
      );

  Future<void> _editCartQuantity(CartItem item) async {
    final billingBloc = context.read<BillingBloc>();
    final quantity = await showDialog<int>(
      context: context,
      builder: (_) => _CartQuantityDialog(
        productName: item.product.name,
        currentQuantity: item.quantity,
        availableStock: item.product.stock,
      ),
    );
    if (!mounted || quantity == null || quantity == item.quantity) return;
    await Future<void>.delayed(kThemeAnimationDuration);
    if (!mounted) return;
    billingBloc.add(UpdateQuantityEvent(item.product.id, quantity));
  }
}

class _CartQuantityDialog extends StatefulWidget {
  final String productName;
  final int currentQuantity;
  final int availableStock;

  const _CartQuantityDialog({
    required this.productName,
    required this.currentQuantity,
    required this.availableStock,
  });

  @override
  State<_CartQuantityDialog> createState() => _CartQuantityDialogState();
}

class _CartQuantityDialogState extends State<_CartQuantityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _quantityController =
        TextEditingController(text: widget.currentQuantity.toString());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context)
        .pop(parseThousandsSeparatedInt(_quantityController.text)!);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: const Text('Atur jumlah'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _quantityController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: const [
              IndonesianThousandsSeparatorInputFormatter(),
            ],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: widget.productName,
              helperText: 'Stok tersedia: ${widget.availableStock}',
            ),
            validator: (value) {
              final quantity = parseThousandsSeparatedInt(value);
              if (quantity == null || quantity <= 0) {
                return 'Masukkan bilangan bulat lebih dari nol.';
              }
              if (quantity > widget.availableStock) {
                return 'Stok yang tersedia hanya ${widget.availableStock}.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal')),
          FilledButton(onPressed: _save, child: const Text('Perbarui')),
        ],
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
                  Text('Cari barang',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Cari nama produk untuk menambahkannya ke keranjang.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Tutup',
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
              hintText: 'Ketik nama produk',
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
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
            Text(_query.isEmpty ? 'SEMUA PRODUK' : 'PRODUK YANG COCOK',
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey)),
            const Spacer(),
            Text('${matches.length} ditemukan',
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
          Text('Produk tidak ditemukan',
              style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Coba nama produk yang berbeda.',
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
