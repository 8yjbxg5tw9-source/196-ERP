import 'package:equatable/equatable.dart';

/// One portion of a lump-sum bank entry that an accountant assigns to a
/// single invoice while splitting a payment across multiple documents.
class SplitAllocation extends Equatable {
  const SplitAllocation({
    required this.documentId,
    required this.amount,
  }) : assert(amount > 0);

  final String documentId;
  final double amount;

  @override
  List<Object?> get props => <Object?>[documentId, amount];
}
