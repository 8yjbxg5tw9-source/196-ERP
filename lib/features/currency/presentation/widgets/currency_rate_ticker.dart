import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/currency_entity.dart';
import '../bloc/currency_bloc.dart';
import '../bloc/currency_event.dart';
import '../bloc/currency_state.dart';

/// Compact live rate bar shown in the application action bar.
class CurrencyRateTicker extends StatelessWidget {
  const CurrencyRateTicker({this.maxVisible = 3, super.key});

  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final CurrencyBloc bloc = context.read<CurrencyBloc>();
    return BlocBuilder<CurrencyBloc, CurrencyState>(
      builder: (BuildContext context, CurrencyState state) {
        if (state is CurrencyInitial) {
          bloc.add(const LoadRatesEvent());
          return const SizedBox(width: 12);
        }
        if (state is CurrencyError) {
          return Tooltip(
            message: state.message,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.currency_exchange_outlined, size: 17),
            ),
          );
        }
        final List<ExchangeRateEntity> rates = state is CurrencyRatesLoaded
            ? state.rates
            : const <ExchangeRateEntity>[];
        final DateTime? asOf =
            state is CurrencyRatesLoaded ? state.asOf : null;

        return Tooltip(
          message: asOf == null
              ? 'No exchange rates cached yet.'
              : 'Exchange rates as of ${AppFormatters.date(asOf)}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.currency_exchange_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              if (rates.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'No rates',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                )
              else
                ...rates.take(maxVisible).map(
                      (ExchangeRateEntity rate) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          '1 ${rate.targetCurrency} = '
                          '${AppFormatters.decimal(rate.rate, decimalDigits: 4)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
              IconButton(
                tooltip: 'Sync exchange rates',
                onPressed: () => bloc.add(const SyncRatesEvent()),
                icon: const Icon(Icons.sync_rounded, size: 15),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        );
      },
    );
  }
}
