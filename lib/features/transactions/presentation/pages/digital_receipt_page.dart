import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/receipt_image_generator.dart';
import '../../domain/entities/sale_transaction.dart';

class DigitalReceiptPage extends StatefulWidget {
  final SaleTransaction transaction;

  const DigitalReceiptPage({super.key, required this.transaction});

  @override
  State<DigitalReceiptPage> createState() => _DigitalReceiptPageState();
}

class _DigitalReceiptPageState extends State<DigitalReceiptPage> {
  String? _receiptUrl;
  String? _uploadError;
  bool _isUploading = true;

  SaleTransaction get transaction => widget.transaction;

  @override
  void initState() {
    super.initState();
    _uploadReceipt();
  }

  Future<void> _uploadReceipt() async {
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        throw StateError('Sign in is required to create a digital receipt.');
      }
      if (currentUser.id != transaction.staffId) {
        throw StateError('This receipt belongs to a different staff account.');
      }

      final imageBytes = await ReceiptImageGenerator.generate(transaction);
      final path = '${currentUser.id}/${transaction.id}.png';
      await client.storage.from('receipts').uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
      final url = client.storage.from('receipts').getPublicUrl(path);
      if (!mounted) return;
      setState(() {
        _receiptUrl = url;
        _isUploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadError = error.toString();
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Digital Receipt'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/'),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 56),
              const SizedBox(height: 12),
              const Text('Payment complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(DateFormat('d MMM y, HH:mm').format(transaction.completedAt),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          transaction.shopName?.isNotEmpty == true
                              ? transaction.shopName!
                              : 'Anugrah Ukui',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ...transaction.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                      '${item.quantity} × ${item.productName}'),
                                ),
                                const SizedBox(width: 16),
                                Text(formatRupiah(item.total),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(formatRupiah(transaction.total),
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildReceiptCode(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.done),
                label: const Text('Done'),
              ),
            ],
          ),
        ),
      );

  Widget _buildReceiptCode() {
    if (_isUploading) {
      return const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Preparing digital receipt...'),
        ],
      );
    }

    if (_uploadError != null) {
      return Column(
        children: [
          const Icon(Icons.cloud_off, color: Colors.red, size: 36),
          const SizedBox(height: 8),
          const Text('Could not upload the receipt image.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _uploadReceipt,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      );
    }

    return Column(
      children: [
        Text('Scan to open the digital receipt',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey[700], fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          width: 190,
          height: 190,
          child: PrettyQrView.data(data: _receiptUrl!),
        ),
        const SizedBox(height: 12),
        Text('Receipt #${transaction.id.substring(0, 8).toUpperCase()}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}
