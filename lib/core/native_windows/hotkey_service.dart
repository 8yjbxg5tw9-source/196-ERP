import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PhysicalKeyboardKey;
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application-wide keyboard shortcuts registered via `hotkey_manager`.
enum HotkeyAction { newTransaction, openReconciliation, globalSearch, runTaxAudit }

extension HotkeyActionMeta on HotkeyAction {
  String get label => switch (this) {
        HotkeyAction.newTransaction => 'Quick transaction entry',
        HotkeyAction.openReconciliation => 'Bank reconciliation',
        HotkeyAction.globalSearch => 'Global search',
        HotkeyAction.runTaxAudit => 'Tax audit inspector',
      };

  /// Default letter key for this action (modifiers are fixed per action).
  String get defaultKey => switch (this) {
        HotkeyAction.newTransaction => 'N',
        HotkeyAction.openReconciliation => 'R',
        HotkeyAction.globalSearch => 'F',
        HotkeyAction.runTaxAudit => 'A',
      };

  List<HotKeyModifier> get modifiers => switch (this) {
        HotkeyAction.newTransaction => <HotKeyModifier>[HotKeyModifier.control],
        HotkeyAction.openReconciliation =>
          <HotKeyModifier>[HotKeyModifier.control, HotKeyModifier.shift],
        HotkeyAction.globalSearch => <HotKeyModifier>[HotKeyModifier.control],
        HotkeyAction.runTaxAudit =>
          <HotKeyModifier>[HotKeyModifier.control, HotKeyModifier.shift],
      };
}

/// Registers and rebinds application-wide hotkeys with persisted per-action
/// letter overrides in [SharedPreferences].
class HotkeyService {
  HotkeyService({SharedPreferences? preferences}) : _preferences = preferences;

  final SharedPreferences? _preferences;

  static const String _keyPrefix = 'hotkey.';

  String _prefKey(HotkeyAction action) => '$_keyPrefix${action.name}.key';

  /// The active letter key for [action], honouring any user override.
  String keyOf(HotkeyAction action) {
    final String? stored = _preferences?.getString(_prefKey(action));
    return stored != null && stored.isNotEmpty ? stored : action.defaultKey;
  }

  Future<void> setKey(HotkeyAction action, String letter) async {
    await _preferences?.setString(_prefKey(action), letter);
  }

  /// Human-readable binding, e.g. `Ctrl+Shift+R`.
  String shortcutLabel(HotkeyAction action) {
    final String modifiers = action.modifiers
        .map((HotKeyModifier modifier) => _modifierLabel(modifier))
        .join('+');
    return '$modifiers+${keyOf(action)}';
  }

  /// Registers every action in [handlers], replacing any prior bindings.
  Future<void> registerAll({
    required Map<HotkeyAction, VoidCallback> handlers,
  }) async {
    await unregisterAll();
    for (final MapEntry<HotkeyAction, VoidCallback> entry in handlers.entries) {
      final HotKey hotKey = HotKey(
        key: _physicalKey(keyOf(entry.key)),
        modifiers: entry.key.modifiers,
        scope: HotKeyScope.inapp,
      );
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (HotKey _) => entry.value(),
      );
    }
  }

  Future<void> unregisterAll() async {
    await hotKeyManager.unregisterAll();
  }

  static String _modifierLabel(HotKeyModifier modifier) {
    return switch (modifier) {
      HotKeyModifier.control => 'Ctrl',
      HotKeyModifier.shift => 'Shift',
      HotKeyModifier.alt => 'Alt',
      HotKeyModifier.meta => 'Meta',
      _ => modifier.name,
    };
  }

  static PhysicalKeyboardKey _physicalKey(String letter) {
    final String normalized = letter.toUpperCase();
    final Map<String, PhysicalKeyboardKey> letters =
        <String, PhysicalKeyboardKey>{
      'A': PhysicalKeyboardKey.keyA,
      'B': PhysicalKeyboardKey.keyB,
      'C': PhysicalKeyboardKey.keyC,
      'D': PhysicalKeyboardKey.keyD,
      'E': PhysicalKeyboardKey.keyE,
      'F': PhysicalKeyboardKey.keyF,
      'G': PhysicalKeyboardKey.keyG,
      'H': PhysicalKeyboardKey.keyH,
      'I': PhysicalKeyboardKey.keyI,
      'J': PhysicalKeyboardKey.keyJ,
      'K': PhysicalKeyboardKey.keyK,
      'L': PhysicalKeyboardKey.keyL,
      'M': PhysicalKeyboardKey.keyM,
      'N': PhysicalKeyboardKey.keyN,
      'O': PhysicalKeyboardKey.keyO,
      'P': PhysicalKeyboardKey.keyP,
      'Q': PhysicalKeyboardKey.keyQ,
      'R': PhysicalKeyboardKey.keyR,
      'S': PhysicalKeyboardKey.keyS,
      'T': PhysicalKeyboardKey.keyT,
      'U': PhysicalKeyboardKey.keyU,
      'V': PhysicalKeyboardKey.keyV,
      'W': PhysicalKeyboardKey.keyW,
      'X': PhysicalKeyboardKey.keyX,
      'Y': PhysicalKeyboardKey.keyY,
      'Z': PhysicalKeyboardKey.keyZ,
      '0': PhysicalKeyboardKey.digit0,
      '1': PhysicalKeyboardKey.digit1,
      '2': PhysicalKeyboardKey.digit2,
      '3': PhysicalKeyboardKey.digit3,
      '4': PhysicalKeyboardKey.digit4,
      '5': PhysicalKeyboardKey.digit5,
      '6': PhysicalKeyboardKey.digit6,
      '7': PhysicalKeyboardKey.digit7,
      '8': PhysicalKeyboardKey.digit8,
      '9': PhysicalKeyboardKey.digit9,
    };
    return letters[normalized] ?? PhysicalKeyboardKey.keyF;
  }
}
