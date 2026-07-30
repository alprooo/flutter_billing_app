import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
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

  bool get _canManage =>
      context.read<AuthBloc>().state is Authenticated &&
      (context.read<AuthBloc>().state as Authenticated).user.canManageInventory;

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
            'The CSV must include a header and one product.');
      }
      final headers = rows.first
          .map((value) => value.toString().trim().toLowerCase())
          .toList();
      const required = ['barcode', 'name', 'price', 'stock'];
      if (!required.every(headers.contains)) {
        throw const FormatException(
            'Required headers: barcode, name, price, stock.');
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
              'Row ${rowNumber + 1}: invalid values or duplicate barcode.');
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
                  title: const Text('Import needs correction'),
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
                title: const Text('Import products'),
                content: Text(
                    'Import ${parsed.length} new products? Existing barcodes will not be changed.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Import')),
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
    final canManage = _canManage;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('Inventory'),
        actions: [
          if (canManage)
            IconButton(
                onPressed: () =>
                    _importCsv(context.read<ProductBloc>().state.products),
                icon: const Icon(Icons.upload_file),
                tooltip: 'Import CSV')
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
                            hintText: 'Search or enter barcode'))),
                const SizedBox(width: 8),
                IconButton(
                    onPressed: _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    color: AppTheme.primaryColor),
              ]),
            ),
            Expanded(
              child: state.status == ProductStatus.loading &&
                      state.products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? const Center(child: Text('No products found.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: products.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return Card(
                                child: ListTile(
                              title: Text(product.name),
                              subtitle: Text(
                                  '${product.barcode}\nStock: ${product.stock} • ${formatRupiah(product.price)}'),
                              isThreeLine: true,
                              trailing: canManage
                                  ? Wrap(spacing: 0, children: [
                                      IconButton(
                                          onPressed: () => _restock(product),
                                          icon: const Icon(
                                              Icons.add_box_outlined),
                                          tooltip: 'Restock'),
                                      IconButton(
                                          onPressed: () => context.push(
                                              '/products/edit/${product.id}',
                                              extra: product),
                                          icon:
                                              const Icon(Icons.edit_outlined)),
                                      IconButton(
                                          onPressed: () =>
                                              _confirmDelete(product),
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.red)),
                                    ])
                                  : null,
                            ));
                          },
                        ),
            ),
          ]);
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/products/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add / Restock'))
          : null,
    );
  }

  void _confirmDelete(Product product) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: const Text('Delete product'),
            content: Text('Delete ${product.name}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () {
                    context.read<ProductBloc>().add(DeleteProduct(product.id));
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Delete')),
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
    Navigator.of(context).pop(int.parse(_quantityController.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text('Restock ${widget.productName}'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _quantityController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              final quantity = int.tryParse(value?.trim() ?? '');
              if (quantity == null || quantity <= 0) {
                return 'Enter a whole number greater than zero.';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Quantity to add',
              hintText: 'e.g. 24',
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Restock')),
        ],
      );
}
