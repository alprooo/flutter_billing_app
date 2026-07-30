import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../billing/domain/entities/cart_item.dart';
import '../entities/sale_transaction.dart';

abstract class TransactionRepository {
  Future<Either<Failure, SaleTransaction>> completeCheckout({
    required String clientTransactionId,
    required List<CartItem> items,
    String? shopName,
  });

  Future<Either<Failure, List<SaleTransaction>>> getTransactions({
    DateTime? from,
    DateTime? to,
  });
}
