import 'package:equatable/equatable.dart';

import '../hotkey_service.dart';

/// Categories of desktop toast notifications the app can dispatch.
enum WindowsNotificationType { fraudWarning, payrollComplete, backupComplete, info }

abstract class WindowsNativeEvent extends Equatable {
  const WindowsNativeEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class InitNativeServicesEvent extends WindowsNativeEvent {
  const InitNativeServicesEvent();
}

class TriggerToastNotificationEvent extends WindowsNativeEvent {
  const TriggerToastNotificationEvent({
    required this.title,
    required this.body,
    this.type = WindowsNotificationType.info,
  });

  final String title;
  final String body;
  final WindowsNotificationType type;

  @override
  List<Object?> get props => <Object?>[title, body, type];
}

class ToggleMinimizeToTrayEvent extends WindowsNativeEvent {
  const ToggleMinimizeToTrayEvent(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => <Object?>[enabled];
}

class RebindHotkeyEvent extends WindowsNativeEvent {
  const RebindHotkeyEvent({required this.action, required this.letter});

  final HotkeyAction action;
  final String letter;

  @override
  List<Object?> get props => <Object?>[action, letter];
}
