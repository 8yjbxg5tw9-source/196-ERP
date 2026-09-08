import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../entities/inventory_batch_entity.dart';

/// The financial effect of consuming stock under a valuation method.
class ValuationResult extends Equatable {
  const ValuationResult({
    required this.costOfGoods,
    required this.unitCost,
    required this.consumedBatches,
  });

  /// Total value removed from the product's book value (COGS on a sale).
  final double costOfGoods;

  /// Weighted cost per unit applied to the movement line.
  final double unitCost;

  /// The FIFO layers consumed (empty for moving-average valuation).
  final List<BatchConsumption> consumedBatches;

  @override
  List<Object?> get props => <Object?>[costOfGoods, unitCost, consumedBatches];
}

/// One batch layer partially or fully consumed by a dispatch.
class BatchConsumption extends Equatable {
  const BatchConsumption({
    required this.batchId,
    required this.quantity,
    required this.unitCost,
  });

  final String batchId;
  final double quantity;
  final double unitCost;

  double get cost => quantity * unitCost;

  @override
  List<Object?> get props => <Object?>[batchId, quantity, unitCost];
}

/// Pure valuation algorithms shared by the inventory repository.
///
/// Supports the two cost-flow assumptions required by the stock ledger:
/// weighted moving average and first-in first-out batch layers.
class InventoryValuationEngine {
  const InventoryValuationEngine();

  /// Blends an incoming receipt into the weighted moving average.
  ///
  /// New Average = (qty × avg + incoming × cost) / (qty + incoming).
  double movingAverageCost({
    required double currentQuantity,
    required double currentAverageCost,
    required double incomingQuantity,
    required double incomingUnitCost,
  }) {
    if (incomingQuantity <= 0) {
      return currentAverageCost;
    }
    final double totalQuantity = currentQuantity + incomingQuantity;
    if (totalQuantity <= 0) {
      return 0;
    }
    final double blended =
        ((currentQuantity * currentAverageCost) +
                (incomingQuantity * incomingUnitCost)) /
            totalQuantity;
    return _round(blended);
  }

  /// Consumes [quantity] from the oldest FIFO layers first and returns the
  /// exact cost of goods and per-layer consumption.
  ValuationResult consumeFifo(
    List<InventoryBatchEntity> layers,
    double quantity,
  ) {
    if (quantity <= 0) {
      return const ValuationResult(
        costOfGoods: 0,
        unitCost: 0,
        consumedBatches: <BatchConsumption>[],
      );
    }

    final List<InventoryBatchEntity> sorted = layers.toList(growable: false)
      ..sort((InventoryBatchEntity a, InventoryBatchEntity b) {
        final int byDate = a.receivedAt.compareTo(b.receivedAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });

    double remaining = quantity;
    double totalCost = 0;
    final List<BatchConsumption> consumed = <BatchConsumption>[];
    for (final InventoryBatchEntity layer in sorted) {
      if (remaining <= 0 || layer.remainingQty <= 0) {
        continue;
      }
      final double take = math.min(layer.remainingQty, remaining);
      totalCost += take * layer.purchaseUnitCost;
      consumed.add(
        BatchConsumption(
          batchId: layer.id,
          quantity: take,
          unitCost: layer.purchaseUnitCost,
        ),
      );
      remaining -= take;
    }

    final double unitCost = quantity <= 0 ? 0 : _round(totalCost / quantity);
    return ValuationResult(
      costOfGoods: _round(totalCost),
      unitCost: unitCost,
      consumedBatches: consumed,
    );
  }

  static double _round(double value) {
    if (!value.isFinite) {
      return 0;
    }
    return (value * 100).roundToDouble() / 100;
  }
}
