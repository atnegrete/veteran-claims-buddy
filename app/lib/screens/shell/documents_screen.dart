import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_document.dart';
import '../../claim/claim_file_sections.dart';
import '../../claim/claim_guide.dart';
import '../../claim/document_repository.dart';
import '../../claim/form_recommendations.dart';
import '../../claim/issue_lane.dart';
import '../../forms/claim_file_section.dart';
import '../../forms/form_actions.dart';
import '../../forms/iso_date_field.dart';
import '../../onboarding/onboarding_progress.dart';
import 'shell_pages.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(claimDocumentsProvider(caseId));
    final earlierClaim = ref
        .watch(onboardingDocProvider)
        .maybeWhen(
          data: (value) => firstClaimAnswer(value) == false,
          orElse: () => false,
        );
    return ShellPage(
      title: 'My Uploads',
      child: documents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('These files could not be opened.'),
        data: (all) {
          final saved = [
            for (final document in all)
              if (document.caseId == caseId) document,
          ];
          final lanes = ref.watch(claimLanesProvider(caseId));
          final sections = claimFileSections(
            earlierClaim: earlierClaim,
            lanes: lanes,
            documents: saved,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EarlierClaimNote(caseId: caseId),
              const LeadText('Files you add for this claim stay here.'),
              const SizedBox(height: 16),
              for (final section in sections)
                ClaimFileSection(
                  caseId: caseId,
                  packet: section.packet,
                  note: section.note,
                  showDropTarget: section.showDropTarget,
                  sectionAcceptsEvidence: _sectionAccepts(section, lanes),
                ),
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

bool _sectionAccepts(
  ClaimFileSectionSpec section,
  List<IssueLaneResult> lanes,
) {
  final accepts = lanes.any(
    (lane) => lane.packet == section.packet && lane.acceptsEvidence,
  );
  if (section.packet == ClaimPacket.newClaim ||
      section.packet == ClaimPacket.supplemental) {
    return section.showDropTarget || accepts;
  }
  return accepts;
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
  late String _packet;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.document.documentType;
    _packet = widget.document.packet;
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
        packet: _type == 'decisionLetter' || _type == 'dd214'
            ? 'record'
            : _packet,
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
        Text(
          widget.document.name,
          style: Theme.of(context).textTheme.titleLarge,
        ),
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
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Kind of file'),
          items: [
            for (final entry in documentTypes.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _busy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _type = value);
                },
        ),
        if (_type != 'decisionLetter' && _type != 'dd214')
          _PacketChoice(
            caseId: widget.caseId,
            value: _packet,
            enabled: !_busy,
            onChanged: (value) => setState(() => _packet = value),
          ),
        const SizedBox(height: 12),
        IsoDateField(
          controller: _date,
          label: 'Document date',
          enabled: !_busy,
        ),
        if (_error != null) ...[const SizedBox(height: 12), ErrorText(_error!)],
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

class _PacketChoice extends ConsumerWidget {
  const _PacketChoice({
    required this.caseId,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String caseId;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accepting = evidencePackets(ref.watch(claimLanesProvider(caseId)));
    if (accepting.length < 2) return const SizedBox.shrink();
    final names = {
      for (final packet in accepting) claimPacketNames[packet]!,
      'shared',
    };
    final current = names.contains(value)
        ? value
        : claimPacketNames[accepting.first]!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey(current),
        initialValue: current,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Which filing'),
        items: [
          for (final packet in accepting)
            DropdownMenuItem(
              value: claimPacketNames[packet],
              child: Text(
                claimPacketLabels[packet]!,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const DropdownMenuItem(
            value: 'shared',
            child: Text('Both', overflow: TextOverflow.ellipsis),
          ),
        ],
        onChanged: enabled
            ? (next) {
                if (next != null) onChanged(next);
              }
            : null,
      ),
    );
  }
}
