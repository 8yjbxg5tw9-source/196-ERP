import 'package:shared_preferences/shared_preferences.dart';

/// App-wide boolean/flag preferences surfaced on the Settings screen.
class AppPreferences {
  static const String _kSystemTray = 'app.system_tray_enabled';
  static const String _kTaxDeadlinePopups = 'app.tax_deadline_popups';
  static const String _kLaunchAtStartup = 'app.launch_at_startup';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> isSystemTrayEnabled() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getBool(_kSystemTray) ?? true;
  }

  Future<bool> areTaxDeadlinePopupsEnabled() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getBool(_kTaxDeadlinePopups) ?? true;
  }

  Future<bool> isLaunchAtStartupEnabled() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getBool(_kLaunchAtStartup) ?? false;
  }

  Future<void> setSystemTrayEnabled(bool value) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setBool(_kSystemTray, value);
  }

  Future<void> setTaxDeadlinePopupsEnabled(bool value) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setBool(_kTaxDeadlinePopups, value);
  }

  Future<void> setLaunchAtStartupEnabled(bool value) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setBool(_kLaunchAtStartup, value);
  }
}
