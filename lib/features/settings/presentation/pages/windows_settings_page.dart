import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/native_windows/bloc/windows_native_bloc.dart';
import '../../../../core/native_windows/bloc/windows_native_event.dart';
import '../../../../core/native_windows/bloc/windows_native_state.dart';
import '../../../../core/native_windows/hotkey_service.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../injection_container.dart';

/// Windows integration preferences and the application hotkey customizer.
class WindowsSettingsPage extends StatelessWidget {
  const WindowsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WindowsNativeBloc>.value(
      value: sl<WindowsNativeBloc>(),
      child: const _WindowsSettingsView(),
    );
  }
}

class _WindowsSettingsView extends StatefulWidget {
  const _WindowsSettingsView();

  @override
  State<_WindowsSettingsView> createState() => _WindowsSettingsViewState();
}

class _WindowsSettingsViewState extends State<_WindowsSettingsView> {
  final Map<HotkeyAction, String> _bindings = <HotkeyAction, String>{};
  bool? _toastEnabled;

  @override
  void initState() {
    super.initState();
    final HotkeyService hotkeyService = sl<HotkeyService>();
    for (final HotkeyAction action in HotkeyAction.values) {
      _bindings[action] = hotkeyService.keyOf(action);
    }
    _loadToastPreference();
  }

  Future<void> _loadToastPreference() async {
    final bool enabled =
        await sl<AppPreferences>().areTaxDeadlinePopupsEnabled();
    if (mounted) {
      setState(() => _toastEnabled = enabled);
    }
  }

  String _labelOf(HotkeyAction action) {
    final String letter = _bindings[action] ?? action.defaultKey;
    final String modifiers = action.modifiers
        .map((HotKeyModifier modifier) => switch (modifier) {
              HotKeyModifier.control => 'Ctrl',
              HotKeyModifier.shift => 'Shift',
              HotKeyModifier.alt => 'Alt',
              HotKeyModifier.meta => 'Meta',
              _ => modifier.name,
            })
        .join('+');
    return '$modifiers+$letter';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Windows Integration & Hotkeys')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Global keyboard shortcuts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rebind the application-wide shortcuts used across the '
                  'desktop workspace. Changes apply immediately.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _HotkeyTable(
                  actions: HotkeyAction.values,
                  bindings: _bindings,
                  labelOf: _labelOf,
                  onRebind: (HotkeyAction action, String letter) {
                    setState(() => _bindings[action] = letter);
                    context
                        .read<WindowsNativeBloc>()
                        .add(RebindHotkeyEvent(action: action, letter: letter));
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Notification & tray behaviour',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable native toast notifications'),
                  subtitle: const Text(
                    'Windows 10/11 toast popups for fraud warnings, payroll '
                    'batch completion, and backup finishes.',
                  ),
                  value: _toastEnabled ?? true,
                  onChanged: (bool value) {
                    setState(() => _toastEnabled = value);
                    sl<AppPreferences>().setTaxDeadlinePopupsEnabled(value);
                  },
                ),
                BlocBuilder<WindowsNativeBloc, WindowsNativeState>(
                  builder: (BuildContext context, WindowsNativeState state) {
                    final bool trayEnabled = switch (state) {
                      TrayActiveState(:final enabled) => enabled,
                      _ => true,
                    };
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Minimize to system tray on close'),
                      subtitle: const Text(
                        'Closing the window hides FinAI Studio to the taskbar '
                        'tray instead of terminating it.',
                      ),
                      value: trayEnabled,
                      onChanged: (bool value) {
                        context.read<WindowsNativeBloc>().add(
                              ToggleMinimizeToTrayEvent(value),
                            );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HotkeyTable extends StatelessWidget {
  const _HotkeyTable({
    required this.actions,
    required this.bindings,
    required this.labelOf,
    required this.onRebind,
  });

  final List<HotkeyAction> actions;
  final Map<HotkeyAction, String> bindings;
  final String Function(HotkeyAction) labelOf;
  final void Function(HotkeyAction, String) onRebind;

  static const List<String> _letters = <String>[
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: Column(
        children: <Widget>[
          for (final HotkeyAction action in actions)
            ListTile(
              leading: Icon(_iconOf(action), color: theme.colorScheme.secondary),
              title: Text(action.label),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      labelOf(action),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: bindings[action] ?? action.defaultKey,
                    items: <DropdownMenuItem<String>>[
                      for (final String letter in _letters)
                        DropdownMenuItem<String>(
                          value: letter,
                          child: Text(letter),
                        ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        onRebind(action, value);
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static IconData _iconOf(HotkeyAction action) {
    return switch (action) {
      HotkeyAction.newTransaction => Icons.add_circle_outline_rounded,
      HotkeyAction.openReconciliation => Icons.balance_rounded,
      HotkeyAction.globalSearch => Icons.search_rounded,
      HotkeyAction.runTaxAudit => Icons.gavel_rounded,
    };
  }
}
