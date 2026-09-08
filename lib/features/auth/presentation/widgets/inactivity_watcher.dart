import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Auto-locks the desktop session after a period without mouse or keyboard
/// activity.
///
/// Pointer movement alone is intentionally ignored (only presses reset the
/// timer) so users reading a dense report are not logged out; any key press or
/// mouse click keeps the session alive.
class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({
    required this.child,
    required this.onLock,
    this.timeout = const Duration(minutes: 15),
    super.key,
  });

  final Widget child;
  final VoidCallback onLock;
  final Duration timeout;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _reschedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    _reschedule();
    return false;
  }

  void _reschedule() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, widget.onLock);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent _) => _reschedule(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
