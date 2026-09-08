import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/product_item_entity.dart';
import '../../domain/entities/stock_movement_entity.dart';
import '../../domain/entities/warehouse_entity.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'inventory_event.dart';
import 'inventory_state.dart';

/// Coordinates the multi-warehouse stock workspace.
class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  InventoryBloc({required InventoryRepository repository})
      : _repository = repository,
        super(const InventoryInitial()) {
    on<LoadWarehousesAndStockEvent>(_onLoad);
    on<CreateProductItemEvent>(_onCreateProduct);
    on<RecordStockMovementEvent>(_onRecordMovement);
    on<TransferStockBetweenWarehousesEvent>(_onTransfer);
  }

  final InventoryRepository _repository;
  String? _companyId;

  Future<void> _onLoad(
    LoadWarehousesAndStockEvent event,
    Emitter<InventoryState> emit,
  ) async {
    final String companyId = event.companyId.trim();
    if (companyId.isEmpty) {
      emit(const InventoryError('Select a company before loading stock.'));
      return;
    }
    _companyId = companyId;
    emit(const InventoryLoading());
    await _repository.ensurePrimaryWarehouse(companyId);
    final Either<Failure, List<WarehouseEntity>> warehousesResult =
        await _repository.getWarehouses(companyId);
    final Either<Failure, List<ProductItemEntity>> productsResult =
        await _repository.getProducts(companyId);

    final Failure? warehousesFailure = warehousesResult.fold(
      (Failure failure) => failure,
      (List<WarehouseEntity> _) => null,
    );
    if (warehousesFailure != null) {
      emit(InventoryError(warehousesFailure.message));
      return;
    }
    final Failure? productsFailure = productsResult.fold(
      (Failure failure) => failure,
      (List<ProductItemEntity> _) => null,
    );
    if (productsFailure != null) {
      emit(InventoryError(productsFailure.message));
      return;
    }

    final List<WarehouseEntity> warehouses = warehousesResult.fold(
      (Failure _) => const <WarehouseEntity>[],
      (List<WarehouseEntity> value) => value,
    );
    final List<ProductItemEntity> products = productsResult.fold(
      (Failure _) => const <ProductItemEntity>[],
      (List<ProductItemEntity> value) => value,
    );
    final Map<String, Map<String, double>> quantities =
        await _loadQuantities(products);
    emit(
      StockLoaded(
        products: products,
        warehouses: warehouses,
        quantitiesByProduct: quantities,
      ),
    );
  }

  Future<void> _onCreateProduct(
    CreateProductItemEvent event,
    Emitter<InventoryState> emit,
  ) async {
    final ProductItemEntity product = event.product.copyWith(
      companyId: event.product.companyId.trim().isEmpty
          ? (_companyId ?? '')
          : event.product.companyId,
    );
    final Either<Failure, ProductItemEntity> result =
        await _repository.createProduct(product);
    await result.fold(
      (Failure failure) async {
        emit(InventoryError(failure.message));
      },
      (ProductItemEntity created) async {
        await _reload(emit, created.companyId);
      },
    );
  }

  Future<void> _onRecordMovement(
    RecordStockMovementEvent event,
    Emitter<InventoryState> emit,
  ) async {
    final String companyId =
        event.companyId.trim().isEmpty ? (_companyId ?? '') : event.companyId.trim();
    final StockMovementEntity movement = StockMovementEntity(
      id: '',
      companyId: companyId,
      productId: event.productId,
      warehouseId: event.warehouseId,
      type: event.type,
      quantity: event.quantity,
      unitCost: event.unitCost,
      totalCost: event.quantity * event.unitCost,
      referenceDocId: event.referenceDocId,
      timestamp: DateTime.now().toUtc(),
    );
    final Either<Failure, StockMovementEntity> result =
        await _repository.recordMovement(movement);
    await result.fold(
      (Failure failure) async {
        emit(InventoryError(failure.message));
      },
      (StockMovementEntity saved) async {
        await _reload(
          emit,
          companyId,
          successMessage: 'Stock movement recorded: '
              '${saved.type.label} ${saved.quantity.abs()} units.',
        );
      },
    );
  }

  Future<void> _onTransfer(
    TransferStockBetweenWarehousesEvent event,
    Emitter<InventoryState> emit,
  ) async {
    final Either<Failure, List<StockMovementEntity>> result =
        await _repository.transferStock(
      companyId: event.companyId,
      productId: event.productId,
      fromWarehouseId: event.fromWarehouseId,
      toWarehouseId: event.toWarehouseId,
      quantity: event.quantity,
      timestamp: DateTime.now().toUtc(),
    );
    await result.fold(
      (Failure failure) async {
        emit(InventoryError(failure.message));
      },
      (List<StockMovementEntity> movements) async {
        await _reload(
          emit,
          event.companyId,
          successMessage:
              'Transferred ${event.quantity} units between warehouses.',
        );
      },
    );
  }

  Future<void> _reload(
    Emitter<InventoryState> emit,
    String companyId, {
    String? successMessage,
  }) async {
    final Either<Failure, List<WarehouseEntity>> warehousesResult =
        await _repository.getWarehouses(companyId);
    final Either<Failure, List<ProductItemEntity>> productsResult =
        await _repository.getProducts(companyId);
    final List<WarehouseEntity> warehouses = warehousesResult.fold(
      (Failure _) => const <WarehouseEntity>[],
      (List<WarehouseEntity> value) => value,
    );
    final List<ProductItemEntity> products = productsResult.fold(
      (Failure _) => const <ProductItemEntity>[],
      (List<ProductItemEntity> value) => value,
    );
    final Map<String, Map<String, double>> quantities =
        await _loadQuantities(products);
    if (successMessage != null) {
      emit(
        StockMovementSuccess(
          message: successMessage,
          products: products,
          warehouses: warehouses,
          quantitiesByProduct: quantities,
        ),
      );
    } else {
      emit(
        StockLoaded(
          products: products,
          warehouses: warehouses,
          quantitiesByProduct: quantities,
        ),
      );
    }
  }

  Future<Map<String, Map<String, double>>> _loadQuantities(
    List<ProductItemEntity> products,
  ) async {
    final Map<String, Map<String, double>> result =
        <String, Map<String, double>>{};
    for (final ProductItemEntity product in products) {
      final Either<Failure, Map<String, double>> quantitiesResult =
          await _repository.getWarehouseQuantities(product.id);
      result[product.id] = quantitiesResult.fold(
        (Failure _) => const <String, double>{},
        (Map<String, double> value) => value,
      );
    }
    return result;
  }
}
