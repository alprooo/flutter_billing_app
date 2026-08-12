import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../billing/domain/entities/cart_item.dart';
import '../../domain/entities/sale_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository _repository;

  TransactionBloc(this._repository) : super(TransactionState()) {
    on<LoadTransactions>(_onLoad);
    on<CompleteCheckout>(_onCompleteCheckout);
  }

  Future<void> _onLoad(
      LoadTransactions event, Emitter<TransactionState> emit) async {
    emit(state.copyWith(
        status: TransactionStatus.loading, selectedDate: event.date));
    final date = event.date;
    final from = DateTime(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1));
    final result = await _repository.getTransactions(from: from, to: to);
    result.fold(
      (failure) => emit(state.copyWith(
          status: TransactionStatus.error, message: failure.message)),
      (transactions) => emit(state.copyWith(
          status: TransactionStatus.loaded,
          transactions: transactions,
          selectedDate: date,
          message: null)),
    );
  }

  Future<void> _onCompleteCheckout(
      CompleteCheckout event, Emitter<TransactionState> emit) async {
    emit(state.copyWith(status: TransactionStatus.completing, message: null));
    final result = await _repository.completeCheckout(
      clientTransactionId: event.clientTransactionId,
      items: event.items,
      shopName: event.shopName,
    );
    result.fold(
      (failure) => emit(state.copyWith(
          status: TransactionStatus.error, message: failure.message)),
      (transaction) => emit(state.copyWith(
          status: TransactionStatus.completed,
          lastCompleted: transaction,
          message: 'Pembayaran selesai')),
    );
  }
}
