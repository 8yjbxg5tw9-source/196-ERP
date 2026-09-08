import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/currency_entity.dart';
import '../../domain/repositories/currency_repository.dart';
import 'currency_event.dart';
import 'currency_state.dart';

/// Loads and synchronizes exchange rates for the live rate ticker.
class CurrencyBloc extends Bloc<CurrencyEvent, CurrencyState> {
  CurrencyBloc({required CurrencyRepository repository})
      : _repository = repository,
        super(const CurrencyInitial()) {
    on<LoadRatesEvent>(_onLoadRates);
    on<SyncRatesEvent>(_onSyncRates);
  }

  static const String _baseCurrency = 'AZN';

  final CurrencyRepository _repository;

  Future<void> _onLoadRates(
    LoadRatesEvent event,
    Emitter<CurrencyState> emit,
  ) async {
    final result = await _repository.getLatestRates(baseCurrency: _baseCurrency);
    result.fold(
      (failure) => emit(CurrencyError(failure.message)),
      (rates) => emit(_loaded(rates)),
    );
  }

  Future<void> _onSyncRates(
    SyncRatesEvent event,
    Emitter<CurrencyState> emit,
  ) async {
    final CurrencyState current = state;
    if (current is! CurrencyRatesLoaded) {
      emit(const CurrencyLoading());
    }
    await _repository.syncRates();
    final result = await _repository.getLatestRates(baseCurrency: _baseCurrency);
    result.fold(
      (failure) => emit(CurrencyError(failure.message)),
      (rates) => emit(_loaded(rates)),
    );
  }

  CurrencyRatesLoaded _loaded(List<ExchangeRateEntity> rates) {
    DateTime? asOf;
    String source = 'Cache';
    for (final ExchangeRateEntity rate in rates) {
      if (asOf == null || rate.rateDate.isAfter(asOf)) {
        asOf = rate.rateDate;
        source = rate.source;
      }
    }
    return CurrencyRatesLoaded(
      rates: rates,
      baseCurrency: _baseCurrency,
      asOf: asOf,
      source: source,
    );
  }
}
