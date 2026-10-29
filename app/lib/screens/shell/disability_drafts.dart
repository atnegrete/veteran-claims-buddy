import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_issue.dart';
import '../../claim/claim_issue_repository.dart';
import '../../claim/disability_explanation.dart';
import '../../claim/form_preparation.dart';
import '../../claim/issue_record_repository.dart';
import '../../forms/form_questions.dart';
import '../../forms/package_form.dart';
import '../../forms/text_input_chain.dart';

/// The disabilities table on 21-526EZ. Each claimed condition is one row. The
/// name is filled from the issue. The explanation is the saved connection notes,
/// unless the Veteran has reviewed an AI draft for that condition.
class DisabilityDrafts extends ConsumerStatefulWidget {
  const DisabilityDrafts({
    super.key,
    required this.caseId,
    required this.entry,
    required this.onChanged,
  });

  final String caseId;
  final PackageForm entry;

  /// The reviewed drafts currently in the editors, including blanks that clear
  /// a saved draft. Used to refresh the preview before Save.
  final ValueChanged<Map<String, String>> onChanged;

  @override
  ConsumerState<DisabilityDrafts> createState() => _DisabilityDraftsState();
}

class _DisabilityDraftsState extends ConsumerState<DisabilityDrafts> {
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final entry in widget.entry.sectionDrafts.entries) {
      if (entry.value.trim().isEmpty) continue;
      _controllers[entry.key] = TextEditingController(text: entry.value)
        ..addListener(_notify);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _notify() {
    widget.onChanged({
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    });
  }

  void _openDraft(String issueId, String text) {
    final existing = _controllers[issueId];
    if (existing != null) {
      existing.text = text;
      return;
    }
    final controller = TextEditingController(text: text)..addListener(_notify);
    setState(() => _controllers[issueId] = controller);
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final issues = ref.watch(claimIssuesProvider).maybeWhen(
      data: (all) {
        final mine = [
          for (final issue in all)
            if (issue.activeCaseId == widget.caseId &&
                issue.displayName.trim().isNotEmpty)
              issue,
        ];
        mine.sort((a, b) {
          final byName = a.displayName.compareTo(b.displayName);
          if (byName != 0) return byName;
          return a.id.compareTo(b.id);
        });
        return mine;
      },
      orElse: () => const <ClaimIssue>[],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('Conditions being claimed'),
        const SizedBox(height: 8),
        const LeadText(
          'Each condition on this claim is one row. The name comes from the '
          'issue. The explanation comes from how you connected it, unless you '
          'review a draft below.',
        ),
        const SizedBox(height: 12),
        if (issues.isEmpty)
          const InfoNote(
            text:
                'Add a condition on Issues and this section of the form fills from it.',
          )
        else ...[
          if (issues.length > 35)
            const InfoNote(
              text:
                  'The form has room for 35 conditions. The first 35, in name order, are the ones filled in.',
            ),
          if (issues.length > 35) const SizedBox(height: 12),
          for (final issue in issues.take(35)) ...[
            _ConditionDraft(
              caseId: widget.caseId,
              issue: issue,
              controller: _controllers[issue.id],
              onDrafted: (text) => _openDraft(issue.id, text),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }
}

class _ConditionDraft extends ConsumerStatefulWidget {
  const _ConditionDraft({
    required this.caseId,
    required this.issue,
    required this.controller,
    required this.onDrafted,
  });

  final String caseId;
  final ClaimIssue issue;
  final TextEditingController? controller;
  final ValueChanged<String> onDrafted;

  @override
  ConsumerState<_ConditionDraft> createState() => _ConditionDraftState();
}

class _ConditionDraftState extends ConsumerState<_ConditionDraft> {
  var _drafting = false;
  String? _error;

  Future<void> _draft() async {
    setState(() {
      _drafting = true;
      _error = null;
    });
    try {
      final body = await ref
          .read(formPreparationServiceProvider)
          .draftDisabilityExplanation(
            caseId: widget.caseId,
            issueId: widget.issue.id,
          );
      if (!mounted) return;
      widget.onDrafted(body);
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The draft could not be written.');
      }
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theories = ref.watch(issueTheoriesProvider(widget.issue.id)).maybeWhen(
      data: (value) => value,
      orElse: () => const <ClaimTheory>[],
    );
    final links = ref.watch(issueLinksProvider(widget.issue.id)).maybeWhen(
      data: (value) => value,
      orElse: () => const <EvidenceLink>[],
    );
    final assembled = disabilityExplanation(theories: theories, links: links);
    final theme = Theme.of(context);
    final controller = widget.controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.issue.displayName, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (controller == null) ...[
          Text(
            assembled.isEmpty
                ? 'Nothing recorded yet for how this connects to service. The row on the form will name the condition and leave the explanation blank.'
                : assembled,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              style: secondaryFilledStyle(),
              onPressed: assembled.isEmpty || _drafting ? null : _draft,
              child: Text(_drafting ? 'Drafting…' : 'Draft with AI'),
            ),
          ),
        ] else ...[
          ChainTextField(
            controller: controller,
            enabled: !_drafting,
            maxLength: statementBodyMaxLength,
            minLines: 3,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'How this relates to service',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          const LeadText(
            'This draft is for this form. Clearing it and saving uses your saved connection notes again.',
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          ErrorText(_error!),
        ],
      ],
    );
  }
}
