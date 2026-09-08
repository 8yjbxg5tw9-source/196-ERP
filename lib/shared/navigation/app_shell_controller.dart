import 'package:flutter/foundation.dart';

/// The ordered sections of the application shell.
///
/// The index order MUST stay in sync with the `_navigationDestinations` list
/// in `app_shell.dart` so command-palette navigation lands on the right tab.
enum AppSection {
  dashboard,
  ocrInvoices,
  taxCopilot,
  reconciliation,
  financialReports,
  cashFlow,
  inventory,
  intercompany,
  fxRevaluation,
  assets,
  payroll,
  auditLog,
  settings,
  consolidation,
  taxDeferred,
  kpiDashboard,
  taxDeclaration,
  disasterRecovery,
}

/// Decouples cross-cutting navigation (command palette, system-tray menu,
/// notification clicks) from the [AppShell] widget tree.
class AppShellController extends ChangeNotifier {
  AppShellController([AppSection initial = AppSection.dashboard])
      : _index = initial.index;

  int _index;
  int get index => _index;

  /// Moves the shell to [section].
  void select(AppSection section) {
    if (_index == section.index) {
      return;
    }
    _index = section.index;
    notifyListeners();
  }
}
