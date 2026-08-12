import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductRepositoryImpl implements ProductRepository {
  final SupabaseClient _client;

  ProductRepositoryImpl(this._client);

  Product _toProduct(Map<String, dynamic> row) => Product(
        id: row['id'] as String,
        name: row['name'] as String,
        barcode: row['barcode'] as String,
        price: (row['price'] as num).toDouble(),
        stock: row['stock'] as int,
      );

  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    try {
      final rows = await _client.from('products').select().order('name');
      return Right((rows as List)
          .map((row) => _toProduct(row as Map<String, dynamic>))
          .toList());
    } catch (e) {
      return Left(RemoteFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    try {
      final row = await _client
          .from('products')
          .select()
          .eq('barcode', barcode.trim())
          .single();
      return Right(_toProduct(row));
    } catch (e) {
      return Left(RemoteFailure('Produk tidak ditemukan: $barcode'));
    }
  }

  @override
  Future<Either<Failure, void>> addProduct(Product product) async {
    try {
      await _client.from('products').insert({
        'id': product.id,
        'name': product.name.trim(),
        'barcode': product.barcode.trim(),
        'price': product.price,
        'stock': product.stock,
      });
      return const Right(null);
    } catch (e) {
      return Left(RemoteFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateProduct(Product product) async {
    try {
      await _client.from('products').update({
        'name': product.name.trim(),
        'price': product.price,
      }).eq('id', product.id);
      return const Right(null);
    } catch (e) {
      return Left(RemoteFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> restockProduct({
    required String id,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return const Left(RemoteFailure('Jumlah harus lebih dari nol.'));
    }
    try {
      await _client.rpc('restock_product_v2', params: {
        'p_product_id': id,
        'p_quantity': quantity,
      });
      return const Right(null);
    } catch (e) {
      return Left(RemoteFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    try {
      await _client.from('products').delete().eq('id', id);
      return const Right(null);
    } catch (e) {
      return Left(RemoteFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> importProducts(List<Product> products) async {
    try {
      await _client.rpc('import_products', params: {
        'p_products': products
            .map((product) => {
                  'barcode': product.barcode.trim(),
                  'name': product.name.trim(),
                  'price': product.price,
                  'stock': product.stock,
                })
            .toList(),
      });
      return const Right(null);
    } catch (e) {
      return Left(RemoteFailure(e.toString()));
    }
  }
}
