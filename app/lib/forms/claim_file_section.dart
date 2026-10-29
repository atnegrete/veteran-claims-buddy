import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_theme.dart';
import '../app/app_ui.dart';
import '../auth/auth_redirect.dart';
import '../claim/claim_document.dart';
import '../claim/claim_file_sections.dart';
import '../claim/document_repository.dart';
import '../claim/issue_lane.dart';
import 'file_upload.dart';

/// A filing's drop target and the files already stored in that filing.
///
/// Case Info and My Uploads use the same block. [packet] is the tag stored
/// on each new file. The storage path stays the shared document path.
class ClaimFileSection extends ConsumerStatefulWidget {
  const ClaimFileSection({
    super.key,
    required this.caseId,
    required this.packet,
    this.heading,
    this.lead,
    this.note,
    this.showDropTarget = true,
    this.sectionAcceptsEvidence = true,
  });

  final String caseId;
  final ClaimPacket packet;
  final String? heading;
  final String? lead;
  final String? note;
  final bool showDropTarget;

  /// A file tagged for both filings is listed when this is true.
  final bool sectionAcceptsEvidence;

  @override
  ConsumerState<ClaimFileSection> createState() => _ClaimFileSectionState();
}

class _ClaimFileSectionState extends ConsumerState<ClaimFileSection> {
  var _hover = false;
  var _busy = false;
  String? _error;

  Future<void> _pick() async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'That file could not be opened.');
      return;
    }
    if (!mounted || picked.isEmpty) return;
    final file = picked.first;
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      if (mounted) setState(() => _error = 'That file could not be opened.');
      return;
    }
    await _upload(file.name, bytes);
  }

  Future<void> _drop(List<DropItem> items) async {
    final files = [
      for (final item in items)
        if (item is! DropItemDirectory) item,
    ];
    for (final file in files) {
      if (!mounted) return;
      final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        if (mounted) setState(() => _error = 'That file could not be opened.');
        return;
      }
      final name = file.name.trim().isEmpty ? 'Document' : file.name;
      final saved = await _upload(name, bytes);
      if (!saved) return;
    }
  }

  Future<bool> _upload(String fileName, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxDocumentBytes) {
      setState(() => _error = 'That file must be under 100 MB.');
      return false;
    }
    if (documentContentType(fileName) == null) {
      setState(() => _error = 'Use a PDF, JPEG, or PNG.');
      return false;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await showFileUpload(
      context: context,
      fileName: fileName,
      upload: (onProgress) {
        return ref.read(uploadDocumentProvider)(
          caseId: widget.caseId,
          fileName: fileName,
          bytes: bytes,
          documentType: 'other',
          documentDate: null,
          onProgress: onProgress,
          packet: claimPacketNames[widget.packet]!,
        );
      },
    );
    if (mounted) setState(() => _busy = false);
    return saved;
  }

  Future<void> _remove(ClaimDocument document) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove this file?'),
          content: Text(document.name),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(112, 48)),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: dangerFilledStyle().merge(
                FilledButton.styleFrom(minimumSize: const Size(112, 48)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (remove != true || !mounted) return;
    try {
      await ref.read(removeDocumentProvider)(
        documentId: document.id,
        storagePath: document.storagePath,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That file could not be removed.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(claimDocumentsProvider(widget.caseId));
    final saved = documents.maybeWhen(
      data: (value) => documentsInSection(
        documents: value,
        packet: widget.packet,
        sectionAcceptsEvidence: widget.sectionAcceptsEvidence,
      ),
      orElse: () => const <ClaimDocument>[],
    );
    final heading = widget.heading ?? claimPacketLabels[widget.packet]!;
    final lead = widget.lead ?? claimFileSectionLead(widget.packet);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(heading),
        if (lead.isNotEmpty) ...[const SizedBox(height: 8), LeadText(lead)],
        if (widget.note != null) ...[
          const SizedBox(height: 8),
          InfoNote(text: widget.note!),
        ],
        if (widget.showDropTarget) ...[
          const SizedBox(height: 12),
          _DropZone(
            hovering: _hover,
            enabled: !_busy,
            onTap: _pick,
            onHover: (value) => setState(() => _hover = value),
            onDrop: _drop,
          ),
        ],
        for (var i = 0; i < saved.length; i++) ...[
          const SizedBox(height: 12),
          _FileRow(
            document: saved[i],
            onOpen: () => context.go(
              saved[i].processingStatus == 'needsReview'
                  ? AuthRoutes.caseDocumentFacts(widget.caseId, saved[i].id)
                  : AuthRoutes.caseDocument(widget.caseId, saved[i].id),
            ),
            onRemove: () => _remove(saved[i]),
          ),
        ],
        if (_error != null) ...[const SizedBox(height: 12), ErrorText(_error!)],
        if (documents.hasError)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: ErrorText('These files could not be opened.'),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.hovering,
    required this.enabled,
    required this.onTap,
    required this.onHover,
    required this.onDrop,
  });

  final bool hovering;
  final bool enabled;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;
  final Future<void> Function(List<DropItem> files) onDrop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = hovering ? scheme.primary : scheme.outline;
    return DropTarget(
      enable: enabled,
      onDragEntered: (_) => onHover(true),
      onDragExited: (_) => onHover(false),
      onDragDone: (detail) {
        onHover(false);
        onDrop(detail.files);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            painter: _DashedBorderPainter(color: border),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Drop a PDF, JPEG, or PNG here',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'or choose a file',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.document,
    required this.onOpen,
    required this.onRemove,
  });

  final ClaimDocument document;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reading = documentReadingLabel(
      document.uploadStatus,
      document.processingStatus,
    );
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              Icon(_fileIcon(document.name), color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (reading != null) ...[
                      const SizedBox(height: 2),
                      reading == 'This file could not be read.'
                          ? ErrorText(reading)
                          : Text(
                              reading,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: Icon(
                  Icons.delete_outline,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _fileIcon(String name) {
  return switch (documentContentType(name)) {
    'application/pdf' => Icons.picture_as_pdf_outlined,
    'image/jpeg' || 'image/png' => Icons.image_outlined,
    _ => Icons.insert_drive_file_outlined,
  };
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
