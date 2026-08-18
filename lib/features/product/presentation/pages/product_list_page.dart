import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/thousands_separator_input_formatter.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class ProductListPage extends StatefulWidget {
  final bool embedded;
  const ProductListPage({super.key, this.embedded = false});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
        () => setState(() => _query = _searchController.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Authenticated? get _authState {
    final state = context.read<AuthBloc>().state;
    return state is Authenticated ? state : null;
  }

  bool get _canAddProducts => _authState?.user.canAddProducts ?? false;
  bool get _canRestockProducts => _authState?.user.canRestockProducts ?? false;
  bool get _canEditProducts => _authState?.user.canEditProducts ?? false;
  bool get _canDeleteProducts => _authState?.user.canDeleteProducts ?? false;
  bool get _canImportProducts => _authState?.user.canImportProducts ?? false;

  Future<void> _scan() async {
    final barcode = await context.push<String>('/scanner');
    if (barcode != null) {
      _searchController.text = barcode;
    }
  }

  Future<void> _restock(Product product) async {
    final productBloc = context.read<ProductBloc>();
    final quantity = await showDialog<int>(
      context: context,
      builder: (_) => _RestockDialog(productName: product.name),
    );
    if (!mounted || quantity == null) return;
    // The dialog route is still leaving the widget tree when its Future
    // resolves. Wait for that close animation before notifying the page's
    // inherited Bloc, avoiding a widget-lifecycle assertion on Android.
    await Future<void>.delayed(kThemeAnimationDuration);
    if (!mounted) return;
    productBloc.add(RestockProduct(productId: product.id, quantity: quantity));
  }

  Future<void> _importCsv(List<Product> existing) async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    try {
      final rows = const CsvToListConverter()
          .convert(utf8.decode(result.files.single.bytes!));
      if (rows.length < 2) {
        throw const FormatException(
            'CSV harus memiliki header dan minimal satu produk.');
      }
      final headers = rows.first
          .map((value) => value.toString().trim().toLowerCase())
          .toList();
      const required = ['barcode', 'name', 'price', 'stock'];
      if (!required.every(headers.contains)) {
        throw const FormatException(
            'Header wajib: barcode, name, price, stock.');
      }
      final parsed = <Product>[];
      final errors = <String>[];
      final barcodes = <String>{...existing.map((item) => item.barcode)};
      for (var rowNumber = 1; rowNumber < rows.length; rowNumber++) {
        final row = rows[rowNumber];
        String value(String key) => row[headers.indexOf(key)].toString().trim();
        final barcode = value('barcode');
        final name = value('name');
        final price = double.tryParse(value('price'));
        final stock = int.tryParse(value('stock'));
        if (barcode.isEmpty ||
            name.isEmpty ||
            price == null ||
            price < 0 ||
            stock == null ||
            stock < 0 ||
            !barcodes.add(barcode)) {
          errors.add(
              'Baris ${rowNumber + 1}: nilai tidak valid atau barcode duplikat.');
          continue;
        }
        parsed.add(Product(
            id: const Uuid().v4(),
            barcode: barcode,
            name: name,
            price: price,
            stock: stock));
      }
      if (!mounted) {
        return;
      }
      if (errors.isNotEmpty) {
        await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Impor perlu diperbaiki'),
                  content:
                      SingleChildScrollView(child: Text(errors.join('\n'))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'))
                  ],
                ));
        return;
      }
      final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Impor produk'),
                content: Text(
                    'Impor ${parsed.length} produk baru? Barcode yang sudah ada tidak akan diubah.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Impor')),
                ],
              ));
      if (confirm == true && mounted) {
        context.read<ProductBloc>().add(ImportProducts(parsed));
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.message), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAddProducts = _canAddProducts;
    final canRestockProducts = _canRestockProducts;
    final canEditProducts = _canEditProducts;
    final canDeleteProducts = _canDeleteProducts;
    final canImportProducts = _canImportProducts;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('Stok'),
        actions: [
          if (canImportProducts)
            IconButton(
                onPressed: () =>
                    _importCsv(context.read<ProductBloc>().state.products),
                icon: const Icon(Icons.upload_file),
                tooltip: 'Impor CSV')
        ],
      ),
      body: BlocConsumer<ProductBloc, ProductState>(
        listener: (context, state) {
          if (state.status == ProductStatus.success ||
              state.status == ProductStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.message ?? ''),
                backgroundColor: state.status == ProductStatus.success
                    ? Colors.green
                    : Colors.red));
          }
        },
        builder: (context, state) {
          final totalProducts = state.products.length;
          final products = state.products
              .where((product) =>
                  product.name.toLowerCase().contains(_query) ||
                  product.barcode.toLowerCase().contains(_query))
              .toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Cari atau masukkan barcode'))),
                const SizedBox(width: 8),
                IconButton(
                    onPressed: _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    color: AppTheme.primaryColor),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _query.isEmpty
                          ? '$totalProducts produk'
                          : '${products.length} dari $totalProducts produk',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (canAddProducts)
                    FilledButton.icon(
                      onPressed: () => context.push('/products/add'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah / Restok'),
                    ),
                ],
              ),
            ),
            if (canAddProducts || canRestockProducts)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    canEditProducts
                        ? 'Gunakan tombol pada setiap produk untuk restok, edit, atau hapus.'
                        : 'Akun staff bisa tambah produk baru dan restok stok dari halaman ini.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ),
              ),
            Expanded(
              child: state.status == ProductStatus.loading &&
                      state.products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? const Center(child: Text('Produk tidak ditemukan.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: products.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final actions = <Widget>[
                              if (canRestockProducts)
                                IconButton(
                                  onPressed: () => _restock(product),
                                  icon: const Icon(Icons.add_box_outlined),
                                  tooltip: 'Restok',
                                ),
                              if (canEditProducts)
                                IconButton(
                                  onPressed: () => context.push(
                                    '/products/edit/${product.id}',
                                    extra: product,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              if (canDeleteProducts)
                                IconButton(
                                  onPressed: () => _confirmDelete(product),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                            ];
                            return Card(
                              child: ListTile(
                                title: Text(product.name),
                                subtitle: Text(
                                  '${product.barcode}\nStok: ${product.stock} • ${formatRupiah(product.price)}',
                                ),
                                isThreeLine: true,
                                trailing: actions.isEmpty
                                    ? null
                                    : Wrap(spacing: 0, children: actions),
                              ),
                            );
                          },
                        ),
            ),
          ]);
        },
      ),
      floatingActionButton: canAddProducts
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/products/add'),
              icon: const Icon(Icons.add),
              label: const Text('Tambah / Restok'))
          : null,
    );
  }

  void _confirmDelete(Product product) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: const Text('Hapus produk'),
            content: Text('Hapus ${product.name}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal')),
              FilledButton(
                  onPressed: () {
                    context.read<ProductBloc>().add(DeleteProduct(product.id));
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Hapus')),
            ],
          ));
}

class _RestockDialog extends StatefulWidget {
  final String productName;
  const _RestockDialog({required this.productName});

  @override
  State<_RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<_RestockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context)
        .pop(parseThousandsSeparatedInt(_quantityController.text)!);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text('Restok ${widget.productName}'),
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
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              final quantity = parseThousandsSeparatedInt(value);
              if (quantity == null || quantity <= 0) {
                return 'Masukkan bilangan bulat lebih dari nol.';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Jumlah yang ditambahkan',
              hintText: 'contoh: 24',
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal')),
          FilledButton(onPressed: _submit, child: const Text('Restok')),
        ],
      );
}
