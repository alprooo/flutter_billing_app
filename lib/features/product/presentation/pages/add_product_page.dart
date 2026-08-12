import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/thousands_separator_input_formatter.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _barcode = '';
  double _price = 0.0;
  int _stock = 0;

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcode = result;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final productState = context.read<ProductBloc>().state;
      final existingProduct =
          productState.products.where((p) => p.barcode == _barcode).firstOrNull;

      if (existingProduct != null) {
        if (_stock <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Masukkan jumlah restok lebih dari nol.'),
              backgroundColor: Colors.red));
          return;
        }
        context.read<ProductBloc>().add(
            RestockProduct(productId: existingProduct.id, quantity: _stock));
        context.pop();
        return;
      }

      if (_name.trim().isEmpty || _price <= 0 || _stock < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Masukkan nama produk, harga, dan stok yang valid.'),
            backgroundColor: Colors.red));
        return;
      }

      final product = Product(
        id: const Uuid().v4(),
        name: _name,
        barcode: _barcode,
        price: _price,
        stock: _stock,
      );

      context.read<ProductBloc>().add(AddProduct(product));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 28, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Tambah Produk',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InputLabel(text: 'Barcode'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(_barcode),
                          initialValue: _barcode,
                          decoration: const InputDecoration(
                            hintText: 'Pindai atau masukkan barcode',
                          ),
                          validator: AppValidators.required('Masukkan barcode'),
                          onSaved: (value) => _barcode = value!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: _scanBarcode,
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Ketuk ikon untuk membuka pemindai kamera',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Nama Produk'),
                  TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'contoh: Beras',
                    ),
                    textCapitalization: TextCapitalization.words,
                    onSaved: (value) => _name = value!,
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Harga'),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    inputFormatters: const [
                      IndonesianThousandsSeparatorInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      hintText: '0',
                      prefixText: 'Rp ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    onSaved: (value) => _price =
                        (parseThousandsSeparatedInt(value) ?? 0).toDouble(),
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Jumlah Stok Awal / Restok'),
                  TextFormField(
                    initialValue: '0',
                    keyboardType: TextInputType.number,
                    inputFormatters: const [
                      IndonesianThousandsSeparatorInputFormatter(),
                    ],
                    decoration: const InputDecoration(hintText: '0'),
                    onSaved: (value) =>
                        _stock = parseThousandsSeparatedInt(value) ?? -1,
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _submit,
          icon: Icons.add_circle,
          label: 'Tambah Produk',
        ));
  }
}
