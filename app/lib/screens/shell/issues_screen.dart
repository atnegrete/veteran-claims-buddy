import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_issue.dart';
import '../../claim/claim_issue_repository.dart';
import '../../claim/claim_sections.dart';
import '../../claim/discovery_questions.dart';
import '../../claim/form_recommendations.dart';
import '../../claim/issue_lane.dart';
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
      title: 'Conditions',
      child: issues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('These conditions could not be opened.'),
        data: (all) {
          final mine = [
            for (final issue in all)
              if (issue.activeCaseId == caseId) issue,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EarlierClaimNote(caseId: caseId),
              const LeadText('The conditions on this claim.'),
              const SizedBox(height: 12),
              if (mine.isEmpty)
                const LeadText(
                  'Nothing has been added yet. Add possible conditions from the questions.',
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
        title: 'Condition',
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
        title: 'Condition',
        child: Text('This condition could not be opened.'),
      ),
      data: (all) {
        final issue = findClaimIssue(all, caseId, issueId);
        if (issue == null) {
          return ShellPage(
            title: 'Condition',
            maxWidth: double.infinity,
            expandChild: true,
            wrapInCard: false,
            child: NestedSplit(
              open: false,
              master: const Center(
                child: Text('This condition is not on this claim.'),
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
          child: _ResumeCondition(
            caseId: caseId,
            issue: issue,
            child: _IssueMenu(
              caseId: caseId,
              issue: issue,
              panel: panel,
              detail: child,
            ),
          ),
        );
      },
    );
  }
}

/// Opens the first part that is not filled in. A finished condition opens
/// on its last open part.
class _ResumeCondition extends ConsumerStatefulWidget {
  const _ResumeCondition({
    required this.caseId,
    required this.issue,
    required this.child,
  });

  final String caseId;
  final ClaimIssue issue;
  final Widget child;

  @override
  ConsumerState<_ResumeCondition> createState() => _ResumeConditionState();
}

class _ResumeConditionState extends ConsumerState<_ResumeCondition> {
  var _sent = false;

  @override
  Widget build(BuildContext context) {
    final panel = issuePanelFromPath(
      GoRouterState.of(context).uri.path,
      widget.issue.id,
    );
    if (panel != null) return widget.child;
    final target = _firstUnfinished();
    if (target != null && !_sent) {
      _sent = true;
      final caseId = widget.caseId;
      final issueId = widget.issue.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = issuePanelFromPath(
          GoRouterState.of(context).uri.path,
          issueId,
        );
        if (current != null) return;
        context.go(AuthRoutes.caseConditionPanel(caseId, issueId, target));
      });
    }
    return widget.child;
  }

  /// Null while the saved parts are still loading.
  String? _firstUnfinished() {
    final session = ref.watch(questionnaireSessionProvider);
    final theories = ref.watch(issueTheoriesProvider(widget.issue.id));
    final lay = ref.watch(issueStatementProvider((widget.issue.id, 'lay')));
    final nexus = ref.watch(nexusLetterStateProvider(widget.issue.id));
    final decisions = ref.watch(issueDecisionsProvider(widget.issue.id));
    final answers = ref.watch(issueLaneAnswersProvider(widget.issue.id));
    final ready = [
      session,
      theories,
      lay,
      nexus,
      decisions,
      answers,
    ].every((value) => value.hasValue || value.hasError);
    if (!ready) return null;
    final laneAnswers = answers.asData?.value ?? LaneAnswers.empty;
    final decisionCount = decisions.asData?.value.length ?? 0;
    final theoryCount = theories.asData?.value.length ?? 0;
    final savedSession = session.asData?.value ?? QuestionnaireSession.empty;
    final lane = _laneFor(
      ref.watch(claimLanesProvider(widget.caseId)),
      widget.issue.id,
    );
    return firstUnfinishedConditionPanel(
      laterClosed: _closedReason(lane, laneAnswers) != null,
      skipDoctor: lane != null && !lane.needsNexus,
      status: {
        'questions': conditionQuestionsFill(
          questions: savedSession.questions,
          answers: savedSession.answers,
          conditionId: widget.issue.id,
        ),
        'decisions': pursueStepStatus(laneAnswers, decisions: decisionCount),
        'connection': theoryCount > 0
            ? ClaimSectionStatus.done
            : ClaimSectionStatus.notStarted,
        'lay': statementSaved(lay.asData?.value)
            ? ClaimSectionStatus.done
            : ClaimSectionStatus.notStarted,
        'doctor': (nexus.asData?.value.interviewComplete ?? false)
            ? ClaimSectionStatus.done
            : ClaimSectionStatus.notStarted,
      },
    );
  }
}

class _IssueMenu extends ConsumerWidget {
  const _IssueMenu({
    required this.caseId,
    required this.issue,
    required this.panel,
    required this.detail,
  });

  final String caseId;
  final ClaimIssue issue;
  final String? panel;
  final Widget detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref
        .watch(questionnaireSessionProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => QuestionnaireSession.empty,
        );
    final theories = ref
        .watch(issueTheoriesProvider(issue.id))
        .maybeWhen(data: (value) => value, orElse: () => const <ClaimTheory>[]);
    final lay = ref
        .watch(issueStatementProvider((issue.id, 'lay')))
        .maybeWhen(data: statementSaved, orElse: () => false);
    final doctor = ref
        .watch(nexusLetterStateProvider(issue.id))
        .maybeWhen(
          data: (value) => value.interviewComplete,
          orElse: () => false,
        );
    final decisions = ref
        .watch(issueDecisionsProvider(issue.id))
        .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final laneAnswers = ref
        .watch(issueLaneAnswersProvider(issue.id))
        .maybeWhen(data: (value) => value, orElse: () => LaneAnswers.empty);
    final pursue = pursueStepStatus(laneAnswers, decisions: decisions);
    final lane = _laneFor(ref.watch(claimLanesProvider(caseId)), issue.id);
    final closed = _closedReason(lane, laneAnswers);
    final questionCounts = topicQuestionCounts(
      questions: session.questions,
      answers: session.answers,
      conditionId: issue.id,
    );
    final questions = topicQuestionsStatus(
      questions: session.questions,
      answers: session.answers,
      conditionId: issue.id,
    );
    final letterSettled =
        doctor || (closed == null && nexusLetterNotNeeded(lane));
    final marks = <String, ProgressMark>{
      'questions': ProgressMark(
        status: questions,
        label: questions == ClaimSectionStatus.inProgress
            ? completionLabel(questionCounts.answered, questionCounts.total)
            : null,
      ),
      'connection': ProgressMark(
        status: theories.isNotEmpty
            ? ClaimSectionStatus.done
            : ClaimSectionStatus.notStarted,
      ),
      'lay': ProgressMark(
        status: lay ? ClaimSectionStatus.done : ClaimSectionStatus.notStarted,
      ),
      'doctor': ProgressMark(
        status: letterSettled
            ? ClaimSectionStatus.done
            : ClaimSectionStatus.notStarted,
      ),
      'decisions': ProgressMark(status: pursue),
    };
    final rows = <_Panel>[
      _Panel(
        id: 'questions',
        title: 'Questions about this',
        shortTitle: 'Questions',
        subtitle: 'The details already asked for this condition.',
        location: AuthRoutes.caseConditionQuestions(caseId, issue.id),
      ),
      _Panel(
        id: 'decisions',
        title: 'New or already decided',
        shortTitle: 'Decision',
        subtitle: 'This chooses the forms prepared for this condition.',
        location: AuthRoutes.caseConditionDecisions(caseId, issue.id),
      ),
      _Panel(
        id: 'connection',
        title: 'How this connects to service',
        shortTitle: 'Connection',
        subtitle:
            closed ??
            'The facts that tie this to service or to another condition.',
        location: AuthRoutes.caseConditionConnection(caseId, issue.id),
        enabled: closed == null,
      ),
      _Panel(
        id: 'lay',
        title: 'How this affects you',
        shortTitle: 'Effects',
        subtitle: closed ?? 'How often it happens, how long it lasts, and what it keeps you from doing. This is not sent from here.',
        location: AuthRoutes.caseConditionLay(caseId, issue.id),
        enabled: closed == null,
      ),
      _Panel(
        id: 'doctor',
        title: 'Nexus Letters',
        shortTitle: 'Nexus letters',
        subtitle: closed ?? 'Two drafts grounded in your facts. Not a finished medical opinion.',
        location: AuthRoutes.caseConditionDoctorDraft(caseId, issue.id),
        enabled: closed == null,
      ),
    ];
    return NestedSplit(
      open: panel != null,
      steps: [
        for (final row in rows)
          NestedStep(
            title: row.title,
            shortTitle: row.shortTitle,
            selected: panel == row.id,
            done: marks[row.id]?.status == ClaimSectionStatus.done,
            enabled: row.enabled,
            onPressed: row.enabled ? () => context.go(row.location) : null,
          ),
      ],
      master: NestedForm(
        expandChild: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EarlierClaimNote(caseId: caseId),
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
                      onTap: row.enabled
                          ? () => context.go(row.location)
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      detail: detail,
    );
  }
}

IssueLaneResult? _laneFor(List<IssueLaneResult> lanes, String issueId) {
  for (final lane in lanes) {
    if (lane.issueId == issueId) return lane;
  }
  return null;
}

/// Why the other cards stay closed, or null when this condition is in a filing.
String? _closedReason(IssueLaneResult? lane, LaneAnswers answers) {
  if (lane?.filing != IssueFiling.leave) return null;
  if (answers.origin == 'new' && !answers.pursue) {
    return 'Not on this claim, so this stays closed.';
  }
  return 'This decision is being left as it is, so this stays closed.';
}

class _Panel {
  const _Panel({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.location,
    this.enabled = true,
  });

  final String id;
  final String title;

  /// The compact label under the step rail circle.
  final String shortTitle;
  final String subtitle;
  final String location;
  final bool enabled;
}

class ConditionReview extends ConsumerStatefulWidget {
  const ConditionReview({
    super.key,
    required this.caseId,
    required this.conditions,
    this.questions = const [],
    this.onOpenQuestions,
  });

  final String? caseId;
  final List<DiscoveryCondition> conditions;
  final List<CatalogQuestion> questions;
  final ValueChanged<DiscoveryCondition>? onOpenQuestions;

  @override
  ConsumerState<ConditionReview> createState() => _ConditionReviewState();
}

class _ConditionReviewState extends ConsumerState<ConditionReview> {
  String? _addingId;
  String? _removingId;
  var _addingAll = false;
  String? _error;

  bool get _locked => _addingAll || _addingId != null || _removingId != null;

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
      final existing = ref
          .read(claimIssuesProvider)
          .maybeWhen(
            data: (value) => value,
            orElse: () => const <ClaimIssue>[],
          );
      for (final issue in existing) {
        if (issue.activeCaseId != caseId) continue;
        if (issue.displayName.trim().toLowerCase() !=
            condition.name.trim().toLowerCase()) {
          continue;
        }
        final decisions = ref
            .read(issueDecisionsProvider(issue.id))
            .maybeWhen(
              data: (value) => value,
              orElse: () => const <RecordedDecision>[],
            );
        final match = matchingClaimIssueId(
          name: condition.name,
          decided: [
            for (final decision in decisions)
              (
                conditionId: issue.id,
                displayName: issue.displayName,
                outcome: decision.outcome,
              ),
          ],
        );
        if (match != null) {
          if (mounted) context.go(AuthRoutes.caseCondition(caseId, match));
          return;
        }
      }
      await _place(condition, caseId);
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

  Future<void> _addAll(List<DiscoveryCondition> pending) async {
    final caseId = widget.caseId;
    if (caseId == null) {
      setState(() => _error = 'The claim is still opening. Try again.');
      return;
    }
    setState(() {
      _addingAll = true;
      _error = null;
    });
    try {
      for (final condition in pending) {
        await _place(condition, caseId);
      }
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Those could not be added. Try again.');
      }
    } finally {
      if (mounted) setState(() => _addingAll = false);
    }
  }

  Future<void> _place(DiscoveryCondition condition, String caseId) {
    return ref.read(addClaimIssueProvider)(
      caseId: caseId,
      conditionId: condition.id,
      displayName: condition.name,
    );
  }

  Future<void> _remove(DiscoveryCondition condition) async {
    final caseId = widget.caseId;
    if (caseId == null) {
      setState(() => _error = 'The claim is still opening. Try again.');
      return;
    }
    setState(() {
      _removingId = condition.id;
      _error = null;
    });
    try {
      await ref.read(removeClaimIssueProvider)(
        caseId: caseId,
        conditionId: condition.id,
      );
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That could not be removed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _removingId = null);
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
    final pending = [
      for (final condition in conditions)
        if (!claimed.contains(condition.id)) condition,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LeadText(
          conditions.isEmpty ? 'No symptoms were added.' : 'Based on your answers, these conditions can likely be added to this claim.',
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 12),
          FilledButton(
            style: secondaryFilledStyle(),
            onPressed: _locked ? null : () => _addAll(pending),
            child: Text(_addingAll ? 'Adding…' : 'Add all to this claim'),
          ),
        ],
        for (final condition in conditions) ...[
          const SizedBox(height: 12),
          _ReviewCard(
            name: condition.name,
            claimed: claimed.contains(condition.id),
            busy: _addingId == condition.id,
            onAdd: _locked ? null : () => _add(condition),
            onRemove: _locked ? null : () => _remove(condition),
            onQuestions:
                widget.onOpenQuestions == null ||
                    catalogPageIdForCondition(widget.questions, condition.id) ==
                        null
                ? null
                : () => widget.onOpenQuestions!(condition),
          ),
        ],
        if (_error != null) ...[const SizedBox(height: 12), ErrorText(_error!)],
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
    required this.onRemove,
    this.onQuestions,
  });

  final String name;
  final bool claimed;
  final bool busy;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onQuestions;

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
            Row(
              children: [
                Expanded(child: Text(name, style: theme.textTheme.titleMedium)),
                if (onQuestions != null)
                  FilledButton(
                    style: secondaryFilledStyle().merge(
                      FilledButton.styleFrom(minimumSize: const Size(112, 40)),
                    ),
                    onPressed: onQuestions,
                    child: const Text('Questions'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (claimed)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const AppBadge.success(
                    label: 'Added to claim',
                    icon: Icons.check,
                  ),
                  TextButton(
                    style: dangerTextStyle().merge(
                      TextButton.styleFrom(minimumSize: const Size(168, 40)),
                    ),
                    onPressed: onRemove,
                    child: const Text('Remove from claim'),
                  ),
                ],
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
    final session = ref
        .watch(questionnaireSessionProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => QuestionnaireSession.empty,
        );
    final theories = ref
        .watch(issueTheoriesProvider(issue.id))
        .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final lay = ref
        .watch(issueStatementProvider((issue.id, 'lay')))
        .maybeWhen(data: statementSaved, orElse: () => false);
    final doctor = ref
        .watch(nexusLetterStateProvider(issue.id))
        .maybeWhen(
          data: (value) => value.interviewComplete,
          orElse: () => false,
        );
    final decisions = ref
        .watch(issueDecisionsProvider(issue.id))
        .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final laneAnswers = ref
        .watch(issueLaneAnswersProvider(issue.id))
        .maybeWhen(data: (value) => value, orElse: () => LaneAnswers.empty);
    final pursue = pursueStepStatus(laneAnswers, decisions: decisions);
    final lane = ref
        .watch(claimLanesProvider(caseId))
        .where((item) => item.issueId == issue.id);
    final laneResult = lane.isEmpty ? null : lane.first;
    final laterClosed = _closedReason(laneResult, laneAnswers) != null;
    final questions = topicQuestionsStatus(
      questions: session.questions,
      answers: session.answers,
      conditionId: issue.id,
    );
    final progress = conditionPartProgress(
      questions: questions,
      decisions: pursue,
      connectionSaved: theories > 0,
      laySaved: lay,
      doctorComplete: doctor || nexusLetterNotNeeded(laneResult),
      laterClosed: laterClosed,
    );
    final laneLabel = laneResult?.label ?? '';
    return AppNavRow(
      title: issue.displayName,
      subtitle: laneLabel.isEmpty ? null : laneLabel,
      showChevron: false,
      trailing: ProgressMark(
        status: progress.status,
        label: completionLabel(progress.completed, progress.total),
      ),
      onTap: () => context.go(AuthRoutes.caseCondition(caseId, issue.id)),
    );
  }
}
