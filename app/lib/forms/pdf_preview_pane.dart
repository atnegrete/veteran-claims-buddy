import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../app/app_ui.dart';

/// Renders PDF bytes in a bordered, read-only viewer. The one place a generated
/// or watermarked PDF is shown on screen; shared by the form preview and the
/// Nexus Letters. Shows a spinner while [bytes] is null and [loading], an error
/// with a retry, or the pages. It never prints, shares, or lets the page change.
class PdfPreviewPane extends StatelessWidget {
  const PdfPreviewPane({
    super.key,
    required this.bytes,
    this.loading = false,
    this.error,
    this.onRetry,
    this.height = 640,
  });

  final Uint8List? bytes;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final double height;

  // A cheap, stable hash so the viewer rebuilds when the bytes change.
  int _previewKey(Uint8List data) {
    var hash = data.length;
    final step = math.max(1, data.length ~/ 24);
    for (var i = 0; i < data.length; i += step) {
      hash = (hash * 31 + data[i]) & 0x7fffffff;
    }
    return hash;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, child: _body(Theme.of(context)));
  }

  Widget _body(ThemeData theme) {
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorText(error!),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      );
    }
    final data = bytes;
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final viewer = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: PdfPreview(
          key: ValueKey(_previewKey(data)),
          build: (_) => data,
          allowPrinting: false,
          allowSharing: false,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          useActions: false,
          previewPageMargin: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        ),
      ),
    );
    if (!loading) return viewer;
    return Stack(
      children: [
        Positioned.fill(child: viewer),
        const Positioned(
          top: 12,
          right: 12,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ],
    );
  }
}
