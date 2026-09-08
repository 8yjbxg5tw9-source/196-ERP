import 'package:equatable/equatable.dart';

/// Whether an elimination was derived from an invoice document or a bank line.
enum IntercompanyEliminationSource { document, transaction }

/// One intercompany flow detected inside the group: a sale (or payment) from a
/// seller member to a buyer member that must cancel out in the group totals.
class IntercompanyElimination extends Equatable {
  const IntercompanyElimination({
    required this.id,
    required this.sellerCompanyId,
    required this.sellerCompanyName,
    required this.buyerCompanyId,
    required this.buyerCompanyName,
    required this.amount,
    required this.source,
  });

  final String id;
  final String sellerCompanyId;
  final String sellerCompanyName;
  final String buyerCompanyId;
  final String buyerCompanyName;
  final double amount;
  final IntercompanyEliminationSource source;

  @override
  List<Object?> get props => <Object?>[
        id,
        sellerCompanyId,
        sellerCompanyName,
        buyerCompanyId,
        buyerCompanyName,
        amount,
        source,
      ];
}

/// One member's contribution to the consolidated statement.
class ConsolidatedMemberSummary extends Equatable {
  const ConsolidatedMemberSummary({
    required this.companyId,
    required this.companyName,
    required this.revenue,
    required this.expenses,
    required this.netIncome,
    this.eliminatedRevenue = 0,
    this.eliminatedExpenses = 0,
  });

  final String companyId;
  final String companyName;
  final double revenue;
  final double expenses;
  final double netIncome;

  /// Intercompany revenue removed from this member's books.
  final double eliminatedRevenue;

  /// Intercompany expense removed from this member's books.
  final double eliminatedExpenses;

  double get adjustedRevenue => revenue - eliminatedRevenue;
  double get adjustedExpenses => expenses - eliminatedExpenses;
  double get adjustedNetIncome => adjustedRevenue - adjustedExpenses;

  ConsolidatedMemberSummary copyWith({
    String? companyId,
    String? companyName,
    double? revenue,
    double? expenses,
    double? netIncome,
    double? eliminatedRevenue,
    double? eliminatedExpenses,
  }) {
    return ConsolidatedMemberSummary(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      revenue: revenue ?? this.revenue,
      expenses: expenses ?? this.expenses,
      netIncome: netIncome ?? this.netIncome,
      eliminatedRevenue: eliminatedRevenue ?? this.eliminatedRevenue,
      eliminatedExpenses: eliminatedExpenses ?? this.eliminatedExpenses,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        companyId,
        companyName,
        revenue,
        expenses,
        netIncome,
        eliminatedRevenue,
        eliminatedExpenses,
      ];
}

/// The fully consolidated multi-company statement for a date range.
class ConsolidatedReportEntity extends Equatable {
  const ConsolidatedReportEntity({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.start,
    required this.end,
    required this.generatedAt,
    required this.memberSummaries,
    required this.eliminations,
    required this.consolidatedRevenue,
    required this.consolidatedExpenses,
    required this.consolidatedNetIncome,
  });

  final String id;
  final String groupId;
  final String groupName;
  final DateTime start;
  final DateTime end;
  final DateTime generatedAt;

  final List<ConsolidatedMemberSummary> memberSummaries;
  final List<IntercompanyElimination> eliminations;

  /// Group totals after intercompany elimination.
  final double consolidatedRevenue;
  final double consolidatedExpenses;
  final double consolidatedNetIncome;

  /// The amount of intercompany revenue removed (equals eliminated expense).
  double get eliminatedTotal =>
      eliminations.fold<double>(0, (double sum, IntercompanyElimination e) => sum + e.amount);

  @override
  List<Object?> get props => <Object?>[
        id,
        groupId,
        groupName,
        start,
        end,
        generatedAt,
        memberSummaries,
        eliminations,
        consolidatedRevenue,
        consolidatedExpenses,
        consolidatedNetIncome,
      ];
}
