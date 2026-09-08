import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../domain/services/currency_conversion_service.dart';

const Map<String, String> _currencySymbols = <String, String>{
  'AZN': '₼',
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'TRY': '₺',
  'RUB': '₽',
};

/// Multi-currency amount entry for invoice line items.
///
/// Enter an amount in any supported currency and the field renders the
/// automatic base-currency equivalent, e.g.
/// `$1,000.00 USD (≈ 1,700.00 AZN at 1.7000 rate)`.
class CurrencyAmountField extends StatefulWidget {
  const CurrencyAmountField({
    required this.label,
    this.initialAmount,
    this.initialCurrency = 'AZN',
    this.baseCurrency = 'AZN',
    this.enabled = true,
    this.onAmountChanged,
    this.onCurrencyChanged,
    this.service,
    super.key,
  });

  final String label;
  final double? initialAmount;
  final String initialCurrency;
  final String baseCurrency;
  final bool enabled;
  final ValueChanged<double>? onAmountChanged;
  final ValueChanged<String>? onCurrencyChanged;
  final CurrencyConversionService? service;

  @override
  State<CurrencyAmountField> createState() => _CurrencyAmountFieldState();
}

class _CurrencyAmountFieldState extends State<CurrencyAmountField> {
  late final TextEditingController _amountController;
  late String _currency;
  double? _baseEquivalent;
  double? _rate;
  bool _resolving = false;

  static const List<String> _supported = <String>[
    'AZN',
    'USD',
    'EUR',
    'GBP',
    'TRY',
    'RUB',
  ];

  CurrencyConversionService get _service =>
      widget.service ?? sl<CurrencyConversionService>();

  @override
  void initState() {
    super.initState();
    _currency = widget.initialCurrency;
    _amountController = TextEditingController(
      text: widget.initialAmount == null
          ? ''
          : _number(widget.initialAmount!),
    );
    if (widget.initialAmount != null) {
      unawaited(_recompute());
    }
  }

  @override
  void didUpdateWidget(covariant CurrencyAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAmount != widget.initialAmount &&
        _parse(_amountController.text) != widget.initialAmount) {
      _amountController.text =
          widget.initialAmount == null ? '' : _number(widget.initialAmount!);
    }
    if (oldWidget.initialCurrency != widget.initialCurrency) {
      _currency = widget.initialCurrency;
      unawaited(_recompute());
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _amountController,
                enabled: widget.enabled,
                onChanged: (_) => unawaited(_recompute()),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: widget.label,
                  isDense: true,
                  suffixIcon: Text(
                    _currencySymbols[_currency] ?? _currency,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _currency,
              items: <DropdownMenuItem<String>>[
                for (final String code in _supported)
                  DropdownMenuItem<String>(
                    value: code,
                    child: Text(code),
                  ),
              ],
              onChanged: widget.enabled
                  ? (String? value) {
                      if (value != null) {
                        setState(() => _currency = value);
                        widget.onCurrencyChanged?.call(value);
                        unawaited(_recompute());
                      }
                    }
                  : null,
            ),
          ],
        ),
        if (_baseEquivalent != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            '≈ ${_symbol(widget.baseCurrency)} '
            '${AppFormatters.decimal(_baseEquivalent!)} '
            '${widget.baseCurrency}'
            '${_rate == null ? '' : ' at ${_rate!.toStringAsFixed(4)} rate'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _recompute() async {
    final double? amount = _parse(_amountController.text);
    if (amount == null || amount == 0 || _currency == widget.baseCurrency) {
      if (mounted) {
        setState(() {
          _baseEquivalent = amount == null ? null : amount;
          _rate = _currency == widget.baseCurrency ? 1 : null;
        });
      }
      return;
    }
    if (_resolving) {
      return;
    }
    _resolving = true;
    try {
      final double converted = await _service.convertAmount(
        amount: amount,
        fromCurrency: _currency,
        toCurrency: widget.baseCurrency,
        date: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _baseEquivalent = converted;
          _rate = converted / amount;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _baseEquivalent = null;
          _rate = null;
        });
      }
    } finally {
      _resolving = false;
    }
  }

  static String _symbol(String code) => _currencySymbols[code] ?? code;

  static String _number(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static double? _parse(String value) {
    final String normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }
}
