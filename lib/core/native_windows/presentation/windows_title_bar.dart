import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../config/theme/app_colors.dart';

/// Dark custom titlebar for the frameless desktop window.
///
/// The native title bar is hidden (`TitleBarStyle.hidden`) and this widget
/// provides the active-company badge, connection status, and the
/// minimize / maximize-restore / close-to-tray window controls.
class WindowsTitleBar extends StatelessWidget {
  const WindowsTitleBar({
    required this.companyName,
    required this.cloudConnected,
    this.closeToTray = true,
    super.key,
  });

  final String? companyName;
  final bool cloudConnected;

  /// When true, the close button hides the window (minimize-to-tray) instead
  /// of terminating the process.
  final bool closeToTray;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      height: 40,
      color: AppColors.primaryDark,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 12),
          Icon(Icons.monitor_heart_outlined, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            'FinAI Studio',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (companyName != null && companyName!.isNotEmpty) ...<Widget>[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                companyName!,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          _ConnectionDot(connected: cloudConnected),
          const SizedBox(width: 4),
          Text(
            cloudConnected ? 'Cloud Sync' : 'Offline SQLite',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white54,
            ),
          ),
          const Spacer(),
          _WindowButton(
            icon: Icons.minimize_rounded,
            tooltip: 'Minimize',
            onPressed: () => windowManager.minimize(),
          ),
          _MaximizeButton(),
          _WindowButton(
            icon: Icons.close_rounded,
            tooltip: closeToTray ? 'Close to tray' : 'Close',
            onPressed: () {
              if (closeToTray) {
                windowManager.hide();
              } else {
                windowManager.destroy();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? AppColors.success : AppColors.warning,
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 44,
          height: 40,
          child: Icon(icon, size: 16, color: Colors.white70),
        ),
      ),
    );
  }
}

class _MaximizeButton extends StatefulWidget {
  @override
  State<_MaximizeButton> createState() => _MaximizeButtonState();
}

class _MaximizeButtonState extends State<_MaximizeButton>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _refresh();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    final bool maximized = await windowManager.isMaximized();
    if (mounted && maximized != _maximized) {
      setState(() => _maximized = maximized);
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _maximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _maximized = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _WindowButton(
      icon: _maximized
          ? Icons.filter_none_rounded
          : Icons.crop_square_rounded,
      tooltip: _maximized ? 'Restore' : 'Maximize',
      onPressed: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
    );
  }
}
