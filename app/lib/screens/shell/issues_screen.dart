import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_issue.dart';
import '../../claim/claim_issue_repository.dart';
import '../../claim/claim_sections.dart';
import '../../claim/discovery_questions.dart';
import '../../claim/issue_progress.dart';
import '../../claim/issue_record_repository.dart';
import '../../claim/questionnaire_catalog.dart';
import '../../claim/questionnaire_repository.dart';
import '../../forms/nested_split.dart';
import 'progress_mark.dart';
import 'shell_pages.dart';

class IssuesScreen extends ConsumerWidget {
  const IssuesScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(claimIssuesProvider);
    return ShellPage(
      title: 'Issues',
      child: issues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('These issues could not be opened.'),
        data: (all) {
          final mine = [
            for (final issue in all)
              if (issue.activeCaseId == caseId) issue,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EarlierClaimNote(caseId: caseId),
              const Text('These are the conditions on this claim.'),
              const SizedBox(height: 12),
              const AppBadge.notFiled(),
              const SizedBox(height: 12),
              if (mine.isEmpty)
                const Text(
                  'Nothing has been added yet. Possible conditions can be added from the questions.',
                )
              else
                for (var i = 0; i < mine.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _IssueTile(caseId: caseId, issue: mine[i]),
                ],
            ],
          );
        },
      ),
    );
  }
}

class IssueWorkspace extends ConsumerWidget {
  const IssueWorkspace({
    super.key,
    required this.caseId,
    required this.issueId,
    required this.child,
  });

  final String caseId;
  final String issueId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(claimIssuesProvider);
    final panel = issuePanelFromPath(
      GoRouterState.of(context).uri.path,
      issueId,
    );
    return issues.when(
      loading: () => ShellPage(
        title: 'Issue',
        maxWidth: double.infinity,
        expandChild: true,
        wrapInCard: false,
        child: NestedSplit(
          open: panel != null,
          master: const Center(child: CircularProgressIndicator()),
          detail: child,
        ),
      ),
      error: (_, _) => const ShellPage(
        title: 'Issue',
        child: Text('This issue could not be opened.'),
      ),
      data: (all) {
        final issue = findClaimIssue(all, caseId, issueId);
        if (issue == null) {
          return ShellPage(
            title: 'Issue',
            maxWidth: double.infinity,
            expandChild: true,
            wrapInCard: false,
            child: NestedSplit(
              open: false,
              master: const Center(
                child: Text('This issue is not on this claim.'),
              ),
              detail: child,
            ),
          );
        }
        return ShellPage(
          title: issue.displayName,
          maxWidth: double.infinity,
          expandChild: true,
          wrapInCard: false,
          child: NestedSplit(
            open: panel != null,
            master: _IssueMenu(caseId: caseId, issue: issue, panel: panel),
            detail: child,
          ),
        );
      },
    );
  }
}

class _IssueMenu extends ConsumerWidget {
  const _IssueMenu({
    required this.caseId,
    required this.issue,
    required this.panel,
  });

  final String caseId;
  final ClaimIssue issue;
  final String? panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref
        .watch(questionnaireSessionProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => QuestionnaireSession.empty,
        );
    final links = ref
        .watch(issueLinksProvider(issue.id))
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <EvidenceLink>[],
        );
    final theories = ref
        .watch(issueTheoriesProvider(issue.id))
        .maybeWhen(data: (value) => value, orElse: () => const <ClaimTheory>[]);
    final lay = ref
        .watch(issueStatementProvider((issue.id, 'lay')))
        .maybeWhen(data: statementSaved, orElse: () => false);
    final doctor = ref
        .watch(issueStatementProvider((issue.id, 'doctorDraft')))
        .maybeWhen(data: statementSaved, orElse: () => false);
    final decisions = ref
        .watch(issueDecisionsProvider(issue.id))
        .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final questions = topicQuestionsStatus(
      questions: session.questions,
      answers: session.answers,
      conditionId: issue.id,
    );
    final evidence = evidenceProgress(links);
    final marks = <String, ProgressMark>{
      'questions': ProgressMark(
        status: questions,
        label: questions == ClaimSectionStatus.inProgress
            ? 'In progress'
            : null,
      ),
      'evidence': ProgressMark(
        status: countStatus(evidence.added, complete: evidence.complete),
        label: evidence.complete ? null : addedLabel(evidence.added),
      ),
      'connection': ProgressMark(
        status: countStatus(theories.length),
        label: addedLabel(theories.length),
      ),
      'lay': ProgressMark(
        status: lay ? ClaimSectionStatus.done : ClaimSectionStatus.notStarted,
      ),
      'doctor': ProgressMark(
        status: doctor
            ? ClaimSectionStatus.done
            : ClaimSectionStatus.notStarted,
      ),
      'decisions': ProgressMark(
        status: countStatus(decisions),
        label: addedLabel(decisions),
      ),
    };
    final rows = <_Panel>[
      _Panel(
        id: 'questions',
        title: 'Questions about this',
        subtitle: 'The details already asked for this condition.',
        location: AuthRoutes.caseIssueQuestions(caseId, issue.id),
      ),
      _Panel(
        id: 'evidence',
        title: 'What this still needs',
        subtitle: 'The pieces a direct claim usually needs.',
        location: AuthRoutes.caseIssueEvidence(caseId, issue.id),
      ),
      _Panel(
        id: 'connection',
        title: 'How this may be connected',
        subtitle: 'Your account of it. Not a medical finding.',
        location: AuthRoutes.caseIssueConnection(caseId, issue.id),
      ),
      _Panel(
        id: 'lay',
        title: 'Your statement',
        subtitle: 'In your own words. This is not sent from here.',
        location: AuthRoutes.caseIssueLay(caseId, issue.id),
      ),
      _Panel(
        id: 'doctor',
        title: 'Draft for your doctor',
        subtitle: 'Not a finished medical opinion.',
        location: AuthRoutes.caseIssueDoctorDraft(caseId, issue.id),
      ),
      _Panel(
        id: 'decisions',
        title: 'A decision you already received',
        subtitle: 'Records that decision. It does not predict one.',
        location: AuthRoutes.caseIssueDecisions(caseId, issue.id),
      ),
    ];
    return NestedForm(
      expandChild: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EarlierClaimNote(caseId: caseId),
          const AppBadge.notFiled(),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                for (final row in rows)
                  SelectRow(
                    title: row.title,
                    subtitle: row.subtitle,
                    selected: panel == row.id,
                    trailing: marks[row.id],
                    onTap: () => context.go(row.location),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel {
  const _Panel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.location,
  });

  final String id;
  final String title;
  final String subtitle;
  final String location;
}

class ConditionReview extends ConsumerStatefulWidget {
  const ConditionReview({
    super.key,
    required this.caseId,
    required this.conditions,
    required this.onBack,
  });

  final String? caseId;
  final List<DiscoveryCondition> conditions;
  final VoidCallback? onBack;

  @override
  ConsumerState<ConditionReview> createState() => _ConditionReviewState();
}

class _ConditionReviewState extends ConsumerState<ConditionReview> {
  String? _addingId;
  String? _error;

  Future<void> _add(DiscoveryCondition condition) async {
    final caseId = widget.caseId;
    if (caseId == null) {
      setState(() => _error = 'The claim is still opening. Try again.');
      return;
    }
    setState(() {
      _addingId = condition.id;
      _error = null;
    });
    try {
      await ref.read(addClaimIssueProvider)(
        caseId: caseId,
        conditionId: condition.id,
        displayName: condition.name,
      );
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That could not be added. Try again.');
      }
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conditions = widget.conditions;
    final issues = ref.watch(claimIssuesProvider);
    final claimed = issues.maybeWhen(
      data: (all) => {
        for (final issue in all)
          if (issue.activeCaseId == widget.caseId) issue.conditionId,
      },
      orElse: () => const <String>{},
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          conditions.isEmpty
              ? 'No symptoms were added.'
              : 'These can be added to this claim.',
        ),
        const SizedBox(height: 12),
        const AppBadge.notFiled(),
        for (final condition in conditions) ...[
          const SizedBox(height: 12),
          _ReviewCard(
            name: condition.name,
            claimed: claimed.contains(condition.id),
            busy: _addingId == condition.id,
            onAdd: _addingId == null ? () => _add(condition) : null,
            onOpen: widget.caseId == null
                ? null
                : () => context.go(
                    AuthRoutes.caseIssue(widget.caseId!, condition.id),
                  ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _addingId == null ? widget.onBack : null,
            child: const Text('Back to the questions'),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.name,
    required this.claimed,
    required this.busy,
    required this.onAdd,
    required this.onOpen,
  });

  final String name;
  final bool claimed;
  final bool busy;
  final VoidCallback? onAdd;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (claimed)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onOpen,
                  child: const Text('On this claim'),
                ),
              )
            else
              FilledButton(
                style: secondaryFilledStyle(),
                onPressed: busy ? null : onAdd,
                child: Text(busy ? 'Saving…' : 'Add to this claim'),
              ),
          ],
        ),
      ),
    );
  }
}

class _IssueTile extends ConsumerWidget {
  const _IssueTile({required this.caseId, required this.issue});

  final String caseId;
  final ClaimIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref
        .watch(questionnaireSessionProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => QuestionnaireSession.empty,
        );
    final links = ref
        .watch(issueLinksProvider(issue.id))
        .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final theories = ref
        .watch(issueTheoriesProvider(issue.id))
        .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final lay = ref
        .watch(issueStatementProvider((issue.id, 'lay')))
        .maybeWhen(data: statementSaved, orElse: () => false);
    final doctor = ref
        .watch(issueStatementProvider((issue.id, 'doctorDraft')))
        .maybeWhen(data: statementSaved, orElse: () => false);
    final decisions = ref
        .watch(issueDecisionsProvider(issue.id))
        .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final filled = filledPartCount(
      questions: topicQuestionsStatus(
        questions: session.questions,
        answers: session.answers,
        conditionId: issue.id,
      ),
      evidenceNotes: links,
      connections: theories,
      lay: lay,
      doctorDraft: doctor,
      decisions: decisions,
    );
    final status = filled == 6
        ? ClaimSectionStatus.done
        : filled == 0
        ? ClaimSectionStatus.notStarted
        : ClaimSectionStatus.inProgress;
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AuthRoutes.caseIssue(caseId, issue.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  issue.displayName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              ProgressMark(status: status, label: issueFilledLabel(filled)),
            ],
          ),
        ),
      ),
    );
  }
}
