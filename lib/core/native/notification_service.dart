import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

/// Desktop toast notification payload.
class AppNotification {
  const AppNotification({required this.title, required this.body, this.payload});

  final String title;
  final String body;

  /// Opaque string the navigation handler uses to route to a module,
  /// e.g. `invoice:{documentId}` or `module:reconciliation`.
  final String? payload;
}

/// Wraps the `local_notifier` plugin behind a small abstraction so the rest
/// of the app never imports platform code directly.
abstract interface class NotificationService {
  Future<void> initialize();

  /// Displays a toast. When the user clicks it, [onClick] is invoked with the
  /// original payload so the application can focus its window and navigate.
  Future<void> showNotification(
    AppNotification notification, {
    ValueChanged<String?>? onClick,
  });
}

class NotificationServiceImpl implements NotificationService {
  NotificationServiceImpl({this.appName = 'FinAI Studio'});

  final String appName;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      await localNotifier.setup(
        appName: appName,
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _initialized = true;
    } on Object catch (error) {
      debugPrint('[NotificationService] init failed: $error');
    }
  }

  @override
  Future<void> showNotification(
    AppNotification notification, {
    ValueChanged<String?>? onClick,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      final LocalNotification localNotification = LocalNotification(
        title: notification.title,
        body: notification.body,
      );
      if (onClick != null) {
        localNotification.onClick = () => onClick(notification.payload);
        localNotification.onClickAction = () => onClick(notification.payload);
      }
      await localNotification.show();
    } on Object catch (error) {
      debugPrint('[NotificationService] show failed: $error');
    }
  }
}
