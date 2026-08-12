import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/product_usecases.dart';
import '../../../../core/usecase/usecase.dart';

part 'product_event.dart';
part 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final GetProductsUseCase getProductsUseCase;
  final AddProductUseCase addProductUseCase;
  final UpdateProductUseCase updateProductUseCase;
  final RestockProductUseCase restockProductUseCase;
  final DeleteProductUseCase deleteProductUseCase;
  final ImportProductsUseCase importProductsUseCase;

  ProductBloc({
    required this.getProductsUseCase,
    required this.addProductUseCase,
    required this.updateProductUseCase,
    required this.restockProductUseCase,
    required this.deleteProductUseCase,
    required this.importProductsUseCase,
  }) : super(const ProductState()) {
    on<LoadProducts>(_onLoadProducts);
    on<AddProduct>(_onAddProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<RestockProduct>(_onRestockProduct);
    on<DeleteProduct>(_onDeleteProduct);
    on<ImportProducts>(_onImportProducts);
  }

  Future<void> _onLoadProducts(
      LoadProducts event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await getProductsUseCase(NoParams());
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (products) => emit(
          state.copyWith(status: ProductStatus.loaded, products: products)),
    );
  }

  Future<void> _onAddProduct(
      AddProduct event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading)); // Keep products
    final result = await addProductUseCase(event.product);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            message: 'Produk berhasil ditambahkan'));
        add(LoadProducts());
      },
    );
  }

  Future<void> _onUpdateProduct(
      UpdateProduct event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await updateProductUseCase(event.product);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            message: 'Produk berhasil diperbarui'));
        add(LoadProducts());
      },
    );
  }

  Future<void> _onDeleteProduct(
      DeleteProduct event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await deleteProductUseCase(event.id);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success, message: 'Produk berhasil dihapus'));
        add(LoadProducts());
      },
    );
  }

  Future<void> _onRestockProduct(
      RestockProduct event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await restockProductUseCase(
        RestockParams(id: event.productId, quantity: event.quantity));
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        // The restock RPC has already completed successfully. Update the
        // in-memory list from the known quantity instead of immediately
        // issuing another products query. That second query could fail after
        // the stock was saved, which made the UI incorrectly show an error.
        final updatedProducts = state.products
            .map((product) => product.id == event.productId
                ? Product(
                    id: product.id,
                    name: product.name,
                    barcode: product.barcode,
                    price: product.price,
                    stock: product.stock + event.quantity,
                  )
                : product)
            .toList(growable: false);
        emit(state.copyWith(
            status: ProductStatus.success,
            products: updatedProducts,
            message: 'Stok berhasil diperbarui'));
      },
    );
  }

  Future<void> _onImportProducts(
      ImportProducts event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await importProductsUseCase(event.products);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            message:
                '${event.products.length} products imported successfully'));
        add(LoadProducts());
      },
    );
  }
}
