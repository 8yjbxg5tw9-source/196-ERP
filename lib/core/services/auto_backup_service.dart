import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/secure_storage_service.dart';
import 'backup_service.dart';

/// How often the background service attempts to create a backup.
enum BackupFrequency { daily, weekly, onAppExit }

/// Schedules and runs automatic encrypted backups with retention control.
///
/// The service persists its schedule and last-run timestamp in
/// [SharedPreferences] and uses [BackupService] for the actual encryption and
/// retention (capped at the ten most recent archives).
class AutoBackupService {
  AutoBackupService({
    required BackupService backupService,
    required SecureStorageService secureStorage,
    required SharedPreferences preferences,
  })  : _backupService = backupService,
        _secureStorage = secureStorage,
        _preferences = preferences;

  static const String _frequencyKey = 'auto_backup_frequency';
  static const String _lastRunKey = 'auto_backup_last_run';
  static const Duration _pollInterval = Duration(minutes: 5);
  static const Duration _exitThrottle = Duration(minutes: 5);

  final BackupService _backupService;
  final SecureStorageService _secureStorage;
  final SharedPreferences _preferences;

  Timer? _timer;
  bool _running = false;

  BackupFrequency get frequency {
    final String? stored = _preferences.getString(_frequencyKey);
    for (final BackupFrequency value in BackupFrequency.values) {
      if (value.name == stored) {
        return value;
      }
    }
    return BackupFrequency.weekly;
  }

  Future<void> setFrequency(BackupFrequency value) async {
    await _preferences.setString(_frequencyKey, value.name);
  }

  Future<DateTime?> lastBackupAt() async {
    final String? stored = _preferences.getString(_lastRunKey);
    if (stored == null) {
      return null;
    }
    return DateTime.tryParse(stored);
  }

  /// Begins the periodic due-check timer and evaluates immediately.
  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _timer ??= Timer.periodic(_pollInterval, (Timer _) => unawaited(_tick()));
    unawaited(_tick());
  }

  /// Stops the periodic timer. Pending backups are unaffected.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Creates a backup immediately, regardless of schedule.
  Future<bool> runBackupNow() async {
    final String? companyId = await _activeCompanyId();
    if (companyId == null) {
      debugPrint('[AutoBackupService] No active company; skipping backup.');
      return false;
    }
    try {
      await _backupService.createBackup(companyId);
      await _preferences.setString(
        _lastRunKey,
        DateTime.now().toUtc().toIso8601String(),
      );
      return true;
    } on Object catch (error) {
      debugPrint('[AutoBackupService] Backup failed: $error');
      return false;
    }
  }

  /// Backs up on application exit when the configured frequency allows it.
  ///
  /// A short throttle prevents duplicate archives when both the desktop close
  /// button and the OS lifecycle handler fire for the same exit.
  Future<void> backupOnAppExit() async {
    if (frequency != BackupFrequency.onAppExit) {
      return;
    }
    final DateTime? lastRun = await lastBackupAt();
    if (lastRun != null &&
        DateTime.now().difference(lastRun) < _exitThrottle) {
      return;
    }
    await runBackupNow();
  }

  Future<void> _tick() async {
    if (frequency == BackupFrequency.onAppExit) {
      return;
    }
    if (!await _isDue()) {
      return;
    }
    await runBackupNow();
  }

  Future<bool> _isDue() async {
    final DateTime? lastRun = await lastBackupAt();
    if (lastRun == null) {
      return true;
    }
    final DateTime now = DateTime.now();
    if (frequency == BackupFrequency.daily) {
      final DateTime last = lastRun.toLocal();
      return last.year != now.year ||
          last.month != now.month ||
          last.day != now.day;
    }
    if (frequency == BackupFrequency.weekly) {
      return now.difference(lastRun) >= const Duration(days: 7);
    }
    return false;
  }

  Future<String?> _activeCompanyId() async {
    final String? companyId = await _secureStorage.read(
      SecureStorageKeys.activeCompanyId,
    );
    if (companyId == null || companyId.trim().isEmpty) {
      return null;
    }
    return companyId;
  }
}
