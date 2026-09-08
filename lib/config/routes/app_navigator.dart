import 'package:flutter/widgets.dart';

/// Root navigator key shared by the command palette, system-tray menu, and
/// notification click handlers so they can push routes from anywhere.
abstract final class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
}
