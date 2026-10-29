import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../claim/claim_decision.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_review.dart';
import '../../claim/form_recommendations.dart';
import '../../claim/form_recommender.dart';
import '../../claim/issue_lane.dart';
import '../../claim/package_form_repository.dart';
import '../../claim/review_repository.dart';
import '../../claim/va_rules.dart';
import '../../forms/package_form.dart';
import '../../forms/repeatable_entries.dart';
import 'forms_workspace.dart';
import 'intent_first_mark.dart';
import 'shell_pages.dart';

const nexusEvidenceNote =
    'A nexus letter is medical evidence, not a VA form. This app does not write or sign it. Your own licensed provider writes and signs it; the app only helps you prepare a draft to bring them.';

/// The Forms page. A deterministic recommender sorts every supported form, and
/// the nexus letter, into the filing that fits and Other Common Forms, using
/// only what the claim already knows. It does not ask the Veteran anything here.
class FormsScreen extends ConsumerWidget {
  const FormsScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(formRecommendationsProvider(caseId));
    final forms = ref
        .watch(packageFormsProvider(caseId))
        .maybeWhen(data: (value) => value, orElse: () => const <PackageForm>[]);

    return ShellPage(
      title: 'Forms',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EarlierClaimNote(caseId: caseId),
          const LeadText(
            'The forms and evidence that fit your claim are recommended. The rest are below. Nothing is automatically filed with the VA at any point.',
          ),
          const SizedBox(height: 12),
          const FilingNote(),
          const SizedBox(height: 20),
          for (final packet in formPacketOrder)
            if (filingFormSuggestions(result, packet).isNotEmpty) ...[
              _PacketForms(
                caseId: caseId,
                packet: packet,
                suggestions: filingFormSuggestions(result, packet),
                forms: forms,
                recommendedHeading:
                    packet == FormPacket.newClaim &&
                    suggestionsForPacket(
                      result,
                      FormPacket.newClaim,
                    ).any((row) => row.track == FormTrack.other),
              ),
              const SizedBox(height: 20),
            ],
          if (otherCommonForms(result).isNotEmpty) ...[
            _SuggestionSection(
              caseId: caseId,
              title: otherCommonFormsTitle,
              empty: '',
              suggestions: otherCommonForms(result),
              forms: forms,
            ),
            const SizedBox(height: 20),
          ],
          const VaFormsCatalogCard(),
        ],
      ),
    );
  }
}

class _PacketForms extends StatelessWidget {
  const _PacketForms({
    required this.caseId,
    required this.packet,
    required this.suggestions,
    required this.forms,
    this.recommendedHeading = false,
  });

  final String caseId;
  final FormPacket packet;
  final List<FormSuggestion> suggestions;
  final List<PackageForm> forms;
  final bool recommendedHeading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(formPacketLabels[packet]!),
        if (packet == FormPacket.higherLevel) ...[
          const SizedBox(height: 8),
          const InfoNote(
            text: 'The VA looks at the evidence it already has. New files are not added on this path.',
          ),
        ],
        if (packet == FormPacket.board) ...[
          const SizedBox(height: 8),
          const InfoNote(
            text: 'Direct review adds no files. The evidence and hearing choices can.',
          ),
        ],
        const SizedBox(height: 12),
        _SuggestionSection(
          caseId: caseId,
          title: recommendedHeading ? 'Recommended for you' : '',
          empty: '',
          suggestions: suggestions,
          forms: forms,
        ),
      ],
    );
  }
}

class _SuggestionSection extends StatelessWidget {
  const _SuggestionSection({
    required this.caseId,
    required this.title,
    required this.empty,
    required this.suggestions,
    required this.forms,
  });

  final String caseId;
  final String title;
  final String empty;
  final List<FormSuggestion> suggestions;
  final List<PackageForm> forms;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty) ...[Eyebrow(title), const SizedBox(height: 12)],
        if (suggestions.isEmpty)
          LeadText(empty)
        else ...[
          for (var i = 0; i < suggestions.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _SuggestionRow(
              caseId: caseId,
              suggestion: suggestions[i],
              added: addedCount(forms, suggestions[i]),
            ),
          ],
        ],
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.caseId,
    required this.suggestion,
    required this.added,
  });

  final String caseId;
  final FormSuggestion suggestion;
  final int added;

  String? _routeFor() => routeForFormSuggestion(caseId, suggestion);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = suggestion.kind == SuggestionKind.evidence
        ? 'Evidence'
        : suggestion.formNumber;
    final reason = formListReason(suggestion, added);
    final subtitle = suggestion.formNumber == '21-0966' || tag == null
        ? reason
        : '$tag — $reason';
    final route = _routeFor();
    final isOpen = route != null;
    final addedLabel = addedCountLabel(added);
    final first = intentFirstRow(suggestion);
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (addedLabel != null) AppBadge.primary(label: addedLabel),
        if (!isOpen) ...[
          if (addedLabel != null) const SizedBox(width: 8),
          Text(
            'Not open yet',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          if (addedLabel != null) const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ],
    );
    final nexus = suggestion.kind == SuggestionKind.evidence;
    return AppNavRow(
      title: suggestion.title,
      subtitle: subtitle,
      showChevron: false,
      leading: first ? const IntentFirstMark() : null,
      accent: first ? AppColors.sand : null,
      trailing: trailing,
      footer: nexus ? const InfoNote(text: nexusEvidenceNote) : null,
      onTap: isOpen ? () => context.go(route) : null,
    );
  }
}

class ReviewPathScreen extends ConsumerWidget {
  const ReviewPathScreen({
    super.key,
    required this.caseId,
    required this.path,
    this.decisionIssueId = '',
  });

  final String caseId;
  final ReviewPath path;
  final String decisionIssueId;

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
          final lanes = ref.watch(claimLanesProvider(caseId));
          final filing = switch (path) {
            ReviewPath.supplemental => IssueFiling.supplemental,
            ReviewPath.higherLevel => IssueFiling.higherLevel,
            ReviewPath.board => IssueFiling.board,
          };
          final allowed = {
            for (final lane in lanes)
              if (lane.filing == filing && lane.decision != null)
                lane.decision!.decisionIssueId,
          };
          final open = candidates.maybeWhen(
            data: (value) => [
              for (final candidate in value)
                if (!taken.contains(candidate.decisionIssueId) &&
                    allowed.contains(candidate.decisionIssueId))
                  candidate,
            ],
            orElse: () => const <ReviewCandidate>[],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LeadText(reviewExplanation(path)),
              const SizedBox(height: 12),
              InfoNote(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Where this goes',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A started review is tracked here and, once generated, lands in your Package. You file it yourself on VA.gov or by mail; this app does not file or sign it.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const FilingNote(),
              const SizedBox(height: 16),
              if (candidates.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (mine.isEmpty && open.isEmpty)
                const LeadText(
                  'Choose this filing on the condition first. A Higher-Level Review or a Board Appeal is only offered while the decision is less than one year old.',
                )
              else
                _ReviewEntries(
                  caseId: caseId,
                  path: path,
                  reviews: mine,
                  issues: open,
                  initialIssueId: decisionIssueId,
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
    this.initialIssueId = '',
  });

  final String caseId;
  final ReviewPath path;
  final List<ClaimReview> reviews;
  final List<ReviewCandidate> issues;
  final String initialIssueId;

  @override
  State<_ReviewEntries> createState() => _ReviewEntriesState();
}

class _ReviewEntriesState extends State<_ReviewEntries> {
  var _adding = false;

  @override
  void initState() {
    super.initState();
    _adding = widget.initialIssueId.isNotEmpty;
  }

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
        initialIssueId: widget.initialIssueId,
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
        EntryField(label: 'Condition', value: review.displayName),
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
    this.initialIssueId = '',
  });

  final String caseId;
  final ReviewPath path;
  final List<ReviewCandidate> issues;
  final String initialIssueId;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  String? _issueId;
  String _docket = 'direct';
  var _conference = false;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialIssueId.isNotEmpty) _issueId = widget.initialIssueId;
  }

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
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Condition'),
          items: [
            for (final item in widget.issues)
              DropdownMenuItem(
                value: item.decisionIssueId,
                child: Text(item.displayName, overflow: TextOverflow.ellipsis),
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
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Board docket'),
            items: [
              for (final entry in boardDockets.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
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
        if (_error != null) ...[const SizedBox(height: 12), ErrorText(_error!)],
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
      setState(() => _error = 'Choose a condition from a confirmed decision.');
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
