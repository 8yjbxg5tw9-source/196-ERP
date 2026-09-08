import 'package:equatable/equatable.dart';

/// Whether a comparison line relates to a balance-sheet asset or liability.
enum BalanceSheetNature { asset, liability }

extension BalanceSheetNatureLabel on BalanceSheetNature {
  String get label => switch (this) {
        BalanceSheetNature.asset => 'Asset',
        BalanceSheetNature.liability => 'Liability',
      };
}

/// A single accounting-vs-tax carrying value comparison feeding the deferred
/// tax engine. The engine derives the timing difference and deferred tax
/// consequence from the signed gap between [accountingValue] and [taxBase].
class TaxBaseComparison extends Equatable {
  const TaxBaseComparison({
    required this.name,
    required this.nature,
    required this.accountingValue,
    required this.taxBase,
  });

  final String name;
  final BalanceSheetNature nature;
  final double accountingValue;
  final double taxBase;

  double get signedDifference => accountingValue - taxBase;

  @override
  List<Object?> get props => <Object?>[
        name,
        nature,
        accountingValue,
        taxBase,
      ];
}
