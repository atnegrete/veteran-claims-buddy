import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../cases/cases_progress.dart';
import '../../claim/claim_document.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_issue.dart';
import '../../claim/claim_issue_repository.dart';
import '../../claim/claim_review.dart';
import '../../claim/document_repository.dart';
import '../../claim/identifiers_repository.dart';
import '../../claim/issue_lane.dart';
import '../../claim/next_action.dart';
import '../../claim/next_action_repository.dart';
import '../../claim/questionnaire_catalog.dart';
import '../../claim/questionnaire_repository.dart';
import '../../claim/review_repository.dart';
import '../../forms/claim_file_section.dart';
import '../../forms/identifier_fields.dart';
import '../../forms/va_file_number_note.dart';
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
  var _busy = false;
  String? _error;
  String? _synced;

  Future<void> _choose(bool firstClaim) async {
    if (firstClaim && _hasSupplementalFiles()) {
      await _showBlockedDialog();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(saveFirstClaimProvider)(firstClaim);
      if (!mounted) return;
      setState(() => _answer = firstClaim);
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

  Future<void> _continue() async {
    final id = widget.caseId ?? ref.read(workingCaseIdProvider);
    if (id == null) return;
    final answer =
        _answer ??
        ref
            .read(onboardingDocProvider)
            .maybeWhen(data: firstClaimAnswer, orElse: () => null);
    if (answer == false && !_hasSupplementalFiles()) {
      final skip = await showDialog<bool>(
        context: context,
        builder: (context) => const _SkipFilesDialog(),
      );
      if (skip != true || !mounted) return;
    }
    if (!mounted) return;
    context.go(AuthRoutes.caseQuestions(id));
  }

  bool _hasSupplementalFiles() {
    final id = widget.caseId ?? ref.read(workingCaseIdProvider);
    if (id == null) return false;
    final documents = ref
        .read(claimDocumentsProvider(id))
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <ClaimDocument>[],
        );
    return documents.any(supportsEarlierClaim);
  }

  Future<void> _showBlockedDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) => const _BlockedSwitchDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref
        .watch(onboardingDocProvider)
        .maybeWhen(data: firstClaimAnswer, orElse: () => null);
    final answer = _answer ?? stored;
    final caseId = widget.caseId ?? ref.watch(workingCaseIdProvider);
    final documents = caseId == null
        ? const <ClaimDocument>[]
        : ref
              .watch(claimDocumentsProvider(caseId))
              .maybeWhen(
                data: (value) => value,
                orElse: () => const <ClaimDocument>[],
              );
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
      title: 'Case Info',
      footer: answer == null
          ? null
          : Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: _busy ? null : _continue,
                child: Text(_busy ? 'Saving…' : 'Continue'),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.caseId != null) EarlierClaimNote(caseId: widget.caseId!),
          if (ensureError != null) ...[
            ErrorText(ensureError),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.read(caseEnsureProvider.notifier).retry(),
              child: const Text('Try again'),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Is this your first VA disability claim?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const LeadText(
            'A first claim starts with your symptoms. A claim you have already filed starts with the VA decision.',
          ),
          const SizedBox(height: 16),
          _ClaimChoices(answer: answer, busy: _busy, onChoose: _choose),
          if (answer != null && caseId != null) ...[
            const SizedBox(height: 16),
            _IntentPrompt(caseId: caseId),
          ],
          if (answer == false) ...[
            const SizedBox(height: 16),
            const _PriorClaimFileNumber(),
            const SizedBox(height: 16),
          ],
          if (answer == false && caseId != null)
            ClaimFileSection(
              caseId: caseId,
              packet: ClaimPacket.supplemental,
              sectionAcceptsEvidence: true,
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorText(_error!),
          ],
        ],
      ),
    );
  }
}

class _PriorClaimFileNumber extends ConsumerStatefulWidget {
  const _PriorClaimFileNumber();

  @override
  ConsumerState<_PriorClaimFileNumber> createState() =>
      _PriorClaimFileNumberState();
}

class _PriorClaimFileNumberState extends ConsumerState<_PriorClaimFileNumber> {
  final _controller = TextEditingController();
  Timer? _timer;
  var _applied = false;
  var _touched = false;
  String? _error;

  static final _valid = RegExp(r'^\d{8,9}$');

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_changed);
    final digits = _controller.text.trim();
    if (_touched && (digits.isEmpty || _valid.hasMatch(digits))) {
      final uid = ref.read(authControllerProvider).session?.uid;
      if (uid != null) {
        final save = ref
            .read(identifiersRepositoryProvider)
            .saveVaFileNumber(uid: uid, vaFileNumber: digits);
        save.then((_) {}, onError: (_) {});
      }
    }
    _controller.dispose();
    super.dispose();
  }

  void _apply(Identifiers value) {
    if (_touched || _applied) return;
    _applied = true;
    final text = value.vaFileNumber;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _touched) return;
      _controller.removeListener(_changed);
      _controller.text = text;
      _controller.addListener(_changed);
    });
  }

  void _changed() {
    _touched = true;
    final digits = _controller.text.trim();
    final invalid = digits.isNotEmpty && !_valid.hasMatch(digits);
    setState(() {
      _error = invalid ? 'A VA file number is 8 or 9 digits.' : null;
    });
    _timer?.cancel();
    if (invalid) return;
    _timer = Timer(const Duration(milliseconds: 400), () => _save(digits));
  }

  Future<void> _save(String digits) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null || !mounted) return;
    try {
      await ref
          .read(identifiersRepositoryProvider)
          .saveVaFileNumber(uid: uid, vaFileNumber: digits);
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That could not be saved. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(identifiersProvider).whenData(_apply);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VaFileNumberNote(),
        VaFileNumberField(controller: _controller, showLabel: false),
        if (_error != null) ...[const SizedBox(height: 8), ErrorText(_error!)],
      ],
    );
  }
}

class _ClaimChoices extends StatelessWidget {
  const _ClaimChoices({
    required this.answer,
    required this.busy,
    required this.onChoose,
  });

  final bool? answer;
  final bool busy;
  final ValueChanged<bool> onChoose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 600;
        final first = _ChoiceCard(
          title: 'Yes, this is my first claim',
          subtitle: 'This claim starts with your symptoms.',
          selected: answer == true,
          onTap: busy ? null : () => onChoose(true),
        );
        final earlier = _ChoiceCard(
          title: 'No, I have an earlier claim',
          subtitle: 'Add the VA decision from a claim you have already filed.',
          selected: answer == false,
          onTap: busy ? null : () => onChoose(false),
        );
        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), earlier],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: earlier),
          ],
        );
      },
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    if (selected) Icon(Icons.check, color: scheme.onSurface),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipFilesDialog extends StatelessWidget {
  const _SkipFilesDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add the earlier decision later?'),
      content: const Text(
        'You have not added the VA decision from that claim. You can add it now, or add it later in My Uploads.',
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(112, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Add later'),
        ),
      ],
    );
  }
}

class _BlockedSwitchDialog extends StatelessWidget {
  const _BlockedSwitchDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Remove the earlier-claim files first'),
      content: const Text(
        'This claim has files for the earlier decision. Delete those files before you mark this as your first VA disability claim. You can remove them here or in My Uploads.',
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(112, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _IntentPrompt extends StatelessWidget {
  const _IntentPrompt({required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoNote(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File an Intent to File before the other forms.',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'If the VA grants your claim, compensation can be paid back to the day they receive VA Form 21-0966. You then have one year to file the complete claim. Preparing it here is free. This app does not send it.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go(AuthRoutes.caseIntent(caseId)),
            child: const Text('Prepare Intent to File'),
          ),
        ],
      ),
    );
  }
}
