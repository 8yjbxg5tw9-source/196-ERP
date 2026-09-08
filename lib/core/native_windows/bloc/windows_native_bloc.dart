import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/navigation/app_shell_controller.dart';
import '../../native/notification_service.dart';
import '../../native/system_tray_service.dart';
import '../../storage/app_preferences.dart';
import '../hotkey_service.dart';
import 'windows_native_event.dart';
import 'windows_native_state.dart';

/// Coordinates OS-level integrations: global hotkeys, native toast
/// notifications, and minimize-to-tray behaviour.
class WindowsNativeBloc
    extends Bloc<WindowsNativeEvent, WindowsNativeState> {
  WindowsNativeBloc({
    required HotkeyService hotkeyService,
    required NotificationService notificationService,
    required SystemTrayService systemTrayService,
    required AppPreferences preferences,
    required AppShellController shellController,
    required VoidCallback onGlobalSearch,
  })  : _hotkeyService = hotkeyService,
        _notificationService = notificationService,
        _systemTrayService = systemTrayService,
        _preferences = preferences,
        _shellController = shellController,
        _onGlobalSearch = onGlobalSearch,
        super(const WindowsNativeInitial()) {
    on<InitNativeServicesEvent>(_onInit);
    on<TriggerToastNotificationEvent>(_onToast);
    on<ToggleMinimizeToTrayEvent>(_onToggleTray);
    on<RebindHotkeyEvent>(_onRebind);
  }

  final HotkeyService _hotkeyService;
  final NotificationService _notificationService;
  final SystemTrayService _systemTrayService;
  final AppPreferences _preferences;
  final AppShellController _shellController;
  final VoidCallback _onGlobalSearch;

  Future<void> _onInit(
    InitNativeServicesEvent event,
    Emitter<WindowsNativeState> emit,
  ) async {
    await _notificationService.initialize();
    await _registerHotkeys();
    if (await _preferences.isSystemTrayEnabled()) {
      await _systemTrayService.initialize();
    }
    emit(const NativeServicesInitialized());
  }

  Future<void> _onToast(
    TriggerToastNotificationEvent event,
    Emitter<WindowsNativeState> emit,
  ) async {
    await _notificationService.showNotification(
      AppNotification(title: event.title, body: event.body),
    );
    emit(NotificationDispatched(event.title));
  }

  Future<void> _onToggleTray(
    ToggleMinimizeToTrayEvent event,
    Emitter<WindowsNativeState> emit,
  ) async {
    await _preferences.setSystemTrayEnabled(event.enabled);
    if (event.enabled) {
      await _systemTrayService.initialize();
    } else {
      await _systemTrayService.dispose();
    }
    emit(TrayActiveState(event.enabled));
  }

  Future<void> _onRebind(
    RebindHotkeyEvent event,
    Emitter<WindowsNativeState> emit,
  ) async {
    await _hotkeyService.setKey(event.action, event.letter);
    await _registerHotkeys();
    emit(const NativeServicesInitialized());
  }

  Future<void> _registerHotkeys() async {
    // `hotkey_manager` only supports desktop targets.
    if (kIsWeb || !_isDesktopPlatform) {
      return;
    }
    await _hotkeyService.registerAll(
      <HotkeyAction, VoidCallback>{
        HotkeyAction.newTransaction: () =>
            _shellController.select(AppSection.reconciliation),
        HotkeyAction.openReconciliation: () =>
            _shellController.select(AppSection.reconciliation),
        HotkeyAction.globalSearch: _onGlobalSearch,
        HotkeyAction.runTaxAudit: () =>
            _shellController.select(AppSection.taxCopilot),
      },
    );
  }

  static bool get _isDesktopPlatform {
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }
}
