import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_decision.dart';
import '../../claim/claim_document.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_issue.dart';
import '../../claim/va_rules.dart';
import '../../claim/claim_issue_repository.dart';
import '../../claim/decision_repository.dart';
import '../../claim/document_repository.dart';
import '../../cases/case_outcome.dart';
import '../../cases/cases_progress.dart';
import '../../cases/cases_repository.dart';
import '../../forms/file_upload.dart';
import '../../forms/form_actions.dart';
import '../../forms/iso_date_field.dart';
import '../../forms/text_input_chain.dart';
import 'shell_pages.dart';

/// The choice offered after a decision letter is confirmed.
enum _NextStep { later, appeal, complete }

class DecisionsScreen extends ConsumerWidget {
  const DecisionsScreen({super.key, required this.caseId, this.adding = false});

  final String caseId;
  final bool adding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisions = ref.watch(claimDecisionsProvider(caseId));
    final documents = ref.watch(claimDocumentsProvider(caseId));
    return ShellPage(
      title: 'Decisions',
      child: decisions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('These decisions could not be opened.'),
        data: (saved) {
          final letters = documents.maybeWhen(
            data: (all) => [
              for (final document in all)
                if (document.documentType == 'decisionLetter') document,
            ],
            orElse: () => const <ClaimDocument>[],
          );
          final covered = {
            for (final decision in saved)
              if (decision.sourceDocumentId != null) decision.sourceDocumentId,
          };
          final pending = [
            for (final letter in letters)
              if (!covered.contains(letter.id)) letter,
          ];
          final showForm = adding || (saved.isEmpty && pending.isEmpty);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EarlierClaimNote(caseId: caseId),
              const LeadText(
                'Upload the VA decision letter. It stays off the claim until you confirm what it says.',
              ),
              const SizedBox(height: 16),
              for (final letter in pending) ...[
                _PendingLetter(letter: letter),
                const SizedBox(height: 12),
              ],
              for (final decision in saved) ...[
                _DecisionCard(caseId: caseId, decision: decision),
                const SizedBox(height: 12),
              ],
              if (showForm)
                _LetterUpload(caseId: caseId)
              else
                FilledButton(
                  style: secondaryFilledStyle(),
                  onPressed: () =>
                      context.go(AuthRoutes.caseDecisionUpload(caseId)),
                  child: const Text('Add Another'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class DecisionReviewScreen extends ConsumerWidget {
  const DecisionReviewScreen({
    super.key,
    required this.caseId,
    required this.decisionId,
  });

  final String caseId;
  final String decisionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisions = ref.watch(claimDecisionsProvider(caseId));
    final issues = ref.watch(decisionIssuesProvider(decisionId));
    return ShellPage(
      title: 'Decision',
      child: decisions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('This decision could not be opened.'),
        data: (saved) {
          final matches = [
            for (final decision in saved)
              if (decision.id == decisionId) decision,
          ];
          if (matches.isEmpty) {
            return const Text('This decision is not on this claim.');
          }
          final decision = matches.first;
          if (!decision.needsReview) {
            return _ConfirmedDecision(decision: decision);
          }
          return issues.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('This decision could not be opened.'),
            data: (rows) =>
                _ReviewForm(caseId: caseId, decision: decision, issues: rows),
          );
        },
      ),
    );
  }
}

class _PendingLetter extends StatelessWidget {
  const _PendingLetter({required this.letter});

  final ClaimDocument letter;

  @override
  Widget build(BuildContext context) {
    final label = documentReadingLabel(
      letter.uploadStatus,
      letter.processingStatus,
    );
    final waiting =
        letter.processingStatus == 'needsReview' ||
        letter.processingStatus == 'complete';
    return Text(
      waiting
          ? '${letter.name}. No decision was read from this letter.'
          : '${letter.name}. ${label ?? 'Reading this letter.'}',
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.caseId, required this.decision});

  final String caseId;
  final ClaimDecision decision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = decision.needsReview
        ? () => context.go(AuthRoutes.caseDecision(caseId, decision.id))
        : null;
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(decision.decisionDate, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                decision.needsReview
                    ? 'Confirm what the letter says.'
                    : 'On this claim.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (decision.overallSummary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(decision.overallSummary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmedDecision extends StatelessWidget {
  const _ConfirmedDecision({required this.decision});

  final ClaimDecision decision;

  @override
  Widget build(BuildContext context) {
    final deadline = oneYearAfterDecision(decision.decisionDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          decision.decisionDate,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const LeadText('This reading is on the claim.'),
        if (decision.overallSummary.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(decision.overallSummary),
        ],
        if (deadline.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('${reviewWindowPhrase()} after the decision date is $deadline.'),
        ],
      ],
    );
  }
}

class _LetterUpload extends ConsumerStatefulWidget {
  const _LetterUpload({required this.caseId});

  final String caseId;

  @override
  ConsumerState<_LetterUpload> createState() => _LetterUploadState();
}

class _LetterUploadState extends ConsumerState<_LetterUpload> {
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
      if (mounted) setState(() => _error = 'That file could not be opened.');
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
          documentType: 'decisionLetter',
          documentDate: null,
          onProgress: onProgress,
        );
      },
    );
    if (!mounted || !saved) return;
    context.go(AuthRoutes.caseDecisions(widget.caseId));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LeadText('Choose the decision letter. A PDF, JPEG, or PNG.'),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _pick, child: const Text('Choose a file')),
        if (_error != null) ...[const SizedBox(height: 12), ErrorText(_error!)],
      ],
    );
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({
    required this.caseId,
    required this.decision,
    required this.issues,
  });

  final String caseId;
  final ClaimDecision decision;
  final List<ClaimDecisionIssue> issues;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _IssueEditors {
  _IssueEditors(this.issue)
    : name = TextEditingController(text: issue.displayName),
      effective = TextEditingController(text: issue.effectiveDate ?? ''),
      outcome = letterOutcomes.containsKey(issue.outcome)
          ? issue.outcome
          : 'other',
      rating = issue.ratingPercent ?? -1,
      conditionId = issue.conditionId ?? '';

  final ClaimDecisionIssue issue;
  final TextEditingController name;
  final TextEditingController effective;
  String outcome;
  int rating;
  String conditionId;
  late final List<TextEditingController> findings = [
    for (final finding in issue.findings)
      TextEditingController(text: finding.text),
  ];
  late final List<TextEditingController> reasons = [
    for (final reason in issue.reasons)
      TextEditingController(text: reason.text),
  ];

  void dispose() {
    name.dispose();
    effective.dispose();
    for (final controller in findings) {
      controller.dispose();
    }
    for (final controller in reasons) {
      controller.dispose();
    }
  }
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  late final TextEditingController _date;
  late final TextEditingController _received;
  late final TextEditingController _summary;
  late final List<_IssueEditors> _issues;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = TextEditingController(text: widget.decision.decisionDate);
    _received = TextEditingController(text: widget.decision.receivedDate ?? '');
    _summary = TextEditingController(text: widget.decision.overallSummary);
    _issues = [for (final issue in widget.issues) _IssueEditors(issue)];
  }

  @override
  void dispose() {
    _date.dispose();
    _received.dispose();
    _summary.dispose();
    for (final issue in _issues) {
      issue.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final claimIssues = ref
        .watch(claimIssuesProvider)
        .maybeWhen(
          data: (value) => [
            for (final issue in value)
              if (issue.activeCaseId == widget.caseId) issue,
          ],
          orElse: () => const <ClaimIssue>[],
        );
    final deadline = oneYearAfterDecision(_date.text);
    return TextInputChain(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LeadText(
            'Check this against the letter. It is not on the claim until you confirm it.',
          ),
          const SizedBox(height: 16),
          IsoDateField(
            controller: _date,
            label: 'Decision date',
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          IsoDateField(
            controller: _received,
            label: 'Received date',
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          ChainTextField(
            controller: _summary,
            enabled: !_busy,
            minLines: 3,
            maxLines: 6,
            maxLength: decisionSummaryMax,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Summary'),
          ),
          if (deadline.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${reviewWindowPhrase()} after the decision date is $deadline.',
            ),
          ],
          for (final issue in _issues) ...[
            const SizedBox(height: 20),
            ChainTextField(
              controller: issue.name,
              enabled: !_busy,
              maxLength: decisionNameMax,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Condition'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('${issue.issue.id}-outcome-${issue.outcome}'),
              initialValue: issue.outcome,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Outcome'),
              items: [
                for (final entry in letterOutcomes.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => issue.outcome = value);
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('${issue.issue.id}-rating-${issue.rating}'),
              initialValue: issue.rating,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Rating on that decision',
              ),
              items: [
                const DropdownMenuItem(
                  value: -1,
                  child: Text(
                    'No rating stated',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (var rating = 0; rating <= 100; rating += 10)
                  DropdownMenuItem(value: rating, child: Text('$rating')),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => issue.rating = value ?? -1),
            ),
            const SizedBox(height: 12),
            IsoDateField(
              controller: issue.effective,
              label: 'Effective date',
              enabled: !_busy,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(
                '${issue.issue.id}-link-${issue.conditionId}-${claimIssues.length}',
              ),
              initialValue:
                  claimIssues.any((item) => item.id == issue.conditionId)
                  ? issue.conditionId
                  : '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Condition on this claim',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text(
                    'Not on this claim',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final item in claimIssues)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      item.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => issue.conditionId = value ?? ''),
            ),
            for (var i = 0; i < issue.findings.length; i++) ...[
              const SizedBox(height: 12),
              ChainTextField(
                controller: issue.findings[i],
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                maxLength: decisionFindingMax,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Favorable finding',
                ),
              ),
            ],
            for (var i = 0; i < issue.reasons.length; i++) ...[
              const SizedBox(height: 12),
              Text(
                decisionReasonCategories[issue.issue.reasons[i].category] ??
                    'Other',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              ChainTextField(
                controller: issue.reasons[i],
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                maxLength: decisionReasonMax,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
            for (final item in issue.issue.evidence) ...[
              const SizedBox(height: 8),
              Text('Evidence considered: $item'),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorText(_error!),
          ],
          FormActions(
            onBack: _busy
                ? null
                : () => context.go(AuthRoutes.caseDecisions(widget.caseId)),
            onPrimary: _busy ? null : _confirm,
            primaryLabel: 'Confirm',
            busy: _busy,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              style: dangerTextStyle(),
              onPressed: _busy ? null : _discard,
              child: const Text('Discard this reading'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    final received = _received.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(decisionRepositoryProvider)
          .confirm(
            uid: uid,
            decisionId: widget.decision.id,
            decisionDate: _date.text.trim(),
            receivedDate: received.isEmpty ? null : received,
            summary: _summary.text,
            issues: [
              for (final issue in _issues)
                ConfirmDecisionIssue(
                  id: issue.issue.id,
                  conditionId: issue.conditionId.isEmpty
                      ? null
                      : issue.conditionId,
                  displayName: issue.name.text,
                  outcome: issue.outcome,
                  ratingPercent: issue.rating < 0 ? null : issue.rating,
                  effectiveDate: issue.effective.text.trim().isEmpty
                      ? null
                      : issue.effective.text.trim(),
                  findings: [
                    for (var i = 0; i < issue.findings.length; i++)
                      DecisionFinding(
                        text: issue.findings[i].text,
                        page: issue.issue.findings[i].page,
                      ),
                  ],
                  reasons: [
                    for (var i = 0; i < issue.reasons.length; i++)
                      DecisionReason(
                        text: issue.reasons[i].text,
                        category: issue.issue.reasons[i].category,
                        page: issue.issue.reasons[i].page,
                      ),
                  ],
                  sourceDocumentId: widget.decision.sourceDocumentId,
                ),
            ],
          );
      if (!mounted) return;
      await _promptNext(classifyCaseOutcomes(_issues.map((i) => i.outcome)));
    } on ClaimGuideFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'That decision could not be confirmed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptNext(CaseOutcomeClass verdict) async {
    if (verdict.pending) {
      context.go(AuthRoutes.caseDecisions(widget.caseId));
      return;
    }
    final action = await showDialog<_NextStep>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('What happens with this claim?'),
        content: Text(
          verdict.appealEligible
              ? 'You can appeal this decision and keep the claim open, or mark it complete. A completed claim stays available to view and download.'
              : 'You can mark this claim complete. It stays available to view and download.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _NextStep.later),
            child: const Text('Later'),
          ),
          if (verdict.appealEligible)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, _NextStep.appeal),
              child: const Text('Appeal'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _NextStep.complete),
            child: const Text('Mark complete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _NextStep.appeal:
        await _runLifecycle(
          ref.read(appealCaseProvider),
          AuthRoutes.casePrepare(widget.caseId),
        );
      case _NextStep.complete:
        await _runLifecycle(
          ref.read(completeCaseProvider),
          AuthRoutes.caseStep(widget.caseId),
        );
      case _NextStep.later:
      case null:
        context.go(AuthRoutes.caseDecisions(widget.caseId));
    }
  }

  Future<void> _runLifecycle(
    Future<void> Function(String) action,
    String destination,
  ) async {
    try {
      await action(widget.caseId);
      if (!mounted) return;
      context.go(destination);
    } on CaseFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      context.go(AuthRoutes.caseDecisions(widget.caseId));
    }
  }

  Future<void> _discard() async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(decisionRepositoryProvider)
          .discard(
            uid: uid,
            decisionId: widget.decision.id,
            issueIds: [for (final issue in _issues) issue.issue.id],
          );
      if (!mounted) return;
      context.go(AuthRoutes.caseDecisions(widget.caseId));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'That reading could not be discarded.';
      });
    }
  }
}
