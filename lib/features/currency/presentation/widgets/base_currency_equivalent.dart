import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../domain/services/currency_conversion_service.dart';

/// Shows the automatic base-currency equivalent of a foreign-currency amount,
/// e.g. `≈ 1,700.00 AZN at 1.7000 rate`.
class BaseCurrencyEquivalent extends StatefulWidget {
  const BaseCurrencyEquivalent({
    required this.amount,
    required this.currency,
    this.baseCurrency = 'AZN',
    this.service,
    super.key,
  });

  final double amount;
  final String currency;
  final String baseCurrency;
  final CurrencyConversionService? service;

  @override
  State<BaseCurrencyEquivalent> createState() => _BaseCurrencyEquivalentState();
}

class _BaseCurrencyEquivalentState extends State<BaseCurrencyEquivalent> {
  double? _equivalent;
  double? _rate;

  @override
  void initState() {
    super.initState();
    unawaited(_recompute());
  }

  @override
  void didUpdateWidget(covariant BaseCurrencyEquivalent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount ||
        oldWidget.currency != widget.currency) {
      unawaited(_recompute());
    }
  }

  Future<void> _recompute() async {
    if (widget.currency.toUpperCase() == widget.baseCurrency ||
        widget.amount == 0) {
      setState(() {
        _equivalent = widget.amount;
        _rate = 1;
      });
      return;
    }
    try {
      final CurrencyConversionService service =
          widget.service ?? sl<CurrencyConversionService>();
      final double converted = await service.convertAmount(
        amount: widget.amount,
        fromCurrency: widget.currency,
        toCurrency: widget.baseCurrency,
        date: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _equivalent = converted;
          _rate = converted / widget.amount;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _equivalent = null;
          _rate = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (_equivalent == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.currency_exchange_rounded,
            size: 15,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Text(
            '≈ ${AppFormatters.decimal(_equivalent!)} ${widget.baseCurrency}'
            '${_rate == null ? '' : ' at ${_rate!.toStringAsFixed(4)} rate'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
