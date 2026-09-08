import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/company_entity.dart';
import '../../domain/usecases/company_usecases.dart';
import 'company_event.dart';
import 'company_state.dart';

/// Coordinates company CRUD operations and the active company context.
class CompanyBloc extends Bloc<CompanyEvent, CompanyState> {
  CompanyBloc({
    required GetCompaniesUseCase getCompanies,
    required CreateCompanyUseCase createCompany,
    required DeleteCompanyUseCase deleteCompany,
    required GetActiveCompanyUseCase getActiveCompany,
    required SwitchActiveCompanyUseCase switchActiveCompany,
  })  : _getCompanies = getCompanies,
        _createCompany = createCompany,
        _deleteCompany = deleteCompany,
        _getActiveCompany = getActiveCompany,
        _switchActiveCompany = switchActiveCompany,
        super(const CompanyInitial()) {
    on<LoadCompaniesEvent>(_onLoadCompanies);
    on<CreateCompanyEvent>(_onCreateCompany);
    on<SelectActiveCompanyEvent>(_onSelectActiveCompany);
    on<DeleteCompanyEvent>(_onDeleteCompany);
  }

  final GetCompaniesUseCase _getCompanies;
  final CreateCompanyUseCase _createCompany;
  final DeleteCompanyUseCase _deleteCompany;
  final GetActiveCompanyUseCase _getActiveCompany;
  final SwitchActiveCompanyUseCase _switchActiveCompany;

  Future<void> _onLoadCompanies(
    LoadCompaniesEvent _event,
    Emitter<CompanyState> emit,
  ) async {
    emit(const CompanyLoading());

    final Either<Failure, List<CompanyEntity>> companiesResult =
        await _getCompanies(const NoParams());
    final Failure? companiesFailure = _failureOf(companiesResult);
    if (companiesFailure != null) {
      emit(CompanyOperationFailure(companiesFailure.message));
      return;
    }

    final List<CompanyEntity> companies = _valueOf(
      companiesResult,
      fallback: <CompanyEntity>[],
    );
    final Either<Failure, CompanyEntity?> activeResult =
        await _getActiveCompany(const NoParams());
    final Failure? activeFailure = _failureOf(activeResult);
    if (activeFailure != null) {
      emit(CompanyOperationFailure(activeFailure.message));
      return;
    }

    CompanyEntity? activeCompany = _nullableValueOf(activeResult);
    if (activeCompany == null && companies.isNotEmpty) {
      final CompanyEntity firstCompany = companies.first;
      final Either<Failure, void> switchResult = await _switchActiveCompany(
        firstCompany.id,
      );
      final Failure? switchFailure = _failureOf(switchResult);
      if (switchFailure != null) {
        emit(CompanyOperationFailure(switchFailure.message));
        return;
      }
      activeCompany = firstCompany;
    }

    emit(
      CompaniesLoaded(
        companies: companies,
        activeCompany: activeCompany,
      ),
    );
  }

  Future<void> _onCreateCompany(
    CreateCompanyEvent event,
    Emitter<CompanyState> emit,
  ) async {
    final CompanyEntity? previousActive = state is CompaniesLoaded
        ? (state as CompaniesLoaded).activeCompany
        : null;
    emit(const CompanyLoading());

    final Either<Failure, CompanyEntity> result = await _createCompany(
      event.company,
    );
    final Failure? failure = _failureOf(result);
    if (failure != null) {
      emit(CompanyOperationFailure(failure.message));
      return;
    }

    final CompanyEntity createdCompany = _valueOf(
      result,
      fallback: event.company,
    );
    if (previousActive == null) {
      final Either<Failure, void> switchResult = await _switchActiveCompany(
        createdCompany.id,
      );
      final Failure? switchFailure = _failureOf(switchResult);
      if (switchFailure != null) {
        emit(CompanyOperationFailure(switchFailure.message));
        return;
      }
    }

    add(const LoadCompaniesEvent());
  }

  Future<void> _onSelectActiveCompany(
    SelectActiveCompanyEvent event,
    Emitter<CompanyState> emit,
  ) async {
    emit(const CompanyLoading());

    final Either<Failure, void> result = await _switchActiveCompany(
      event.companyId,
    );
    final Failure? failure = _failureOf(result);
    if (failure != null) {
      emit(CompanyOperationFailure(failure.message));
      return;
    }

    add(const LoadCompaniesEvent());
  }

  Future<void> _onDeleteCompany(
    DeleteCompanyEvent event,
    Emitter<CompanyState> emit,
  ) async {
    emit(const CompanyLoading());

    final Either<Failure, void> result = await _deleteCompany(event.companyId);
    final Failure? failure = _failureOf(result);
    if (failure != null) {
      emit(CompanyOperationFailure(failure.message));
      return;
    }

    add(const LoadCompaniesEvent());
  }

  static Failure? _failureOf<T>(Either<Failure, T> result) {
    return result.fold(
      (Failure failure) => failure,
      (T value) => null,
    );
  }

  static T _valueOf<T>(
    Either<Failure, T> result, {
    required T fallback,
  }) {
    return result.fold(
      (Failure failure) => fallback,
      (T value) => value,
    );
  }

  static T? _nullableValueOf<T>(Either<Failure, T?> result) {
    return result.fold(
      (Failure failure) => null,
      (T? value) => value,
    );
  }
}
