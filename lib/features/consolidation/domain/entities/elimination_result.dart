import 'consolidated_report_entity.dart';

/// Output of [EliminationEngine]: the raw intercompany flows plus the revenue
/// and expense adjustments attributable to each group member.
class EliminationResult {
  const EliminationResult({
    required this.eliminations,
    required this.eliminatedRevenueByCompany,
    required this.eliminatedExpensesByCompany,
  });

  final List<IntercompanyElimination> eliminations;

  /// seller company id → intercompany revenue to remove.
  final Map<String, double> eliminatedRevenueByCompany;

  /// buyer company id → intercompany expense to remove.
  final Map<String, double> eliminatedExpensesByCompany;

  double get totalEliminated =>
      eliminations.fold<double>(
        0,
        (double sum, IntercompanyElimination e) => sum + e.amount,
      );
}
