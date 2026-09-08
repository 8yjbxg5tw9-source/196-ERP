import 'package:equatable/equatable.dart';

/// Net cash movement for a single calendar month, used by the liquidity /
/// runway waterfall widget.
class CashFlowMonthlyPoint extends Equatable {
  const CashFlowMonthlyPoint({
    required this.date,
    required this.label,
    required this.netMovement,
  });

  final DateTime date;
  final String label;
  final double netMovement;

  @override
  List<Object?> get props => <Object?>[date, label, netMovement];
}
