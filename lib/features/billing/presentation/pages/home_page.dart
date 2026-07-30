import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
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

  Future<void> _showManualBarcodeEntry() async {
    final controller = TextEditingController();
    final barcode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter barcode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Barcode number'),
            onSubmitted: Navigator.of(context).pop,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(controller.text),
            icon: const Icon(Icons.add),
            label: const Text('Add to cart'),
          ),
        ]),
      ),
    );
    controller.dispose();
    if (barcode != null) await _submitBarcode(barcode);
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
          Center(
            child: Container(
              width: 230,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
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
              _overlayButton(Icons.edit_note, _showManualBarcodeEntry),
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
