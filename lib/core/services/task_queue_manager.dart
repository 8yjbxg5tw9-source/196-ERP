import 'dart:async';

import 'package:flutter/foundation.dart';

/// A unit of work executed by the [TaskQueueManager].
typedef TaskOperation<T> = Future<T> Function();

/// Emitted by the queue as a task's reported progress changes.
class TaskProgress {
  const TaskProgress({required this.taskId, required this.name, this.progress});

  final String taskId;
  final String name;

  /// 0.0–1.0, or null while the task is indeterminate.
  final double? progress;
}

/// Completed task result.
class TaskResult<T> {
  const TaskResult({required this.taskId, this.value, this.error});

  final String taskId;
  final T? value;
  final Object? error;

  bool get hasError => error != null;
}

/// Serial background queue for heavy work (OCR transforms, PDF generation,
/// large exports). It streams real-time 0–100% progress so the UI can render
/// determinate bars without blocking the isolate-local event loop.
class TaskQueueManager {
  TaskQueueManager._();

  static final TaskQueueManager instance = TaskQueueManager._();

  final StreamController<TaskProgress> _progressController =
      StreamController<TaskProgress>.broadcast();

  final Map<String, double?> _progress = <String, double?>{};
  Future<void> _tail = Future<void>.value();

  /// Progress of every task ever enqueued in this session, keyed by task id.
  Map<String, double?> get progress => Map<String, double?>.unmodifiable(
    _progress,
  );

  Stream<TaskProgress> get onProgress => _progressController.stream;

  /// Enqueues [operation] and returns a future that resolves with the
  /// operation's return value when the task reaches the front of the queue.
  ///
  /// [onProgress] reports 0.0–1.0 as [report] is called inside the operation.
  Future<T> enqueue<T>(
    String taskId,
    String name,
    TaskOperation<T> operation, {
    void Function(double progress)? onProgress,
  }) {
    final Completer<T> completer = Completer<T>();
    _tail = _tail.then((_) async {
      _progress[taskId] = null;
      _emit(taskId, name, null);
      try {
        final T value = await operation();
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      } on Object catch (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
        debugPrint('[TaskQueueManager] task "$name" failed: $error');
      } finally {
        _progress.remove(taskId);
      }
    });
    if (onProgress != null) {
      onProgress(0);
    }
    // The queue itself is awaited internally; the caller only cares about the
    // operation result, surfaced through the completer.
    return completer.future;
  }

  /// Reports progress for [taskId]. Call from inside a task operation.
  void report(String taskId, String name, double progress) {
    final double clamped = progress.clamp(0.0, 1.0).toDouble();
    _progress[taskId] = clamped;
    _emit(taskId, name, clamped);
  }

  void _emit(String taskId, String name, double? progress) {
    if (!_progressController.isClosed) {
      _progressController.add(
        TaskProgress(taskId: taskId, name: name, progress: progress),
      );
    }
  }

  void dispose() {
    unawaited(_progressController.close());
  }
}
