import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';

import '../../domain/entities/document_entity.dart';

/// Local PDF/image viewer used by the verification split view.
///
/// PDF rendering is provided by pdfx's Windows-compatible PdfView. Images use
/// Flutter's InteractiveViewer so both media types share zoom, rotation, and
/// reset controls.
class DocumentViewer extends StatefulWidget {
  const DocumentViewer({required this.document, super.key});

  final DocumentEntity document;

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  late final TransformationController _imageController;
  PdfController? _pdfController;
  double _zoom = 1;
  double _rotation = 0;
  Object? _pdfError;

  bool get _isPdf =>
      p.extension(widget.document.filePath).toLowerCase() == '.pdf';

  @override
  void initState() {
    super.initState();
    _imageController = TransformationController();
    _openDocument();
  }

  @override
  void didUpdateWidget(covariant DocumentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.filePath != widget.document.filePath) {
      _pdfController?.dispose();
      _pdfController = null;
      _pdfError = null;
      _resetView();
      _openDocument();
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _imageController.dispose();
    super.dispose();
  }

  void _openDocument() {
    if (!_isPdf) {
      return;
    }
    try {
      _pdfController = PdfController(
        document: PdfDocument.openFile(widget.document.filePath),
      );
    } on Object catch (error) {
      _pdfError = error;
    }
  }

  void _changeZoom(double delta) {
    final double nextZoom = (_zoom + delta).clamp(0.5, 3.0).toDouble();
    final double factor = nextZoom / _zoom;
    setState(() => _zoom = nextZoom);
    if (!_isPdf) {
      final Matrix4 nextTransform = Matrix4.copy(_imageController.value)
        ..scale(factor);
      _imageController.value = nextTransform;
    }
  }

  void _rotate() {
    setState(() => _rotation += 1.57079632679);
  }

  void _resetView() {
    setState(() {
      _zoom = 1;
      _rotation = 0;
      _imageController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(35),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(80)),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _buildToolbar(context),
          Expanded(child: _buildDocumentSurface(context)),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withAlpha(70)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            _isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
            size: 17,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.document.fileName,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Zoom out',
            onPressed: () => _changeZoom(-0.1),
            icon: const Icon(Icons.remove_rounded, size: 17),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 45,
            child: Text(
              '${(_zoom * 100).round()}%',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ),
          IconButton(
            tooltip: 'Zoom in',
            onPressed: () => _changeZoom(0.1),
            icon: const Icon(Icons.add_rounded, size: 17),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Rotate 90 degrees',
            onPressed: _rotate,
            icon: const Icon(Icons.rotate_right_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Reset view',
            onPressed: _resetView,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSurface(BuildContext context) {
    if (!File(widget.document.filePath).existsSync()) {
      return const _ViewerMessage(
        icon: Icons.folder_off_outlined,
        message: 'The stored document file is unavailable.',
      );
    }
    if (_isPdf) {
      final PdfController? controller = _pdfController;
      if (_pdfError != null || controller == null) {
        return _ViewerMessage(
          icon: Icons.picture_as_pdf_outlined,
          message: 'This PDF could not be opened.',
          detail: _pdfError?.toString(),
        );
      }
      return Transform.rotate(
        angle: _rotation,
        child: Transform.scale(
          scale: _zoom,
          child: PdfView(
            controller: controller,
            scrollDirection: Axis.vertical,
            backgroundDecoration: const BoxDecoration(
              color: Color(0xffe8eaed),
            ),
            onDocumentError: (Object error) {
              if (mounted) {
                setState(() => _pdfError = error);
              }
            },
          ),
        ),
      );
    }

    return InteractiveViewer(
      transformationController: _imageController,
      minScale: 0.5,
      maxScale: 4,
      boundaryMargin: const EdgeInsets.all(80),
      child: Transform.rotate(
        angle: _rotation,
        child: Image.file(
          File(widget.document.filePath),
          fit: BoxFit.contain,
          errorBuilder: (_, Object error, __) => _ViewerMessage(
            icon: Icons.broken_image_outlined,
            message: 'This image could not be displayed.',
            detail: error.toString(),
          ),
        ),
      ),
    );
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({
    required this.icon,
    required this.message,
    this.detail,
  });

  final IconData icon;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 42, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (detail != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                detail!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
