import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../forms/text_input_chain.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_issue.dart';
import '../../claim/issue_progress.dart';
import '../../claim/claim_issue_repository.dart';
import '../../claim/issue_record_repository.dart';
import '../../claim/questionnaire_catalog.dart';
import '../../claim/questionnaire_repository.dart';
import '../../forms/form_actions.dart';
import '../../forms/iso_date_field.dart';
import '../../forms/nested_split.dart';
import '../../forms/repeatable_entries.dart';
import 'questions_screen.dart';

class IssueQuestionsScreen extends ConsumerWidget {
  const IssueQuestionsScreen({
    super.key,
    required this.caseId,
    required this.issueId,
  });

  final String caseId;
  final String issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(claimIssuesProvider);
    final session = ref.watch(questionnaireSessionProvider);
    return issues.when(
      loading: () => const NestedForm(
        expandChild: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const NestedForm(
        title: 'Questions about this',
        child: Text('This issue could not be opened.'),
      ),
      data: (all) {
        final issue = findClaimIssue(all, caseId, issueId);
        if (issue == null) {
          return const NestedForm(
            title: 'Questions about this',
            child: Text('This issue is not on this claim.'),
          );
        }
        return session.when(
          loading: () => const NestedForm(
            expandChild: true,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const NestedForm(
            title: 'Questions about this',
            child: Text('Those questions could not be opened.'),
          ),
          data: (value) {
            final pageId = catalogPageIdForCondition(value.questions, issue.id);
            if (pageId == null || value.questions.isEmpty) {
              return NestedForm(
                title: 'Questions about this',
                footer: FormActions(
                  onBack: () =>
                      context.go(AuthRoutes.caseIssue(caseId, issue.id)),
                ),
                child: const Text(
                  'These questions are not in the current list.',
                ),
              );
            }
            return NestedForm(
              expandChild: true,
              child: CatalogPanel(
                caseId: caseId,
                onlyPageId: pageId,
                onLeave: () =>
                    context.go(AuthRoutes.caseIssue(caseId, issue.id)),
              ),
            );
          },
        );
      },
    );
  }
}

class IssueEvidenceScreen extends ConsumerWidget {
  const IssueEvidenceScreen({
    super.key,
    required this.caseId,
    required this.issueId,
  });

  final String caseId;
  final String issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(claimIssuesProvider);
    final links = ref.watch(issueLinksProvider(issueId));
    return issues.when(
      loading: () => const NestedForm(
        expandChild: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const NestedForm(
        title: 'What this still needs',
        child: Text('This issue could not be opened.'),
      ),
      data: (all) {
        final issue = findClaimIssue(all, caseId, issueId);
        if (issue == null) {
          return const NestedForm(
            title: 'What this still needs',
            child: Text('This issue is not on this claim.'),
          );
        }
        final saved = links.maybeWhen(
          data: (value) => value,
          orElse: () => const <EvidenceLink>[],
        );
        final progress = evidenceProgress(saved);
        final stillOpen = progress.openLabels.isEmpty
            ? 'Each of those pieces has a note.'
            : 'Still open: ${progress.openLabels.join(', ')}.';
        return NestedForm(
          title: 'What this still needs',
          intro: 'A direct claim usually needs a current disability, something that happened in service, a relationship between them, how bad it is now, and how it affects daily life. Add a note in your own words for any you have. This is not a score.',
          notice: const AppBadge.notFiled(),
          footer: FormActions(
            onBack: () => context.go(AuthRoutes.caseIssue(caseId, issue.id)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                stillOpen,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _LinkForm(issueId: issue.id, links: saved),
            ],
          ),
        );
      },
    );
  }
}

class IssueConnectionScreen extends ConsumerWidget {
  const IssueConnectionScreen({
    super.key,
    required this.caseId,
    required this.issueId,
  });

  final String caseId;
  final String issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(claimIssuesProvider);
    final theories = ref.watch(issueTheoriesProvider(issueId));
    return issues.when(
      loading: () => const NestedForm(
        expandChild: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const NestedForm(
        title: 'How this may be connected',
        child: Text('This issue could not be opened.'),
      ),
      data: (all) {
        final issue = findClaimIssue(all, caseId, issueId);
        if (issue == null) {
          return const NestedForm(
            title: 'How this may be connected',
            child: Text('This issue is not on this claim.'),
          );
        }
        final others = [
          for (final item in all)
            if (item.activeCaseId == caseId && item.id != issue.id) item,
        ];
        final saved = theories.maybeWhen(
          data: (value) => value,
          orElse: () => const <ClaimTheory>[],
        );
        return NestedForm(
          title: 'How this may be connected',
          intro: 'This is your account of how it may be connected to service. It is not a medical finding.',
          notice: const AppBadge.notFiled(),
          footer: FormActions(
            onBack: () => context.go(AuthRoutes.caseIssue(caseId, issue.id)),
          ),
          child: _TheoryForm(
            issueId: issue.id,
            theories: saved,
            others: others,
          ),
        );
      },
    );
  }
}

class IssueStatementScreen extends ConsumerWidget {
  const IssueStatementScreen({
    super.key,
    required this.caseId,
    required this.issueId,
    required this.kind,
    required this.heading,
    required this.intro,
  });

  final String caseId;
  final String issueId;
  final String kind;
  final String heading;
  final String intro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(claimIssuesProvider);
    final statement = ref.watch(issueStatementProvider((issueId, kind)));
    return issues.when(
      loading: () => const NestedForm(
        expandChild: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => NestedForm(
        title: heading,
        child: const Text('This issue could not be opened.'),
      ),
      data: (all) {
        final issue = findClaimIssue(all, caseId, issueId);
        if (issue == null) {
          return NestedForm(
            title: heading,
            child: const Text('This issue is not on this claim.'),
          );
        }
        if (statement.isLoading) {
          return const NestedForm(
            expandChild: true,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (statement.hasError) {
          return NestedForm(
            title: heading,
            child: const Text('This statement could not be opened.'),
          );
        }
        return _StatementForm(
          key: ValueKey('${issue.id}-$kind'),
          caseId: caseId,
          issueId: issue.id,
          kind: kind,
          heading: heading,
          intro: intro,
          saved: statement.value,
        );
      },
    );
  }
}

class IssueDecisionsScreen extends ConsumerWidget {
  const IssueDecisionsScreen({
    super.key,
    required this.caseId,
    required this.issueId,
  });

  final String caseId;
  final String issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(claimIssuesProvider);
    final decisions = ref.watch(issueDecisionsProvider(issueId));
    return issues.when(
      loading: () => const NestedForm(
        expandChild: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const NestedForm(
        title: 'A decision you already received',
        child: Text('This issue could not be opened.'),
      ),
      data: (all) {
        final issue = findClaimIssue(all, caseId, issueId);
        if (issue == null) {
          return const NestedForm(
            title: 'A decision you already received',
            child: Text('This issue is not on this claim.'),
          );
        }
        final saved = decisions.maybeWhen(
          data: (value) => value,
          orElse: () => const <RecordedDecision>[],
        );
        return NestedForm(
          title: 'A decision you already received',
          intro: 'Record a decision you already received. This does not file a claim or predict an outcome.',
          notice: const AppBadge.notFiled(),
          footer: FormActions(
            onBack: () => context.go(AuthRoutes.caseIssue(caseId, issue.id)),
          ),
          child: _DecisionForm(caseId: caseId, issue: issue, decisions: saved),
        );
      },
    );
  }
}

class _LinkForm extends ConsumerStatefulWidget {
  const _LinkForm({required this.issueId, required this.links});

  final String issueId;
  final List<EvidenceLink> links;

  @override
  ConsumerState<_LinkForm> createState() => _LinkFormState();
}

class _LinkFormState extends ConsumerState<_LinkForm> {
  final _summary = TextEditingController();
  String? _type;
  String? _relationship;
  var _adding = false;
  var _busy = false;
  var _formKey = 0;
  String? _error;

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final type = _type;
    final relationship = _relationship;
    final summary = _summary.text.trim();
    if (type == null || relationship == null || summary.isEmpty) {
      setState(
        () => _error = 'Choose what this note is about and add a short note.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(saveEvidenceLinkProvider)(
        issueId: widget.issueId,
        evidenceType: type,
        relationship: relationship,
        summary: summary,
      );
      if (!mounted) return;
      setState(() {
        _adding = false;
        _type = null;
        _relationship = null;
        _summary.clear();
        _formKey++;
      });
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That note could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String id) async {
    try {
      await ref.read(removeEvidenceLinkProvider)(linkId: id);
    } catch (_) {
      if (mounted) setState(() => _error = 'That note could not be removed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = {
      for (final row in directEvidenceMatrix) row.type: row.label,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepeatableEntries(
          entries: [
            for (final link in widget.links)
              EntryCard(
                onRemove: _busy ? null : () => _remove(link.id),
                fields: [
                  EntryField(
                    label: 'About',
                    value: labels[link.evidenceType] ?? link.evidenceType,
                  ),
                  EntryField(
                    label: 'Relationship',
                    value:
                        evidenceRelationships[link.relationship] ??
                        link.relationship,
                  ),
                  EntryField(label: 'Note', value: link.summary),
                ],
              ),
          ],
          addingAnother: _adding,
          onAddAnother: _busy ? null : () => setState(() => _adding = true),
          onCancel: () => setState(() {
            _adding = false;
            _error = null;
          }),
          form: Column(
            key: ValueKey(_formKey),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'About'),
                items: [
                  for (final row in directEvidenceMatrix)
                    DropdownMenuItem(value: row.type, child: Text(row.label)),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _type = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                decoration: const InputDecoration(labelText: 'Relationship'),
                items: [
                  for (final entry in evidenceRelationships.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _relationship = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _summary,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: secondaryFilledStyle(),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
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

class _TheoryForm extends ConsumerStatefulWidget {
  const _TheoryForm({
    required this.issueId,
    required this.theories,
    required this.others,
  });

  final String issueId;
  final List<ClaimTheory> theories;
  final List<ClaimIssue> others;

  @override
  ConsumerState<_TheoryForm> createState() => _TheoryFormState();
}

class _TheoryFormState extends ConsumerState<_TheoryForm> {
  final _summary = TextEditingController();
  String? _type;
  String? _relatedId;
  var _adding = false;
  var _busy = false;
  var _formKey = 0;
  String? _error;

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final type = _type;
    final summary = _summary.text.trim();
    if (type == null || summary.isEmpty) {
      setState(() => _error = 'Choose how it may be connected and add a note.');
      return;
    }
    if (type == 'secondary' && (_relatedId == null || widget.others.isEmpty)) {
      setState(() => _error = 'Add the other condition to this claim first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(saveTheoryProvider)(
        issueId: widget.issueId,
        type: type,
        summary: summary,
        relatedClaimIssueId: type == 'secondary' ? _relatedId : null,
      );
      if (!mounted) return;
      setState(() {
        _adding = false;
        _type = null;
        _relatedId = null;
        _summary.clear();
        _formKey++;
      });
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String id) async {
    try {
      await ref.read(removeTheoryProvider)(
        issueId: widget.issueId,
        theoryId: id,
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'That could not be removed.');
    }
  }

  String _relatedName(String? id) {
    if (id == null) return '';
    for (final issue in widget.others) {
      if (issue.id == id) return issue.displayName;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepeatableEntries(
          entries: [
            for (final theory in widget.theories)
              EntryCard(
                onRemove: _busy ? null : () => _remove(theory.id),
                fields: [
                  EntryField(
                    label: 'How it may be connected',
                    value: connectionTypes[theory.type] ?? theory.type,
                  ),
                  if (theory.relatedClaimIssueId != null)
                    EntryField(
                      label: 'Other condition',
                      value: _relatedName(theory.relatedClaimIssueId),
                    ),
                  EntryField(label: 'In your own words', value: theory.summary),
                ],
              ),
          ],
          addingAnother: _adding,
          onAddAnother: _busy ? null : () => setState(() => _adding = true),
          onCancel: () => setState(() {
            _adding = false;
            _error = null;
          }),
          form: Column(
            key: ValueKey(_formKey),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'How it may be connected',
                ),
                items: [
                  for (final entry in connectionTypes.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _type = value),
              ),
              if (_type == 'secondary' && widget.others.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _relatedId,
                  decoration: const InputDecoration(
                    labelText: 'Other condition',
                  ),
                  items: [
                    for (final issue in widget.others)
                      DropdownMenuItem(
                        value: issue.id,
                        child: Text(issue.displayName),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _relatedId = value),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _summary,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'In your own words',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: secondaryFilledStyle(),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
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

class _StatementForm extends ConsumerStatefulWidget {
  const _StatementForm({
    super.key,
    required this.caseId,
    required this.issueId,
    required this.kind,
    required this.heading,
    required this.intro,
    required this.saved,
  });

  final String caseId;
  final String issueId;
  final String kind;
  final String heading;
  final String intro;
  final IssueStatement? saved;

  @override
  ConsumerState<_StatementForm> createState() => _StatementFormState();
}

class _StatementFormState extends ConsumerState<_StatementForm> {
  late final TextEditingController _body;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _body = TextEditingController(text: widget.saved?.body ?? '');
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = _body.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (body.isEmpty) {
        if (widget.saved != null) {
          await ref.read(removeStatementProvider)(
            issueId: widget.issueId,
            kind: widget.kind,
          );
        }
        return;
      }
      await ref.read(saveStatementProvider)(
        issueId: widget.issueId,
        kind: widget.kind,
        body: body,
      );
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NestedForm(
      title: widget.heading,
      intro: widget.intro,
      notice: const AppBadge.notFiled(),
      footer: FormActions(
        onBack: () =>
            context.go(AuthRoutes.caseIssue(widget.caseId, widget.issueId)),
        onPrimary: _save,
        primaryLabel: 'Save',
        busy: _busy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _body,
            enabled: !_busy,
            minLines: 6,
            maxLines: 12,
            maxLength: 8000,
            decoration: const InputDecoration(labelText: 'In your own words'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _DecisionForm extends ConsumerStatefulWidget {
  const _DecisionForm({
    required this.caseId,
    required this.issue,
    required this.decisions,
  });

  final String caseId;
  final ClaimIssue issue;
  final List<RecordedDecision> decisions;

  @override
  ConsumerState<_DecisionForm> createState() => _DecisionFormState();
}

class _DecisionFormState extends ConsumerState<_DecisionForm> {
  final _date = TextEditingController();
  final _effective = TextEditingController();
  String? _outcome;
  int _rating = -1;
  var _adding = false;
  var _busy = false;
  var _formKey = 0;
  String? _error;

  @override
  void dispose() {
    _date.dispose();
    _effective.dispose();
    super.dispose();
  }

  bool get _needsRating {
    return _outcome == 'granted' ||
        _outcome == 'increased' ||
        _outcome == 'continued' ||
        _outcome == 'reduced';
  }

  Future<void> _save() async {
    final outcome = _outcome;
    final date = _date.text.trim();
    final effective = _effective.text.trim();
    if (outcome == null || !validIsoDate(date)) {
      setState(() => _error = 'Enter the decision date and the outcome.');
      return;
    }
    if (effective.isNotEmpty && !validIsoDate(effective)) {
      setState(() => _error = 'Enter a month, day, and year.');
      return;
    }
    if (_needsRating && _rating < 0) {
      setState(() => _error = 'Choose the rating on that decision.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(saveDecisionProvider)(
        caseId: widget.caseId,
        issueId: widget.issue.id,
        displayName: widget.issue.displayName,
        decisionDate: date,
        outcome: outcome,
        ratingPercent: _needsRating ? _rating : null,
        effectiveDate: effective.isEmpty ? null : effective,
      );
      if (!mounted) return;
      setState(() {
        _adding = false;
        _outcome = null;
        _rating = -1;
        _date.clear();
        _effective.clear();
        _formKey++;
      });
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That decision could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String id) async {
    try {
      await ref.read(removeDecisionProvider)(decisionId: id);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That decision could not be removed.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepeatableEntries(
          entries: [
            for (final decision in widget.decisions)
              EntryCard(
                onRemove: _busy ? null : () => _remove(decision.id),
                fields: [
                  EntryField(label: 'Date', value: decision.decisionDate),
                  EntryField(
                    label: 'Outcome',
                    value:
                        decisionOutcomes[decision.outcome] ?? decision.outcome,
                  ),
                  if (decision.ratingPercent != null)
                    EntryField(
                      label: 'Rating on that decision',
                      value: '${decision.ratingPercent}',
                    ),
                  if (decision.effectiveDate != null)
                    EntryField(
                      label: 'Effective date',
                      value: decision.effectiveDate!,
                    ),
                ],
              ),
          ],
          addingAnother: _adding,
          onAddAnother: _busy ? null : () => setState(() => _adding = true),
          onCancel: () => setState(() {
            _adding = false;
            _error = null;
          }),
          form: TextInputChain(
            child: Column(
              key: ValueKey(_formKey),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IsoDateField(
                  controller: _date,
                  label: 'Decision date',
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _outcome,
                  decoration: const InputDecoration(labelText: 'Outcome'),
                  items: [
                    for (final entry in decisionOutcomes.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _outcome = value),
                ),
                if (_needsRating) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _rating,
                    decoration: const InputDecoration(
                      labelText: 'Rating on that decision',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('Choose a rating'),
                      ),
                      for (var rating = 0; rating <= 100; rating += 10)
                        DropdownMenuItem(value: rating, child: Text('$rating')),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _rating = value ?? -1),
                  ),
                ],
                const SizedBox(height: 12),
                IsoDateField(
                  controller: _effective,
                  label: 'Effective date',
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: secondaryFilledStyle(),
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          ),
        ),
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
