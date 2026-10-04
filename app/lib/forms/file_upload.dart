import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FileUploadException implements Exception {
  const FileUploadException(this.message);

  final String message;
}

typedef ReportProgress = void Function(double progress);

/// Sends bytes to storage and reports how much has landed, from 0 to 1.
Future<void> uploadBytes({
  required Reference file,
  required Uint8List bytes,
  required String contentType,
  required ReportProgress onProgress,
}) async {
  final task = file.putData(bytes, SettableMetadata(contentType: contentType));
  final events = task.snapshotEvents.listen((snapshot) {
    final total = snapshot.totalBytes;
    if (total <= 0) return;
    onProgress(snapshot.bytesTransferred / total);
  });
  try {
    await task;
    onProgress(1);
  } finally {
    await events.cancel();
  }
}

/// Blocks the screen with a progress dialog until [upload] finishes.
///
/// A failure stays in the dialog with Retry. Closing the dialog does not
/// finish the upload.
Future<bool> showFileUpload({
  required BuildContext context,
  required String fileName,
  required Future<void> Function(ReportProgress onProgress) upload,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _FileUploadDialog(fileName: fileName, upload: upload),
  );
  return saved ?? false;
}

class _FileUploadDialog extends StatefulWidget {
  const _FileUploadDialog({required this.fileName, required this.upload});

  final String fileName;
  final Future<void> Function(ReportProgress onProgress) upload;

  @override
  State<_FileUploadDialog> createState() => _FileUploadDialogState();
}

class _FileUploadDialogState extends State<_FileUploadDialog> {
  var _progress = 0.0;
  var _running = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
    });
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
      _progress = 0;
    });
    try {
      await widget.upload((value) {
        if (!mounted) return;
        setState(() => _progress = value.clamp(0, 1));
      });
      if (mounted) Navigator.of(context).pop(true);
    } on FileUploadException catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = 'That file could not be saved. Try the upload again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_running,
      child: AlertDialog(
        title: const Text('Uploading'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.fileName, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _running && _progress == 0 ? null : _progress,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
        actions: [
          if (!_running)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(112, 48)),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Close'),
            ),
          if (!_running)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(112, 48)),
              onPressed: _run,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
