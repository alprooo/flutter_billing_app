part of 'transaction_bloc.dart';

sealed class TransactionEvent extends Equatable {
  const TransactionEvent();
  @override
  List<Object?> get props => [];
}

class LoadTransactions extends TransactionEvent {
  final DateTime date;
  const LoadTransactions(this.date);
  @override
  List<Object> get props => [date];
}

class CompleteCheckout extends TransactionEvent {
  final String clientTransactionId;
  final List<CartItem> items;
  final String? shopName;
  const CompleteCheckout({
    required this.clientTransactionId,
    required this.items,
    this.shopName,
  });
  @override
  List<Object?> get props => [clientTransactionId, items, shopName];
}
