import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/tax_query_entity.dart';
import '../entities/tax_rule_entity.dart';

/// Domain contract for retrieval-augmented tax and legal assistance.
abstract interface class TaxCopilotRepository {
  Future<Either<Failure, List<TaxRuleEntity>>> searchRelevantTaxRules(
    String queryVector,
  );

  Future<Either<Failure, TaxQueryEntity>> askTaxCopilot(
    String question,
    String companyId,
  );

  Future<Either<Failure, List<TaxQueryEntity>>> getQueryHistory(
    String companyId,
  );

  Future<Either<Failure, void>> clearQueryHistory(String companyId);
}
