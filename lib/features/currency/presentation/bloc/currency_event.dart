import 'package:equatable/equatable.dart';

abstract class CurrencyEvent extends Equatable {
  const CurrencyEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Loads the latest cached rates for display.
class LoadRatesEvent extends CurrencyEvent {
  const LoadRatesEvent();
}

/// Fetches fresh daily rates from the central-bank feed, then reloads.
class SyncRatesEvent extends CurrencyEvent {
  const SyncRatesEvent();
}
