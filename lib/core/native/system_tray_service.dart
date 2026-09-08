import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';

/// Native Windows/Linux/macOS system-tray integration.
///
/// The tray menu wires the four required actions to callbacks supplied by the
/// application so this service stays free of UI and DI dependencies. On
/// platforms without tray support every method is a safe no-op.
abstract interface class SystemTrayService {
  bool get isSupported;

  Future<void> initialize();

  Future<void> dispose();
}

class SystemTrayServiceImpl implements SystemTrayService {
  SystemTrayServiceImpl({
    required this.onShowWindow,
    required this.onQuickUpload,
    required this.onRunAutoReconciliation,
    required this.onExit,
    this.iconPath = 'assets/icons/app_icon.ico',
  });

  final VoidCallback onShowWindow;
  final VoidCallback onQuickUpload;
  final VoidCallback onRunAutoReconciliation;
  final VoidCallback onExit;

  /// Resolved at runtime by the `system_tray` plugin (`.ico` on Windows,
  /// `.png` elsewhere).
  final String iconPath;

  final SystemTray _systemTray = SystemTray();
  bool _initialized = false;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  Future<void> initialize() async {
    if (!isSupported || _initialized) {
      return;
    }
    try {
      await _systemTray.initSystemTray(
        title: 'FinAI Studio',
        iconPath: iconPath,
      );
      final Menu menu = Menu();
      await menu.buildFrom(<MenuItemBase>[
        MenuItemLabel(
          label: 'Show FinAI Studio',
          onClicked: (_) => onShowWindow(),
        ),
        MenuItemLabel(
          label: 'Quick Upload Invoices',
          onClicked: (_) => onQuickUpload(),
        ),
        MenuItemLabel(
          label: 'Run Auto Reconciliation',
          onClicked: (_) => onRunAutoReconciliation(),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Exit',
          onClicked: (_) => onExit(),
        ),
      ]);
      await _systemTray.setContextMenu(menu);
      _systemTray.registerSystemTrayEventHandler(_onTrayEvent);
      _initialized = true;
      debugPrint('[SystemTrayService] Tray initialized.');
    } on Object catch (error) {
      debugPrint('[SystemTrayService] Tray init failed: $error');
    }
  }

  void _onTrayEvent(String eventName) {
    if (eventName == kSystemTrayEventClick ||
        eventName == kSystemTrayEventDoubleClick) {
      onShowWindow();
    } else if (eventName == kSystemTrayEventRightClick) {
      unawaited(_systemTray.popUpContextMenu());
    }
  }

  @override
  Future<void> dispose() async {
    if (!_initialized) {
      return;
    }
    try {
      await _systemTray.destroy();
    } on Object catch (error) {
      debugPrint('[SystemTrayService] Tray dispose failed: $error');
    }
    _initialized = false;
  }
}
