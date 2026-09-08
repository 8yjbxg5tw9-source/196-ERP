import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/domain/entities/document_entity.dart';
import '../../../reconciliation/domain/entities/bank_transaction_entity.dart';
import '../entities/consolidated_report_entity.dart';
import '../entities/elimination_result.dart';

/// Deterministic intercompany elimination engine.
///
/// A flow between two group members is intercompany when the counterparty
/// VÖEN on a member's invoice or bank line resolves to another member. The
/// engine removes that amount from the seller's revenue and the buyer's
/// expense so the group totals contain only third-party activity.
class EliminationEngine {
  const EliminationEngine({this.amountTolerance = 0.01});

  final double amountTolerance;

  /// Computes eliminations across [members] from their [documents] and
  /// [transactions] within a date range.
  EliminationResult compute({
    required List<CompanyEntity> members,
    required List<DocumentEntity> documents,
    required List<BankTransactionEntity> transactions,
  }) {
    final Map<String, CompanyEntity> byId = <String, CompanyEntity>{
      for (final CompanyEntity member in members) member.id: member,
    };
    final Map<String, CompanyEntity> byVoen = <String, CompanyEntity>{};
    for (final CompanyEntity member in members) {
      final String voen = _normalizeVoen(member.voenTin);
      if (voen.isNotEmpty) {
        byVoen[voen] = member;
      }
    }

    final List<IntercompanyElimination> eliminations =
        <IntercompanyElimination>[];
    final Set<String> countedDocumentIds = <String>{};

    // Invoices: the owner's ledger counts a completed document as revenue, so
    // the owner is the seller and the company matching `vendor_voen` (another
    // group member) is the buyer whose expense must be eliminated.
    for (final DocumentEntity document in documents) {
      if (document.status != DocumentStatus.completed) {
        continue;
      }
      final double amount = document.totalAmount ?? 0;
      if (!_isPositive(amount)) {
        continue;
      }
      final CompanyEntity? buyer = byVoen[_normalizeVoen(document.vendorVoen)];
      final CompanyEntity? seller = byId[document.companyId];
      if (buyer == null || seller == null || buyer.id == seller.id) {
        continue;
      }
      countedDocumentIds.add(document.id);
      eliminations.add(
        IntercompanyElimination(
          id: 'doc-${document.id}',
          sellerCompanyId: seller.id,
          sellerCompanyName: seller.name,
          buyerCompanyId: buyer.id,
          buyerCompanyName: buyer.name,
          amount: amount,
          source: IntercompanyEliminationSource.document,
        ),
      );
    }

    // Bank lines not already represented by a counted invoice.
    for (final BankTransactionEntity transaction in transactions) {
      if (transaction.matchedDocumentId != null &&
          countedDocumentIds.contains(transaction.matchedDocumentId)) {
        continue;
      }
      if (!_isPositive(transaction.amount)) {
        continue;
      }
      final CompanyEntity? counterparty =
          byVoen[_normalizeVoen(transaction.counterpartyVoen)];
      if (counterparty == null || counterparty.id == transaction.companyId) {
        continue;
      }
      final CompanyEntity? owner = byId[transaction.companyId];
      if (owner == null) {
        continue;
      }
      // Credit = money received (revenue for the owner, expense for the
      // counterparty). Debit = money paid (expense for the owner).
      final bool ownerIsSeller = transaction.type == BankTransactionType.credit;
      final CompanyEntity seller = ownerIsSeller ? owner : counterparty;
      final CompanyEntity buyer = ownerIsSeller ? counterparty : owner;
      eliminations.add(
        IntercompanyElimination(
          id: 'tx-${transaction.id}',
          sellerCompanyId: seller.id,
          sellerCompanyName: seller.name,
          buyerCompanyId: buyer.id,
          buyerCompanyName: buyer.name,
          amount: transaction.amount,
          source: IntercompanyEliminationSource.transaction,
        ),
      );
    }

    final Map<String, double> revenueByCompany = <String, double>{};
    final Map<String, double> expensesByCompany = <String, double>{};
    for (final IntercompanyElimination elimination in eliminations) {
      revenueByCompany[elimination.sellerCompanyId] =
          (revenueByCompany[elimination.sellerCompanyId] ?? 0) +
              elimination.amount;
      expensesByCompany[elimination.buyerCompanyId] =
          (expensesByCompany[elimination.buyerCompanyId] ?? 0) +
              elimination.amount;
    }

    return EliminationResult(
      eliminations: eliminations,
      eliminatedRevenueByCompany: revenueByCompany,
      eliminatedExpensesByCompany: expensesByCompany,
    );
  }

  bool _isPositive(double value) => value > amountTolerance;

  static String _normalizeVoen(String? value) {
    return (value ?? '').replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toLowerCase();
  }
}
