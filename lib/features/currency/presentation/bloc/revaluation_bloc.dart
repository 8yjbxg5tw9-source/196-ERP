import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/revaluation/fx_balance_entity.dart';
import '../../domain/revaluation/fx_revaluation_entity.dart';
import '../../domain/revaluation/fx_revaluation_repository.dart';
import 'revaluation_event.dart';
import 'revaluation_state.dart';

/// Coordinates period-end FX revaluation, posting, and history.
class FxRevaluationBloc
    extends Bloc<FxRevaluationEvent, FxRevaluationState> {
  FxRevaluationBloc({required FxRevaluationRepository repository})
      : _repository = repository,
        super(const FxRevaluationInitial()) {
    on<CalculateFxRevaluationEvent>(_onCalculate);
    on<PostFxRevaluationJournalEvent>(_onPost);
    on<PostFxReversalEvent>(_onPostReversal);
    on<FetchFxHistoryEvent>(_onFetchHistory);
    on<UpsertFxBalanceEvent>(_onUpsertBalance);
  }

  final FxRevaluationRepository _repository;
  String _companyId = '';
  FxRevaluationEntity? _pendingRevaluation;
  List<FxBalanceEntity> _lastBalances = const <FxBalanceEntity>[];

  Future<void> _onCalculate(
    CalculateFxRevaluationEvent event,
    Emitter<FxRevaluationState> emit,
  ) async {
    _companyId = event.companyId.trim();
    if (_companyId.isEmpty) {
      emit(const FxRevaluationError('Select a company before revaluing.'));
      return;
    }
    emit(const FxRevaluationLoading());
    final Either<Failure, FxRevaluationEntity> result =
        await _repository.calculateRevaluation(
      companyId: _companyId,
      date: event.date,
    );
    await result.fold(
      (Failure failure) async => emit(FxRevaluationError(failure.message)),
      (FxRevaluationEntity revaluation) async {
        _pendingRevaluation = revaluation;
        final List<FxBalanceEntity> balances = await _loadBalances(_companyId);
        _lastBalances = balances;
        emit(
          FxRevaluationCalculated(
            revaluation: revaluation,
            balances: balances,
            history: await _loadHistory(_companyId),
          ),
        );
      },
    );
  }

  Future<void> _onPost(
    PostFxRevaluationJournalEvent event,
    Emitter<FxRevaluationState> emit,
  ) async {
    final FxRevaluationEntity? pending = _pendingRevaluation;
    if (pending == null) {
      emit(const FxRevaluationError('Run a revaluation before posting.'));
      return;
    }
    final Either<Failure, FxRevaluationEntity> result =
        await _repository.postRevaluation(pending);
    await result.fold(
      (Failure failure) async => emit(FxRevaluationError(failure.message)),
      (FxRevaluationEntity posted) async {
        if (event.withReversal) {
          await _repository.postReversal(posted);
        }
        _pendingRevaluation = posted;
        emit(
          FxRevaluationPostedSuccess(
            revaluation: posted,
            balances: _lastBalances,
            history: await _loadHistory(_companyId),
          ),
        );
      },
    );
  }

  Future<void> _onPostReversal(
    PostFxReversalEvent event,
    Emitter<FxRevaluationState> emit,
  ) async {
    final FxRevaluationEntity? pending = _pendingRevaluation;
    if (pending == null) {
      emit(const FxRevaluationError('Run and post a revaluation first.'));
      return;
    }
    final Either<Failure, void> result = await _repository.postReversal(
      pending,
    );
    await result.fold(
      (Failure failure) async => emit(FxRevaluationError(failure.message)),
      (void _) async {
        emit(
          FxRevaluationPostedSuccess(
            revaluation: pending,
            balances: _lastBalances,
            history: await _loadHistory(_companyId),
          ),
        );
      },
    );
  }

  Future<void> _onFetchHistory(
    FetchFxHistoryEvent event,
    Emitter<FxRevaluationState> emit,
  ) async {
    _companyId = event.companyId.trim();
    final List<FxRevaluationEntity> history = await _loadHistory(_companyId);
    final List<FxBalanceEntity> balances = await _loadBalances(_companyId);
    emit(
      FxRevaluationCalculated(
        revaluation: FxRevaluationEntity(
          id: '',
          companyId: _companyId,
          revaluationDate: DateTime.now().toUtc(),
          periodMonth: DateTime.now().month,
          periodYear: DateTime.now().year,
        ),
        balances: balances,
        history: history,
      ),
    );
  }

  Future<void> _onUpsertBalance(
    UpsertFxBalanceEvent event,
    Emitter<FxRevaluationState> emit,
  ) async {
    final Either<Failure, FxBalanceEntity> result =
        await _repository.upsertBalance(event.balance);
    await result.fold(
      (Failure failure) async => emit(FxRevaluationError(failure.message)),
      (FxBalanceEntity saved) async {
        final List<FxBalanceEntity> balances = await _loadBalances(
          saved.companyId,
        );
        _lastBalances = balances;
        emit(
          FxRevaluationCalculated(
            revaluation: FxRevaluationEntity(
              id: '',
              companyId: saved.companyId,
              revaluationDate: DateTime.now().toUtc(),
              periodMonth: DateTime.now().month,
              periodYear: DateTime.now().year,
            ),
            balances: balances,
            history: await _loadHistory(saved.companyId),
          ),
        );
      },
    );
  }

  Future<List<FxBalanceEntity>> _loadBalances(String companyId) async {
    final Either<Failure, List<FxBalanceEntity>> result =
        await _repository.getBalances(companyId);
    return result.fold(
      (Failure _) => const <FxBalanceEntity>[],
      (List<FxBalanceEntity> value) => value,
    );
  }

  Future<List<FxRevaluationEntity>> _loadHistory(String companyId) async {
    final Either<Failure, List<FxRevaluationEntity>> result =
        await _repository.getHistory(companyId);
    return result.fold(
      (Failure _) => const <FxRevaluationEntity>[],
      (List<FxRevaluationEntity> value) => value,
    );
  }
}
