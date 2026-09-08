import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../../analytics/domain/entities/profit_and_loss_entity.dart';
import '../../../analytics/domain/repositories/financial_report_repository.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../company/domain/repositories/company_repository.dart';
import '../../domain/entities/tax_declaration_entity.dart';
import '../../domain/entities/xml_validation_issue.dart';
import '../../domain/repositories/tax_declaration_repository.dart';
import '../../domain/services/tax_xml_engine.dart';
import '../datasources/tax_declaration_local_data_source.dart';

/// Assembles statutory declaration data from the ledger, validates it, and
/// delegates XML serialization to the [TaxXmlEngine].
class TaxDeclarationRepositoryImpl implements TaxDeclarationRepository {
  TaxDeclarationRepositoryImpl(
    this._localDataSource,
    this._financialReportRepository,
    this._companyRepository, {
    TaxXmlEngine engine = const TaxXmlEngine(),
  }) : _engine = engine;

  final TaxDeclarationLocalDataSource _localDataSource;
  final FinancialReportRepository _financialReportRepository;
  final CompanyRepository _companyRepository;
  final TaxXmlEngine _engine;

  static const double _profitTaxRate = 0.20;
  static const double _simplifiedTaxRate = 0.02;

  @override
  Future<Either<Failure, TaxDeclarationEntity>> compileDeclarationData(
    String companyId,
    TaxDeclarationType type,
    int year,
    int period,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, TaxDeclarationEntity>(
        const ValidationFailure(message: 'Select a company before filing.'),
      );
    }

    try {
      final CompanyEntity company = await _companyFor(normalizedCompanyId);
      final TaxPeriod taxPeriod = type.defaultPeriod;
      final DateTimeRange range = _dateRangeFor(taxPeriod, year, period);
      final String voen = company.voenTin.trim();
      final String authorityCode =
          voen.length >= 4 ? voen.substring(0, 4) : '1100';

      final TaxDeclarationEntity declaration = await _compileByType(
        normalizedCompanyId: normalizedCompanyId,
        type: type,
        taxPeriod: taxPeriod,
        year: year,
        period: period,
        range: range,
        voen: voen,
        authorityCode: authorityCode,
      );
      return Right<Failure, TaxDeclarationEntity>(declaration);
    } on DatabaseException catch (error) {
      return Left<Failure, TaxDeclarationEntity>(
        DatabaseFailure(
          message: 'The tax declaration could not be compiled.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, TaxDeclarationEntity>(
        CacheFailure(
          message: 'The tax declaration could not be generated.',
          cause: error,
        ),
      );
    }
  }

  Future<TaxDeclarationEntity> _compileByType({
    required String normalizedCompanyId,
    required TaxDeclarationType type,
    required TaxPeriod taxPeriod,
    required int year,
    required int period,
    required DateTimeRange range,
    required String voen,
    required String authorityCode,
  }) async {
    final String id = 'decl-$normalizedCompanyId-${type.shortCode}-$year-$period';
    final TaxDeclarationEntity base = TaxDeclarationEntity(
      id: id,
      companyId: normalizedCompanyId,
      declarationType: type,
      taxPeriod: taxPeriod,
      periodYear: year,
      periodQuarterMonth: period,
      voen: voen,
      taxAuthorityCode: authorityCode,
    );

    switch (type) {
      case TaxDeclarationType.vat2026:
        final VatFilingInputs vat = await _localDataSource.loadVatFilingInputs(
          normalizedCompanyId,
          start: _startOf(range),
          endExclusive: _endExclusiveOf(range),
        );
        return base.copyWith(
          taxableTurnover: vat.taxableTurnover,
          zeroRatedTurnover: vat.zeroRatedTurnover,
          exemptTurnover: vat.exemptTurnover,
          vatCalculated: vat.vatCalculated,
          vatDeductible: vat.vatDeductible,
          netVatPayable: vat.netVatPayable,
        );
      case TaxDeclarationType.profitTax:
        final ProfitAndLossEntity pnl = await _profitAndLoss(
          normalizedCompanyId,
          range,
        );
        final double taxableProfit = pnl.netProfit < 0 ? 0 : pnl.netProfit;
        final double tax = taxableProfit * _profitTaxRate;
        return base.copyWith(
          taxableTurnover: taxableProfit,
          vatCalculated: tax,
          vatDeductible: 0,
          netVatPayable: tax,
        );
      case TaxDeclarationType.simplifiedTax:
        final ProfitAndLossEntity pnl = await _profitAndLoss(
          normalizedCompanyId,
          range,
        );
        final double turnover = pnl.totalRevenue;
        final double tax = turnover * _simplifiedTaxRate;
        return base.copyWith(
          taxableTurnover: turnover,
          vatCalculated: tax,
          vatDeductible: 0,
          netVatPayable: tax,
        );
      case TaxDeclarationType.payrollDsmf:
        final PayrollFilingInputs payroll =
            await _localDataSource.loadPayrollFilingInputs(
          normalizedCompanyId,
          year: year,
          months: _monthsFor(taxPeriod, period),
        );
        return base.copyWith(
          taxableTurnover: payroll.grossPayroll,
          vatCalculated: payroll.dsmfContributions,
          vatDeductible: 0,
          netVatPayable: payroll.dsmfContributions,
        );
    }
  }

  Future<ProfitAndLossEntity> _profitAndLoss(
    String companyId,
    DateTimeRange range,
  ) async {
    final Either<Failure, ProfitAndLossEntity> result =
        await _financialReportRepository.generateProfitAndLoss(
      companyId,
      range,
    );
    return result.fold(
      (Failure _) => ProfitAndLossEntity(
        dateRange: range,
        totalRevenue: 0,
        cogs: 0,
        grossProfit: 0,
        operatingExpenses: const <String, double>{},
        totalExpenses: 0,
        ebitda: 0,
        netProfit: 0,
        profitMarginPercentage: 0,
      ),
      (ProfitAndLossEntity value) => value,
    );
  }

  Future<CompanyEntity> _companyFor(String companyId) async {
    final Either<Failure, List<CompanyEntity>> result =
        await _companyRepository.getCompanies();
    final List<CompanyEntity> companies = result.fold(
      (Failure _) => const <CompanyEntity>[],
      (List<CompanyEntity> value) => value,
    );
    for (final CompanyEntity company in companies) {
      if (company.id == companyId) {
        return company;
      }
    }
    throw const ValidationFailure(message: 'Company profile not found.');
  }

  @override
  Future<Either<Failure, String>> generateTaxXml(
    TaxDeclarationEntity declaration,
  ) async {
    final List<XmlValidationIssue> issues =
        _engine.validateDeclaration(declaration);
    final List<XmlValidationIssue> errors = issues
        .where((XmlValidationIssue issue) => issue.isError)
        .toList(growable: false);
    if (errors.isNotEmpty) {
      return Left<Failure, String>(
        ValidationFailure(
          message: 'Cannot generate the declaration file: '
              '${errors.map((XmlValidationIssue issue) => issue.message).join(' ')}',
        ),
      );
    }
    return Right<Failure, String>(_engine.buildXml(declaration));
  }

  @override
  Future<Either<Failure, List<XmlValidationIssue>>> validateDeclaration(
    TaxDeclarationEntity declaration,
  ) async {
    return Right<Failure, List<XmlValidationIssue>>(
      _engine.validateDeclaration(declaration),
    );
  }

  @override
  Future<Either<Failure, List<XmlValidationIssue>>> validateXmlSchema(
    String xmlContent,
  ) async {
    return Right<Failure, List<XmlValidationIssue>>(
      _engine.validateXml(xmlContent),
    );
  }

  static DateTimeRange _dateRangeFor(
    TaxPeriod taxPeriod,
    int year,
    int period,
  ) {
    switch (taxPeriod) {
      case TaxPeriod.monthly:
        return DateTimeRange(
          start: DateTime(year, period, 1),
          end: DateTime(year, period + 1, 0),
        );
      case TaxPeriod.quarterly:
        final int startMonth = (period - 1) * 3 + 1;
        return DateTimeRange(
          start: DateTime(year, startMonth, 1),
          end: DateTime(year, startMonth + 3, 0),
        );
      case TaxPeriod.annual:
        return DateTimeRange(
          start: DateTime(year, 1, 1),
          end: DateTime(year, 12, 31),
        );
    }
  }

  static List<int> _monthsFor(TaxPeriod taxPeriod, int period) {
    switch (taxPeriod) {
      case TaxPeriod.monthly:
        return <int>[period];
      case TaxPeriod.quarterly:
        final int startMonth = (period - 1) * 3 + 1;
        return <int>[startMonth, startMonth + 1, startMonth + 2];
      case TaxPeriod.annual:
        return <int>[for (int month = 1; month <= 12; month++) month];
    }
  }

  static DateTime _startOf(DateTimeRange range) {
    return DateTime(range.start.year, range.start.month, range.start.day)
        .toUtc();
  }

  static DateTime _endExclusiveOf(DateTimeRange range) {
    return DateTime(range.end.year, range.end.month, range.end.day)
        .add(const Duration(days: 1))
        .toUtc();
  }
}
