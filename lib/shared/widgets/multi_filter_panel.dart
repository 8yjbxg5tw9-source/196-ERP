import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/formatters.dart';

/// Relative date presets for the reusable filter panel.
enum DateRangePreset { all, today, thisWeek, thisMonth, custom }

extension DateRangePresetLabel on DateRangePreset {
  String get label => switch (this) {
        DateRangePreset.all => 'All dates',
        DateRangePreset.today => 'Today',
        DateRangePreset.thisWeek => 'This Week',
        DateRangePreset.thisMonth => 'This Month',
        DateRangePreset.custom => 'Custom range',
      };
}

/// Immutable criteria emitted by [MultiFilterPanel].
class MultiFilterCriteria extends Equatable {
  const MultiFilterCriteria({
    this.dateRange,
    this.datePreset = DateRangePreset.all,
    this.statuses = const <String>[],
    this.minAmount,
    this.maxAmount,
    this.voens = const <String>[],
  });

  final DateTimeRange? dateRange;
  final DateRangePreset datePreset;
  final List<String> statuses;
  final double? minAmount;
  final double? maxAmount;
  final List<String> voens;

  bool get isDefault =>
      dateRange == null &&
      datePreset == DateRangePreset.all &&
      statuses.isEmpty &&
      minAmount == null &&
      maxAmount == null &&
      voens.isEmpty;

  MultiFilterCriteria copyWith({
    DateTimeRange? dateRange,
    DateRangePreset? datePreset,
    List<String>? statuses,
    Object? minAmount = _unset,
    Object? maxAmount = _unset,
    List<String>? voens,
  }) {
    return MultiFilterCriteria(
      dateRange: dateRange ?? this.dateRange,
      datePreset: datePreset ?? this.datePreset,
      statuses: statuses ?? this.statuses,
      minAmount: identical(minAmount, _unset)
          ? this.minAmount
          : minAmount as double?,
      maxAmount: identical(maxAmount, _unset)
          ? this.maxAmount
          : maxAmount as double?,
      voens: voens ?? this.voens,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[dateRange, datePreset, statuses, minAmount, maxAmount, voens];
}

const Object _unset = Object();

/// Result of showing the filter panel as a dialog.
class MultiFilterResult {
  const MultiFilterResult.apply(this.criteria) : cleared = false;
  const MultiFilterResult.cleared()
      : criteria = const MultiFilterCriteria(),
        cleared = true;

  final MultiFilterCriteria criteria;
  final bool cleared;
}

/// Reusable dynamic multi-filter drawer used by the document list and the
/// reconciliation workspace: date-range presets, status checkboxes, amount
/// range, and a counterparty VÖEN multi-select.
class MultiFilterPanel extends StatefulWidget {
  const MultiFilterPanel({
    required this.initial,
    required this.statusOptions,
    required this.voenOptions,
    this.onApply,
    this.onClear,
    this.onSavePreset,
    super.key,
  });

  final MultiFilterCriteria initial;
  final List<String> statusOptions;

  /// VÖEN → display label (usually the company or counterparty name).
  final Map<String, String> voenOptions;

  final ValueChanged<MultiFilterCriteria>? onApply;
  final VoidCallback? onClear;
  final void Function(MultiFilterCriteria criteria, String name)? onSavePreset;

  /// Shows the panel in a modal and returns the applied criteria.
  static Future<MultiFilterResult?> show(
    BuildContext context, {
    required MultiFilterCriteria initial,
    required List<String> statusOptions,
    required Map<String, String> voenOptions,
  }) {
    return showDialog<MultiFilterResult>(
      context: context,
      builder: (BuildContext _) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        title: const Text('Filters'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: MultiFilterPanel(
              initial: initial,
              statusOptions: statusOptions,
              voenOptions: voenOptions,
              onApply: (MultiFilterCriteria criteria) =>
                  Navigator.of(context).pop(MultiFilterResult.apply(criteria)),
              onClear: () => Navigator.of(context).pop(
                const MultiFilterResult.cleared(),
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  State<MultiFilterPanel> createState() => _MultiFilterPanelState();
}

class _MultiFilterPanelState extends State<MultiFilterPanel> {
  late DateRangePreset _datePreset;
  DateTimeRange? _dateRange;
  late List<String> _statuses;
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  late List<String> _voens;

  @override
  void initState() {
    super.initState();
    _datePreset = widget.initial.datePreset;
    _dateRange = widget.initial.dateRange;
    _statuses = List<String>.of(widget.initial.statuses);
    _voens = List<String>.of(widget.initial.voens);
    _minAmountController.text = widget.initial.minAmount == null
        ? ''
        : _number(widget.initial.minAmount!);
    _maxAmountController.text = widget.initial.maxAmount == null
        ? ''
        : _number(widget.initial.maxAmount!);
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildDateSection(theme),
        const SizedBox(height: 18),
        _buildStatusSection(theme),
        const SizedBox(height: 18),
        _buildAmountSection(theme),
        const SizedBox(height: 18),
        _buildVoenSection(theme),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check_rounded, size: 17),
                label: const Text('Apply Filters'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.restart_alt_rounded, size: 17),
              label: const Text('Clear All'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _savePreset,
            icon: const Icon(Icons.bookmark_add_outlined, size: 17),
            label: const Text('Save Filter Preset'),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _buildDateSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionLabel(theme, 'Date range'),
        const SizedBox(height: 8),
        DropdownButton<DateRangePreset>(
          value: _datePreset,
          isExpanded: true,
          items: <DropdownMenuItem<DateRangePreset>>[
            for (final DateRangePreset preset in DateRangePreset.values)
              DropdownMenuItem<DateRangePreset>(
                value: preset,
                child: Text(preset.label),
              ),
          ],
          onChanged: (DateRangePreset? value) {
            if (value == null) {
              return;
            }
            setState(() {
              _datePreset = value;
              _dateRange = _presetRange(value);
            });
            if (value == DateRangePreset.custom) {
              unawaited(_pickCustomRange());
            }
          },
        ),
        if (_datePreset == DateRangePreset.custom)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => unawaited(_pickCustomRange()),
              icon: const Icon(Icons.date_range_outlined, size: 16),
              label: Text(
                _dateRange == null
                    ? 'Pick a range'
                    : '${AppFormatters.date(_dateRange!.start)} – '
                        '${AppFormatters.date(_dateRange!.end)}',
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickCustomRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _dateRange,
    );
    if (picked == null) {
      return;
    }
    setState(() => _dateRange = picked);
  }

  Widget _buildStatusSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionLabel(theme, 'Status'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String status in widget.statusOptions)
              FilterChip(
                label: Text(status),
                selected: _statuses.contains(status),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _statuses = <String>[..._statuses, status];
                    } else {
                      _statuses = _statuses
                          .where((String value) => value != status)
                          .toList(growable: false);
                    }
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionLabel(theme, 'Amount range'),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _minAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Min amount',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _maxAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Max amount',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoenSection(ThemeData theme) {
    if (widget.voenOptions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionLabel(theme, 'Counterparty VÖEN'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final MapEntry<String, String> entry
                in widget.voenOptions.entries)
              FilterChip(
                label: Text(entry.value.isEmpty ? entry.key : entry.value),
                selected: _voens.contains(entry.key),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _voens = <String>[..._voens, entry.key];
                    } else {
                      _voens = _voens
                          .where((String value) => value != entry.key)
                          .toList(growable: false);
                    }
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  void _apply() {
    final MultiFilterCriteria criteria = MultiFilterCriteria(
      dateRange: _dateRange,
      datePreset: _datePreset,
      statuses: _statuses,
      minAmount: _parseNullable(_minAmountController.text),
      maxAmount: _parseNullable(_maxAmountController.text),
      voens: _voens,
    );
    widget.onApply?.call(criteria);
  }

  void _clearAll() {
    widget.onClear?.call();
  }

  Future<void> _savePreset() async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Save filter preset'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Preset name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) {
      return;
    }
    final MultiFilterCriteria criteria = MultiFilterCriteria(
      dateRange: _dateRange,
      datePreset: _datePreset,
      statuses: _statuses,
      minAmount: _parseNullable(_minAmountController.text),
      maxAmount: _parseNullable(_maxAmountController.text),
      voens: _voens,
    );
    await _persistPreset(name, criteria);
    widget.onSavePreset?.call(criteria, name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Filter preset "$name" saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _persistPreset(
    String name,
    MultiFilterCriteria criteria,
  ) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> existing =
        preferences.getStringList('filter_presets') ?? const <String>[];
    final Map<String, dynamic> preset = <String, dynamic>{
      'name': name,
      'dateRange':
          criteria.dateRange == null
              ? null
              : <String, String>{
                  'start': criteria.dateRange!.start.toIso8601String(),
                  'end': criteria.dateRange!.end.toIso8601String(),
                },
      'datePreset': criteria.datePreset.name,
      'statuses': criteria.statuses,
      'minAmount': criteria.minAmount,
      'maxAmount': criteria.maxAmount,
      'voens': criteria.voens,
    };
    final List<String> updated = <String>[...existing, jsonEncode(preset)];
    await preferences.setStringList('filter_presets', updated);
  }

  static DateTimeRange? _presetRange(DateRangePreset preset) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case DateRangePreset.all:
      case DateRangePreset.custom:
        return null;
      case DateRangePreset.today:
        return DateTimeRange(start: today, end: today);
      case DateRangePreset.thisWeek:
        final DateTime monday = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );
        return DateTimeRange(start: monday, end: today);
      case DateRangePreset.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: today,
        );
    }
  }

  static String _number(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static double? _parseNullable(String value) {
    final String normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }
}
