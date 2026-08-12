import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../billing/domain/entities/cart_item.dart';
import '../../domain/entities/sale_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

class SupabaseTransactionRepository implements TransactionRepository {
  final SupabaseClient _client;

  SupabaseTransactionRepository(this._client);

  SaleTransactionItem _toItem(Map<String, dynamic> row) => SaleTransactionItem(
        productId: row['product_id'] as String?,
        barcode: row['barcode'] as String,
        productName: row['product_name'] as String,
        unitPrice: (row['unit_price'] as num).toDouble(),
        quantity: row['quantity'] as int,
      );

  SaleTransaction _toTransaction(Map<String, dynamic> row) {
    final profile = row['staff'] as Map<String, dynamic>?;
    final items = (row['transaction_items'] as List? ?? const [])
        .map((item) => _toItem(item as Map<String, dynamic>))
        .toList();
    return SaleTransaction(
      id: row['id'] as String,
      staffId: row['staff_id'] as String,
      staffName: (profile?['display_name'] as String?)?.isNotEmpty == true
          ? profile!['display_name'] as String
          : 'Staf',
      completedAt: DateTime.parse(row['completed_at'] as String).toLocal(),
      total: (row['total'] as num).toDouble(),
      shopName: row['shop_name'] as String?,
      items: items,
    );
  }

  @override
  Future<Either<Failure, SaleTransaction>> completeCheckout({
    required String clientTransactionId,
    required List<CartItem> items,
    String? shopName,
  }) async {
    try {
      final row = await _client.rpc('complete_checkout', params: {
        'p_client_transaction_id': clientTransactionId,
        'p_items': items
            .map((item) => {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                })
            .toList(),
        'p_shop_name': shopName,
      }) as Map<String, dynamic>;
      final hydrated = await _client
          .from('transactions')
          .select('*, staff:profiles(display_name), transaction_items(*)')
          .eq('id', row['id'])
          .single();
      return Right(_toTransaction(hydrated));
    } catch (error) {
      return Left(RemoteFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SaleTransaction>>> getTransactions({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = _client
          .from('transactions')
          .select('*, staff:profiles(display_name), transaction_items(*)');
      if (from != null) {
        query = query.gte('completed_at', from.toUtc().toIso8601String());
      }
      if (to != null) {
        query = query.lt('completed_at', to.toUtc().toIso8601String());
      }
      final rows = await query.order('completed_at', ascending: false);
      return Right((rows as List)
          .map((row) => _toTransaction(row as Map<String, dynamic>))
          .toList());
    } catch (error) {
      return Left(RemoteFailure(error.toString()));
    }
  }
}
