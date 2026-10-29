import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_ui.dart';
import '../../auth/auth_redirect.dart';
import '../../billing/entitlement_service.dart';
import '../../claim/claim_guide.dart';
import '../../claim/form_preparation.dart';
import '../../claim/identifiers_repository.dart';
import '../../forms/form_catalog.dart';
import '../../forms/pdf_preview_pane.dart';
import 'form_download_dialog.dart';

/// The watermarked preview of one package form. Refreshes after [sectionDrafts]
/// changes. The Veteran scrolls to it; there is no second tab.
class FormPdfPreview extends ConsumerStatefulWidget {
  const FormPdfPreview({
    super.key,
    required this.packageFormId,
    required this.sectionDrafts,
    required this.caseId,
    required this.formNumber,
    required this.download,
  });

  final String packageFormId;
  final Map<String, String> sectionDrafts;
  final String caseId;
  final String formNumber;
  final FormDownloadPolicy download;

  @override
  ConsumerState<FormPdfPreview> createState() => _FormPdfPreviewState();
}

class _FormPdfPreviewState extends ConsumerState<FormPdfPreview> {
  Timer? _debounce;
  int _token = 0;
  bool _loading = false;
  Uint8List? _bytes;
  String? _error;
  List<FormPreviewGap> _missing = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didUpdateWidget(FormPdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageFormId != widget.packageFormId ||
        !_sameDrafts(oldWidget.sectionDrafts, widget.sectionDrafts)) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1200), _refresh);
    }
  }

  bool _sameDrafts(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final token = ++_token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(formPreparationServiceProvider)
          .preview(
            packageFormId: widget.packageFormId,
            sectionDrafts: widget.sectionDrafts,
          );
      if (!mounted || token != _token) return;
      setState(() {
        _bytes = result.bytes;
        _missing = result.missing;
        _loading = false;
      });
    } on ClaimGuideFailure catch (error) {
      if (!mounted || token != _token) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _error = 'The preview could not be built.';
        _loading = false;
      });
    }
  }

  String _prefilledName() {
    final identifiers =
        ref.read(identifiersProvider).asData?.value ?? Identifiers.empty;
    if (!identifiers.hasLegalName) return '';
    return [
      identifiers.legalFirstName,
      if (identifiers.legalMiddleName.trim().isNotEmpty)
        identifiers.legalMiddleName.trim(),
      identifiers.legalLastName,
    ].join(' ');
  }

  void _openDownload() {
    final policy = widget.download;
    if (policy.access == FormDownloadAccess.premium) {
      final premium =
          ref.read(premiumStatusProvider).asData?.value ?? PremiumStatus.inactive;
      final unlocks =
          ref.read(caseUnlocksProvider).asData?.value ?? const <String>{};
      final unlocked =
          premium.subscriptionActive || unlocks.contains(widget.caseId);
      if (!unlocked) {
        context.go('${AuthRoutes.plans}?reason=form&caseId=${widget.caseId}');
        return;
      }
    }
    final storedSsn =
        ref.read(identifiersProvider).asData?.value.ssn.trim() ?? '';
    showFormDownloadDialog(
      context: context,
      ref: ref,
      packageFormId: widget.packageFormId,
      formNumber: widget.formNumber,
      policy: policy,
      initialName: _prefilledName(),
      initialSsn: policy.collectSsn ? storedSsn : '',
      sectionDrafts: widget.sectionDrafts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Eyebrow('Preview')),
            if (_loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LeadText(
          widget.download.offered
              ? 'This page is a watermarked preview of your details. Download is where you check the form and save a copy to send. The app does not file it.'
              : 'A preview of the official form with your saved details filled in. '
                  'It is watermarked and is not for filing.',
        ),
        if (widget.download.offered) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _bytes == null || _loading ? null : _openDownload,
            child: const Text('Download form'),
          ),
        ],
        if (_missing.isNotEmpty) ...[
          const SizedBox(height: 12),
          InfoNote(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Still needed', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  _missing.map((gap) => gap.label).join(', '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        PdfPreviewPane(
          bytes: _bytes,
          loading: _loading,
          error: _error,
          onRetry: _refresh,
        ),
      ],
    );
  }
}

/// Development-only list of the raw PDF keys. Never shown in a release build.
class PdfKeyDebug extends ConsumerWidget {
  const PdfKeyDebug({super.key, required this.formNumber});

  final String formNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();
    final mapping = ref.watch(vaFormMappingProvider(formNumber)).asData?.value;
    if (mapping == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('PDF keys (${mapping.fields.length}) — dev only'),
      children: [
        for (final field in mapping.fields)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(field.pdfField, style: theme.textTheme.bodySmall),
                ),
                const SizedBox(width: 8),
                Text(
                  field.source.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
