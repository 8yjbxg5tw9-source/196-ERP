import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/document_repository.dart';
import '../company_context.dart';

const Set<String> _supportedExtensions = <String>{
  '.pdf',
  '.png',
  '.jpg',
  '.jpeg',
};

/// Desktop drag-and-drop ingestion surface with a native picker fallback.
class FileDropZone extends StatefulWidget {
  const FileDropZone({super.key});

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  bool _dragging = false;
  bool _processing = false;
  String _message = 'Drop an invoice, receipt, or bank statement here.';
  List<_FileProcessingStatus> _fileStatuses = <_FileProcessingStatus>[];

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DropTarget(
              onDragEntered: (_) {
                if (mounted) {
                  setState(() => _dragging = true);
                }
              },
              onDragExited: (_) {
                if (mounted) {
                  setState(() => _dragging = false);
                }
              },
              onDragDone: (DropDoneDetails details) {
                setState(() => _dragging = false);
                final List<File> files = details.files
                    .where((DropItem item) => _isSupported(item.path))
                    .map((DropItem item) => File(item.path))
                    .toList(growable: false);
                if (files.isEmpty) {
                  _setMessage('Only PDF, PNG, JPG, and JPEG files are supported.');
                  return;
                }
                unawaited(_processFiles(files, activeCompany));
              },
              child: _buildDropSurface(context, activeCompany),
            ),
            if (_fileStatuses.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              _ProcessingStatusList(statuses: _fileStatuses),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDropSurface(
    BuildContext context,
    CompanyEntity? activeCompany,
  ) {
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.secondary;
    final bool canProcess = activeCompany != null && !_processing;
    final Color borderColor = _dragging
        ? accent
        : theme.colorScheme.outline.withAlpha(120);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: _dragging
            ? accent.withAlpha(18)
            : theme.colorScheme.surfaceContainerHighest.withAlpha(55),
        border: Border.all(
          color: borderColor,
          width: _dragging ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: canProcess ? _pickFiles : null,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withAlpha(24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _processing
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Icon(Icons.upload_file_rounded, color: accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _dragging ? 'Release to upload' : 'Import documents',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activeCompany == null
                        ? 'Select an active company before importing.'
                        : _message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            OutlinedButton.icon(
              onPressed: canProcess ? _pickFiles : null,
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('Choose files'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    if (_processing) {
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'png', 'jpg', 'jpeg'],
      withData: false,
    );
    if (!mounted || result == null) {
      return;
    }

    final List<File> files = result.files
        .map((PlatformFile file) => file.path)
        .whereType<String>()
        .where(_isSupported)
        .map(File.new)
        .toList(growable: false);
    if (files.isEmpty) {
      _setMessage('No supported document was selected.');
      return;
    }

    final CompanyEntity? activeCompany = CompanyContextBuilder.activeCompanyOf(
      context,
    );
    unawaited(_processFiles(files, activeCompany));
  }

  Future<void> _processFiles(
    List<File> files,
    CompanyEntity? activeCompany,
  ) async {
    if (_processing) {
      return;
    }
    if (activeCompany == null) {
      _setMessage('Select an active company before importing documents.');
      return;
    }

    setState(() {
      _processing = true;
      _message = 'Saving files and extracting invoice fields…';
      _fileStatuses = files
          .map(
            (File file) => _FileProcessingStatus(
              fileName: p.basename(file.path),
              status: _FileStatus.pending,
            ),
          )
          .toList(growable: false);
    });

    final DocumentRepository repository = context.read<DocumentRepository>();
    for (int index = 0; index < files.length; index++) {
      if (!mounted) {
        return;
      }
      _setFileStatus(index, _FileStatus.processing);
      final result = await repository.processDocument(
        files[index],
        activeCompany.id,
      );
      if (!mounted) {
        return;
      }
      result.fold(
        (failure) {
          _setFileStatus(index, _FileStatus.failed, failure.message);
        },
        (DocumentEntity document) {
          _setFileStatus(
            index,
            document.status == DocumentStatus.completed
                ? _FileStatus.completed
                : _FileStatus.failed,
            document.status.name,
          );
        },
      );
    }

    if (mounted) {
      setState(() {
        _processing = false;
        _message = 'Import complete. OCR fields are saved locally.';
      });
    }
  }

  void _setFileStatus(
    int index,
    _FileStatus status, [
    String? detail,
  ]) {
    if (!mounted || index >= _fileStatuses.length) {
      return;
    }
    final List<_FileProcessingStatus> statuses =
        List<_FileProcessingStatus>.of(_fileStatuses);
    statuses[index] = statuses[index].copyWith(
      status: status,
      detail: detail,
    );
    setState(() => _fileStatuses = statuses);
  }

  void _setMessage(String message) {
    if (mounted) {
      setState(() => _message = message);
    }
  }

  bool _isSupported(String path) {
    return _supportedExtensions.contains(p.extension(path).toLowerCase());
  }
}

enum _FileStatus {
  pending,
  processing,
  completed,
  failed,
}

class _FileProcessingStatus {
  const _FileProcessingStatus({
    required this.fileName,
    required this.status,
    this.detail,
  });

  final String fileName;
  final _FileStatus status;
  final String? detail;

  _FileProcessingStatus copyWith({
    _FileStatus? status,
    String? detail,
  }) {
    return _FileProcessingStatus(
      fileName: fileName,
      status: status ?? this.status,
      detail: detail ?? this.detail,
    );
  }
}

class _ProcessingStatusList extends StatelessWidget {
  const _ProcessingStatusList({required this.statuses});

  final List<_FileProcessingStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: statuses
          .map(
            (_FileProcessingStatus item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: <Widget>[
                  _StatusIcon(status: item.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  if (item.detail != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        item.detail!,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final _FileStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    switch (status) {
      case _FileStatus.pending:
        return Icon(
          Icons.schedule_outlined,
          size: 17,
          color: theme.colorScheme.onSurfaceVariant,
        );
      case _FileStatus.processing:
        return SizedBox(
          width: 17,
          height: 17,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.secondary,
          ),
        );
      case _FileStatus.completed:
        return Icon(
          Icons.check_circle_outline_rounded,
          size: 17,
          color: theme.colorScheme.secondary,
        );
      case _FileStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 17,
          color: theme.colorScheme.error,
        );
    }
  }
}
