import 'package:equatable/equatable.dart';

class SaleTransaction extends Equatable {
  final String id;
  final String staffId;
  final String staffName;
  final DateTime completedAt;
  final double total;
  final String? shopName;
  final List<SaleTransactionItem> items;

  const SaleTransaction({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.completedAt,
    required this.total,
    required this.items,
    this.shopName,
  });

  int get unitsSold => items.fold(0, (sum, item) => sum + item.quantity);

  @override
  List<Object?> get props =>
      [id, staffId, staffName, completedAt, total, shopName, items];
}

class SaleTransactionItem extends Equatable {
  final String productId;
  final String barcode;
  final String productName;
  final double unitPrice;
  final int quantity;

  const SaleTransactionItem({
    required this.productId,
    required this.barcode,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  double get total => unitPrice * quantity;

  @override
  List<Object> get props =>
      [productId, barcode, productName, unitPrice, quantity];
}
