part of 'transaction_bloc.dart';

enum TransactionStatus {
  initial,
  loading,
  loaded,
  completing,
  completed,
  error
}

class TransactionState extends Equatable {
  final TransactionStatus status;
  final List<SaleTransaction> transactions;
  final DateTime selectedDate;
  final SaleTransaction? lastCompleted;
  final String? message;

  TransactionState({
    this.status = TransactionStatus.initial,
    this.transactions = const [],
    DateTime? selectedDate,
    this.lastCompleted,
    this.message,
  }) : selectedDate = selectedDate ?? DateTime.now();

  TransactionState copyWith({
    TransactionStatus? status,
    List<SaleTransaction>? transactions,
    DateTime? selectedDate,
    SaleTransaction? lastCompleted,
    String? message,
  }) =>
      TransactionState(
        status: status ?? this.status,
        transactions: transactions ?? this.transactions,
        selectedDate: selectedDate ?? this.selectedDate,
        lastCompleted: lastCompleted ?? this.lastCompleted,
        message: message,
      );

  int get transactionCount => transactions.length;
  int get unitsSold =>
      transactions.fold(0, (sum, sale) => sum + sale.unitsSold);
  double get grossSales =>
      transactions.fold(0, (sum, sale) => sum + sale.total);

  @override
  List<Object?> get props =>
      [status, transactions, selectedDate, lastCompleted, message];
}
