import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_document.dart';
import '../../claim/claim_guide.dart';
import '../../claim/document_repository.dart';
import '../../forms/file_upload.dart';
import '../../forms/form_actions.dart';
import '../../forms/iso_date_field.dart';
import 'shell_pages.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key, required this.caseId, this.adding = false});

  final String caseId;
  final bool adding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(claimDocumentsProvider(caseId));
    return ShellPage(
      title: 'Documents',
      child: documents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('These documents could not be opened.'),
        data: (all) {
          final saved = [
            for (final document in all)
              if (document.caseId == caseId) document,
          ];
          final showForm = adding || saved.isEmpty;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EarlierClaimNote(caseId: caseId),
              const Text('Files for this claim stay here.'),
              const SizedBox(height: 12),
              const AppBadge.notFiled(),
              const SizedBox(height: 16),
              if (!showForm)
                for (var i = 0; i < saved.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _DocumentCard(caseId: caseId, document: saved[i]),
                ],
              if (showForm) ...[
                if (saved.isNotEmpty) ...[
                  for (var i = 0; i < saved.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _DocumentCard(caseId: caseId, document: saved[i]),
                  ],
                  const SizedBox(height: 16),
                ],
                _UploadForm(caseId: caseId),
              ] else ...[
                const SizedBox(height: 12),
                FilledButton(
                  style: secondaryFilledStyle(),
                  onPressed: () =>
                      context.go(AuthRoutes.caseDocumentUpload(caseId)),
                  child: const Text('Add Another'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class DocumentDetailsScreen extends ConsumerWidget {
  const DocumentDetailsScreen({
    super.key,
    required this.caseId,
    required this.documentId,
  });

  final String caseId;
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(claimDocumentsProvider(caseId));
    return ShellPage(
      title: 'Document',
      child: documents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('This document could not be opened.'),
        data: (all) {
          final matches = [
            for (final item in all)
              if (item.id == documentId) item,
          ];
          if (matches.isEmpty) {
            return const Text('This document is not on this claim.');
          }
          return _DetailsForm(caseId: caseId, document: matches.first);
        },
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.caseId, required this.document});

  final String caseId;
  final ClaimDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(
          document.processingStatus == 'needsReview'
              ? AuthRoutes.caseDocumentFacts(caseId, document.id)
              : AuthRoutes.caseDocument(caseId, document.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(document.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                documentTypes[document.documentType] ?? document.documentType,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (document.documentDate != null) ...[
                const SizedBox(height: 2),
                Text(document.documentDate!, style: theme.textTheme.bodyMedium),
              ],
              if (document.pageCount != null) ...[
                const SizedBox(height: 2),
                Text(
                  document.pageCount == 1
                      ? '1 page'
                      : '${document.pageCount} pages',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (documentReadingLabel(
                    document.uploadStatus,
                    document.processingStatus,
                  )
                  case final reading?) ...[
                const SizedBox(height: 2),
                Text(
                  reading,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: document.processingStatus == 'failed'
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadForm extends ConsumerStatefulWidget {
  const _UploadForm({required this.caseId});

  final String caseId;

  @override
  ConsumerState<_UploadForm> createState() => _UploadFormState();
}

class _UploadFormState extends ConsumerState<_UploadForm> {
  String? _error;

  Future<void> _pick() async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That file could not be opened.');
      }
      return;
    }
    if (!mounted || picked.isEmpty) return;
    final file = picked.first;
    final known = file.lengthSync();
    if (known != null && known > maxDocumentBytes) {
      setState(() => _error = 'That file must be under 100 MB.');
      return;
    }
    if (documentContentType(file.name) == null) {
      setState(() => _error = 'Use a PDF, JPEG, or PNG.');
      return;
    }
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That file could not be opened.');
      }
      return;
    }
    if (!mounted) return;
    if (bytes.isEmpty || bytes.length > maxDocumentBytes) {
      setState(() => _error = 'That file must be under 100 MB.');
      return;
    }
    setState(() => _error = null);
    final saved = await showFileUpload(
      context: context,
      fileName: file.name,
      upload: (onProgress) {
        return ref.read(uploadDocumentProvider)(
          caseId: widget.caseId,
          fileName: file.name,
          bytes: bytes,
          documentType: 'other',
          documentDate: null,
          onProgress: onProgress,
        );
      },
    );
    if (!mounted || !saved) return;
    context.go(AuthRoutes.caseDocuments(widget.caseId));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(onPressed: _pick, child: const Text('Choose a file')),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _DetailsForm extends ConsumerStatefulWidget {
  const _DetailsForm({required this.caseId, required this.document});

  final String caseId;
  final ClaimDocument document;

  @override
  ConsumerState<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends ConsumerState<_DetailsForm> {
  late final TextEditingController _date;
  late String _type;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.document.documentType;
    _date = TextEditingController(text: widget.document.documentDate ?? '');
  }

  @override
  void dispose() {
    _date.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final date = _date.text.trim();
    if (date.isNotEmpty && !validIsoDate(date)) {
      setState(() => _error = 'Enter a month, day, and year.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(updateDocumentProvider)(
        documentId: widget.document.id,
        documentType: _type,
        documentDate: date.isEmpty ? null : date,
      );
      if (!mounted) return;
      context.go(AuthRoutes.caseDocuments(widget.caseId));
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(removeDocumentProvider)(
        documentId: widget.document.id,
        storagePath: widget.document.storagePath,
      );
      if (!mounted) return;
      context.go(AuthRoutes.caseDocuments(widget.caseId));
    } catch (_) {
      if (mounted) setState(() => _error = 'That could not be removed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.document.name),
        if (documentReadingLabel(
              widget.document.uploadStatus,
              widget.document.processingStatus,
            )
            case final reading?) ...[
          const SizedBox(height: 8),
          Text(
            reading,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: widget.document.processingStatus == 'failed'
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (widget.document.processingStatus == 'needsReview') ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go(
              AuthRoutes.caseDocumentFacts(widget.caseId, widget.document.id),
            ),
            child: const Text('Review statements'),
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Kind of file'),
          items: [
            for (final entry in documentTypes.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: _busy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _type = value);
                },
        ),
        const SizedBox(height: 12),
        IsoDateField(
          controller: _date,
          label: 'Document date',
          enabled: !_busy,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        FormActions(
          onBack: () => context.go(AuthRoutes.caseDocuments(widget.caseId)),
          onPrimary: _save,
          primaryLabel: 'Save',
          busy: _busy,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            style: dangerTextStyle(),
            onPressed: _busy ? null : _remove,
            child: const Text('Remove'),
          ),
        ),
      ],
    );
  }
}
