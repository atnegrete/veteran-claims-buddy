import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_badge.dart';
import '../../auth/auth_redirect.dart';
import '../../cases/cases_progress.dart';
import '../../claim/claim_document.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_issue.dart';
import '../../claim/claim_issue_repository.dart';
import '../../claim/claim_review.dart';
import '../../claim/document_repository.dart';
import '../../claim/next_action.dart';
import '../../claim/next_action_repository.dart';
import '../../claim/questionnaire_catalog.dart';
import '../../claim/questionnaire_repository.dart';
import '../../claim/review_repository.dart';
import '../../onboarding/onboarding_progress.dart';
import 'shell_pages.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.caseId});

  /// Set when this claim is opened directly. Null while the open claim is still being created.
  final String? caseId;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool? _answer;
  var _editing = false;
  var _busy = false;
  String? _error;
  String? _synced;

  Future<void> _choose(bool firstClaim) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(saveFirstClaimProvider)(firstClaim);
      if (!mounted) return;
      setState(() {
        _answer = firstClaim;
        _editing = false;
      });
      final id = widget.caseId ?? ref.read(workingCaseIdProvider);
      if (firstClaim && id != null) {
        context.go(AuthRoutes.caseQuestions(id));
      }
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref
        .watch(onboardingDocProvider)
        .maybeWhen(data: firstClaimAnswer, orElse: () => null);
    final answer = _editing ? null : (_answer ?? stored);
    final caseId = widget.caseId ?? ref.watch(workingCaseIdProvider);
    final documents = caseId == null
        ? const <ClaimDocument>[]
        : ref
              .watch(claimDocumentsProvider(caseId))
              .maybeWhen(
                data: (value) => value,
                orElse: () => const <ClaimDocument>[],
              );
    final documentCount = documents
        .where((document) => document.uploadStatus == 'uploaded')
        .length;
    final session = ref
        .watch(questionnaireSessionProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => QuestionnaireSession.empty,
        );
    final issues = ref
        .watch(claimIssuesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <ClaimIssue>[]);
    final reviews = caseId == null
        ? const <ReviewCandidate>[]
        : ref
              .watch(reviewCandidatesProvider(caseId))
              .maybeWhen(
                data: (value) => value,
                orElse: () => const <ReviewCandidate>[],
              );
    final drafts = caseId == null
        ? const <ClaimReview>[]
        : ref
              .watch(claimReviewsProvider(caseId))
              .maybeWhen(
                data: (value) => value,
                orElse: () => const <ClaimReview>[],
              );
    final reviewDraftIds = {
      for (final review in drafts) review.decisionIssueId,
    };
    final action = nextActionFor(
      NextActionInput(
        caseId: caseId ?? '',
        firstClaim: answer,
        documents: documents,
        session: session,
        issues: issues,
        reviews: reviews,
        reviewDraftIds: reviewDraftIds,
        reviewDrafts: drafts,
      ),
    );
    if (caseId != null && action.syncKey != _synced) {
      _synced = action.syncKey;
      final save = ref.read(syncNextActionProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        save(action);
      });
    }
    final ensureError = ref.watch(caseEnsureProvider);
    return ShellPage(
      title: 'Your claim',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.caseId != null) EarlierClaimNote(caseId: widget.caseId!),
          if (ensureError != null) ...[
            Text(
              ensureError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.read(caseEnsureProvider.notifier).retry(),
              child: const Text('Try again'),
            ),
            const SizedBox(height: 16),
          ],
          if (answer == null)
            _FirstClaimQuestion(busy: _busy, onChoose: _choose)
          else ...[
            if (!answer)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Add the decision or claim paperwork you want to pursue again. It stays in Documents. You can still add new conditions in Questions.',
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('This is your first VA disability claim.'),
              ),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: AppBadge.notFiled(),
            ),
            if (!answer && documentCount == 0) ...[
              FilledButton(
                onPressed: caseId == null
                    ? null
                    : () => context.go(AuthRoutes.caseDocumentUpload(caseId)),
                child: const Text('Add paperwork'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: caseId == null
                    ? null
                    : () => context.go(AuthRoutes.caseQuestions(caseId)),
                child: const Text('Continue'),
              ),
            ] else ...[
              Text(
                action.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (action.kind == NextActionKind.addIssue ||
                  action.kind == NextActionKind.reviewFile ||
                  action.kind == NextActionKind.decisionReview ||
                  action.kind == NextActionKind.selfSubmit ||
                  action.kind == NextActionKind.formsLater) ...[
                const SizedBox(height: 8),
                Text(action.description),
              ],
              if (action.route != null && action.buttonLabel != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(action.route!),
                  child: Text(action.buttonLabel!),
                ),
              ],
              if (!answer) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: caseId == null
                      ? null
                      : () => context.go(AuthRoutes.caseDocumentUpload(caseId)),
                  child: const Text('Add paperwork'),
                ),
              ],
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (answer != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : () => setState(() => _editing = true),
                child: const Text('Change this answer'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FirstClaimQuestion extends StatelessWidget {
  const _FirstClaimQuestion({required this.busy, required this.onChoose});

  final bool busy;
  final ValueChanged<bool> onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Is this your first VA disability claim?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'A first claim starts with symptoms. An earlier claim starts with that paperwork. You can add new conditions either way.',
        ),
        const SizedBox(height: 12),
        const AppBadge.notFiled(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : () => onChoose(true),
          child: Text(busy ? 'Saving…' : 'Yes, this is my first claim'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy ? null : () => onChoose(false),
          child: const Text('No, I have an earlier claim'),
        ),
      ],
    );
  }
}
