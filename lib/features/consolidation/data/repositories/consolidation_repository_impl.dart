import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../../analytics/domain/entities/profit_and_loss_entity.dart';
import '../../../analytics/domain/repositories/financial_report_repository.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../company/domain/repositories/company_repository.dart';
import '../../../document_ocr/domain/entities/document_entity.dart';
import '../../../reconciliation/domain/entities/bank_transaction_entity.dart';
import '../../domain/entities/company_group_entity.dart';
import '../../domain/entities/consolidated_report_entity.dart';
import '../../domain/entities/elimination_result.dart';
import '../../domain/repositories/consolidation_repository.dart';
import '../../domain/services/elimination_engine.dart';
import '../datasources/consolidation_local_data_source.dart';
import '../models/company_group_model.dart';

/// Builds company groups and composes per-member P&L statements into a single
/// consolidated report with intercompany eliminations applied.
class ConsolidationRepositoryImpl implements ConsolidationRepository {
  ConsolidationRepositoryImpl({
    required ConsolidationLocalDataSource localDataSource,
    required CompanyRepository companyRepository,
    required FinancialReportRepository financialReportRepository,
    required EliminationEngine eliminationEngine,
  })  : _localDataSource = localDataSource,
        _companyRepository = companyRepository,
        _financialReportRepository = financialReportRepository,
        _eliminationEngine = eliminationEngine;

  final ConsolidationLocalDataSource _localDataSource;
  final CompanyRepository _companyRepository;
  final FinancialReportRepository _financialReportRepository;
  final EliminationEngine _eliminationEngine;

  @override
  Future<Either<Failure, CompanyGroupEntity>> createGroup({
    required String groupName,
    required String parentCompanyId,
    required List<String> subsidiaryCompanyIds,
  }) async {
    final String normalizedName = groupName.trim();
    final String normalizedParent = parentCompanyId.trim();
    if (normalizedName.isEmpty) {
      return Left<Failure, CompanyGroupEntity>(
        const ValidationFailure(message: 'Group name is required.'),
      );
    }
    if (normalizedParent.isEmpty) {
      return Left<Failure, CompanyGroupEntity>(
        const ValidationFailure(message: 'Select a parent company.'),
      );
    }
    final List<String> subsidiaries = <String>{
      for (final String id in subsidiaryCompanyIds)
        if (id.trim().isNotEmpty && id.trim() != normalizedParent) id.trim(),
    }.toList(growable: false);

    try {
      final CompanyGroupModel group = CompanyGroupModel(
        id: 'group-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        groupName: normalizedName,
        parentCompanyId: normalizedParent,
        subsidiaryCompanyIds: subsidiaries,
        createdAt: DateTime.now().toUtc(),
      );
      final CompanyGroupEntity saved = await _localDataSource.createGroup(group);
      return Right<Failure, CompanyGroupEntity>(saved);
    } on DatabaseException catch (error) {
      return Left<Failure, CompanyGroupEntity>(
        DatabaseFailure(
          message: 'The company group could not be created.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, CompanyGroupEntity>(
        CacheFailure(
          message: 'The company group could not be saved.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<CompanyGroupEntity>>> getGroups() async {
    try {
      final List<CompanyGroupEntity> groups =
          await _localDataSource.getGroups();
      return Right<Failure, List<CompanyGroupEntity>>(groups);
    } on DatabaseException catch (error) {
      return Left<Failure, List<CompanyGroupEntity>>(
        DatabaseFailure(
          message: 'Company groups could not be loaded.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<CompanyGroupEntity>>(
        CacheFailure(
          message: 'Company groups could not be read.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, ConsolidatedReportEntity>> generateConsolidatedReport(
    String groupId,
    DateTimeRange range,
  ) async {
    final String normalizedGroupId = groupId.trim();
    if (normalizedGroupId.isEmpty) {
      return Left<Failure, ConsolidatedReportEntity>(
        const ValidationFailure(message: 'Select a company group.'),
      );
    }

    try {
      final CompanyGroupModel? group =
          await _localDataSource.getGroup(normalizedGroupId);
      if (group == null) {
        return Left<Failure, ConsolidatedReportEntity>(
          const NotFoundFailure(message: 'The company group no longer exists.'),
        );
      }

      final Either<Failure, List<CompanyEntity>> companiesResult =
          await _companyRepository.getCompanies();
      final List<CompanyEntity> companies = companiesResult.fold(
        (Failure _) => const <CompanyEntity>[],
        (List<CompanyEntity> value) => value,
      );
      final Map<String, CompanyEntity> companiesById = <String, CompanyEntity>{
        for (final CompanyEntity company in companies) company.id: company,
      };

      final List<String> memberIds = group.memberCompanyIds;
      final List<CompanyEntity> members = <CompanyEntity>[
        for (final String id in memberIds)
          if (companiesById[id] != null) companiesById[id]!,
      ];
      if (members.isEmpty) {
        return Left<Failure, ConsolidatedReportEntity>(
          const ValidationFailure(
            message: 'The group has no known member companies.',
          ),
        );
      }

      final DateTime start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      ).toUtc();
      final DateTime endExclusive = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
      ).add(const Duration(days: 1)).toUtc();

      // Per-member statements.
      final List<ConsolidatedMemberSummary> summaries =
          <ConsolidatedMemberSummary>[];
      for (final CompanyEntity member in members) {
        final Either<Failure, ProfitAndLossEntity> statementResult =
            await _financialReportRepository.generateProfitAndLoss(
          member.id,
          range,
        );
        final ProfitAndLossEntity? statement = statementResult.fold(
          (Failure _) => null,
          (ProfitAndLossEntity value) => value,
        );
        summaries.add(
          ConsolidatedMemberSummary(
            companyId: member.id,
            companyName: member.name,
            revenue: statement?.totalRevenue ?? 0,
            expenses: statement?.totalExpenses ?? 0,
            netIncome: statement?.netProfit ?? 0,
          ),
        );
      }

      // Intercompany flows.
      final List<DocumentEntity> documents =
          await _localDataSource.getDocumentsForCompanies(
        memberIds,
        start: start,
        endExclusive: endExclusive,
      );
      final List<BankTransactionEntity> transactions =
          await _localDataSource.getTransactionsForCompanies(
        memberIds,
        start: start,
        endExclusive: endExclusive,
      );
      final EliminationResult elimination = _eliminationEngine.compute(
        members: members,
        documents: documents,
        transactions: transactions,
      );

      // Attribute eliminations back onto member summaries.
      final List<ConsolidatedMemberSummary> attributed =
          <ConsolidatedMemberSummary>[
        for (final ConsolidatedMemberSummary summary in summaries)
          summary.copyWith(
            eliminatedRevenue:
                elimination.eliminatedRevenueByCompany[summary.companyId] ?? 0,
            eliminatedExpenses:
                elimination.eliminatedExpensesByCompany[summary.companyId] ?? 0,
          ),
      ];

      double totalRevenue = 0;
      double totalExpenses = 0;
      for (final ConsolidatedMemberSummary summary in attributed) {
        totalRevenue += summary.revenue;
        totalExpenses += summary.expenses;
      }
      final double eliminated = elimination.totalEliminated;

      return Right<Failure, ConsolidatedReportEntity>(
        ConsolidatedReportEntity(
          id: 'consol-${DateTime.now().toUtc().microsecondsSinceEpoch}',
          groupId: group.id,
          groupName: group.groupName,
          start: start,
          end: endExclusive,
          generatedAt: DateTime.now().toUtc(),
          memberSummaries: attributed,
          eliminations: elimination.eliminations,
          consolidatedRevenue: totalRevenue - eliminated,
          consolidatedExpenses: totalExpenses - eliminated,
          consolidatedNetIncome: (totalRevenue - eliminated) -
              (totalExpenses - eliminated),
        ),
      );
    } on DatabaseException catch (error) {
      return Left<Failure, ConsolidatedReportEntity>(
        DatabaseFailure(
          message: 'The consolidated report could not be computed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, ConsolidatedReportEntity>(
        CacheFailure(
          message: 'The consolidated report could not be generated.',
          cause: error,
        ),
      );
    }
  }
}
