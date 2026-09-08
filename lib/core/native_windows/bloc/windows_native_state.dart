import 'package:equatable/equatable.dart';

abstract class WindowsNativeState extends Equatable {
  const WindowsNativeState();

  @override
  List<Object?> get props => const <Object?>[];
}

class WindowsNativeInitial extends WindowsNativeState {
  const WindowsNativeInitial();
}

class NativeServicesInitialized extends WindowsNativeState {
  const NativeServicesInitialized();
}

class TrayActiveState extends WindowsNativeState {
  const TrayActiveState(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => <Object?>[enabled];
}

class NotificationDispatched extends WindowsNativeState {
  const NotificationDispatched(this.title);

  final String title;

  @override
  List<Object?> get props => <Object?>[title];
}
