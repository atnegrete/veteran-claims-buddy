import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_decision.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_review.dart';
import '../../claim/review_repository.dart';
import '../../claim/va_rules.dart';
import '../../forms/repeatable_entries.dart';
import 'shell_pages.dart';

class FormsScreen extends StatelessWidget {
  const FormsScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return ShellPage(
      title: 'Forms',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EarlierClaimNote(caseId: caseId),
          const Text(
            'Pick a review for an issue the VA already decided. The official form is not filled here.',
          ),
          const SizedBox(height: 12),
          const AppBadge.notFiled(),
          const SizedBox(height: 16),
          for (final path in ReviewPath.values) ...[
            OutlinedButton(
              onPressed: () => context.go(_route(caseId, path)),
              child: Text(reviewTitle(path)),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Intent to file, the initial claim, and the other forms are not open yet.',
          ),
        ],
      ),
    );
  }

  String _route(String caseId, ReviewPath path) {
    return switch (path) {
      ReviewPath.supplemental => AuthRoutes.caseSupplemental(caseId),
      ReviewPath.higherLevel => AuthRoutes.caseHigherLevelReview(caseId),
      ReviewPath.board => AuthRoutes.caseBoard(caseId),
    };
  }
}

class ReviewPathScreen extends ConsumerWidget {
  const ReviewPathScreen({super.key, required this.caseId, required this.path});

  final String caseId;
  final ReviewPath path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(claimReviewsProvider(caseId));
    final candidates = ref.watch(reviewCandidatesProvider(caseId));
    return ShellPage(
      title: reviewTitle(path),
      child: reviews.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('These reviews could not be opened.'),
        data: (drafts) {
          final mine = [
            for (final review in drafts)
              if (review.type == reviewType(path)) review,
          ];
          final taken = {for (final review in drafts) review.decisionIssueId};
          final open = candidates.maybeWhen(
            data: (value) => [
              for (final candidate in value)
                if (!taken.contains(candidate.decisionIssueId)) candidate,
            ],
            orElse: () => const <ReviewCandidate>[],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(reviewExplanation(path)),
              const SizedBox(height: 8),
              const _DecisionReviewsLink(),
              const SizedBox(height: 12),
              const AppBadge.notFiled(),
              const SizedBox(height: 16),
              if (candidates.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (mine.isEmpty && open.isEmpty)
                const Text(
                  'Confirm a decision that denied, deferred, or reduced an issue before starting a review.',
                )
              else
                _ReviewEntries(
                  caseId: caseId,
                  path: path,
                  reviews: mine,
                  issues: open,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewEntries extends StatefulWidget {
  const _ReviewEntries({
    required this.caseId,
    required this.path,
    required this.reviews,
    required this.issues,
  });

  final String caseId;
  final ReviewPath path;
  final List<ClaimReview> reviews;
  final List<ReviewCandidate> issues;

  @override
  State<_ReviewEntries> createState() => _ReviewEntriesState();
}

class _ReviewEntriesState extends State<_ReviewEntries> {
  var _adding = false;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final review in widget.reviews) _ReviewCard(review: review),
    ];
    if (widget.issues.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            cards[i],
          ],
        ],
      );
    }
    return RepeatableEntries(
      entries: cards,
      form: _ReviewForm(
        caseId: widget.caseId,
        path: widget.path,
        issues: widget.issues,
      ),
      addingAnother: _adding,
      onAddAnother: () => setState(() => _adding = true),
      onCancel: () => setState(() => _adding = false),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.review});

  final ClaimReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EntryCard(
      onRemove: () => _discard(context, ref),
      fields: [
        EntryField(label: 'Issue', value: review.displayName),
        EntryField(label: 'Form', value: review.formId),
        if (review.boardDocket != null)
          EntryField(
            label: 'Board docket',
            value: boardDockets[review.boardDocket] ?? review.boardDocket!,
          ),
        if (review.informalConference != null)
          EntryField(
            label: 'Informal conference',
            value: review.informalConference! ? 'Yes' : 'No',
          ),
      ],
    );
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    try {
      await ref
          .read(reviewRepositoryProvider)
          .discard(uid: uid, reviewId: review.id);
    } on ClaimGuideFailure catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({
    required this.caseId,
    required this.path,
    required this.issues,
  });

  final String caseId;
  final ReviewPath path;
  final List<ReviewCandidate> issues;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  String? _issueId;
  String _docket = 'direct';
  var _conference = false;
  var _busy = false;
  String? _error;

  ReviewCandidate? get _issue {
    for (final issue in widget.issues) {
      if (issue.decisionIssueId == _issueId) return issue;
    }
    return widget.issues.length == 1 ? widget.issues.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final issue = _issue;
    final selectedId = issue?.decisionIssueId;
    final deadline = issue == null
        ? ''
        : oneYearAfterDecision(issue.decisionDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('issue-$selectedId-${widget.issues.length}'),
          initialValue: selectedId,
          decoration: const InputDecoration(labelText: 'Issue'),
          items: [
            for (final item in widget.issues)
              DropdownMenuItem(
                value: item.decisionIssueId,
                child: Text(item.displayName),
              ),
          ],
          onChanged: _busy ? null : (value) => setState(() => _issueId = value),
        ),
        if (issue != null && deadline.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'The decision date is ${issue.decisionDate}. ${reviewWindowPhrase()} after that is $deadline.',
          ),
        ],
        if (widget.path == ReviewPath.board) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('docket-$_docket'),
            initialValue: _docket,
            decoration: const InputDecoration(labelText: 'Board docket'),
            items: [
              for (final entry in boardDockets.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _docket = value);
                  },
          ),
        ],
        if (widget.path == ReviewPath.higherLevel)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _conference,
            onChanged: _busy
                ? null
                : (value) => setState(() => _conference = value ?? false),
            title: const Text('Ask for an informal conference'),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          style: secondaryFilledStyle(),
          onPressed: _busy ? null : _start,
          child: Text(_busy ? 'Saving…' : 'Start this review'),
        ),
      ],
    );
  }

  Future<void> _start() async {
    final uid = ref.read(authControllerProvider).session?.uid;
    final issue = _issue;
    if (uid == null || issue == null) {
      setState(() => _error = 'Choose an issue from a confirmed decision.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(reviewRepositoryProvider)
          .start(
            uid: uid,
            caseId: widget.caseId,
            path: widget.path,
            issue: issue,
            boardDocket: widget.path == ReviewPath.board ? _docket : null,
            informalConference: widget.path == ReviewPath.higherLevel
                ? _conference
                : null,
          );
      if (!mounted) return;
      setState(() => _busy = false);
    } on ClaimGuideFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'That review could not be started.';
      });
    }
  }
}

class _DecisionReviewsLink extends StatelessWidget {
  const _DecisionReviewsLink();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () async {
          final opened = await launchUrl(
            Uri.parse(vaDecisionReviewsUrl),
            mode: LaunchMode.externalApplication,
          );
          if (opened || !context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That page could not be opened.')),
          );
        },
        child: const Text('VA decision reviews'),
      ),
    );
  }
}
