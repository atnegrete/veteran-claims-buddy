import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../app/app_tabs.dart';
import '../../app/app_badge.dart';
import '../../ai/ai_chat_input.dart';
import '../../ai/ai_refine_panel.dart';
import '../../forms/pdf_preview_pane.dart';
import '../../forms/text_input_chain.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_issue.dart';
import '../../claim/form_preparation.dart';
import '../../claim/form_recommendations.dart';
import '../../claim/issue_lane.dart';
import '../../claim/issue_progress.dart';
import 'connection_form.dart';
import 'issue_lane_panel.dart';
import '../../claim/claim_issue_repository.dart';
import '../../claim/issue_record_repository.dart';
import '../../claim/questionnaire_catalog.dart';
import '../../claim/questionnaire_repository.dart';
import '../../forms/form_questions.dart';
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
        child: Text('This condition could not be opened.'),
      ),
      data: (all) {
        final issue = findClaimIssue(all, caseId, issueId);
        if (issue == null) {
          return const NestedForm(
            title: 'Questions about this',
            child: Text('This condition is not on this claim.'),
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
                  onBack: () => context.go(AuthRoutes.caseConditions(caseId)),
                  onPrimary: () => context.go(
                    AuthRoutes.caseConditionDecisions(caseId, issue.id),
                  ),
                ),
                child: const LeadText(
                  "These questions aren't in the current list.",
                ),
              );
            }
            return NestedForm(
              expandChild: true,
              child: CatalogPanel(
                caseId: caseId,
                onlyPageId: pageId,
                onLeave: () => context.go(AuthRoutes.caseConditions(caseId)),
                onContinue: () => context.go(
                  AuthRoutes.caseConditionDecisions(caseId, issue.id),
                ),
              ),
            );
          },
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
    final links = ref.watch(issueLinksProvider(issueId));
    return issues.when(
      loading: () => const NestedForm(
        expandChild: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const NestedForm(
        title: 'How this connects to service',
        child: Text('This condition could not be opened.'),
      ),
      data: (all) {
        final issue = findClaimIssue(all, caseId, issueId);
        if (issue == null) {
          return const NestedForm(
            title: 'How this connects to service',
            child: Text('This condition is not on this claim.'),
          );
        }
        final saved = theories.maybeWhen(
          data: (value) => value,
          orElse: () => const <ClaimTheory>[],
        );
        final notes = links.maybeWhen(
          data: (value) => value,
          orElse: () => const <EvidenceLink>[],
        );
        return _ConnectionPage(
          caseId: caseId,
          issueId: issue.id,
          theories: saved,
          links: notes,
        );
      },
    );
  }
}

class _ConnectionPage extends ConsumerStatefulWidget {
  const _ConnectionPage({
    required this.caseId,
    required this.issueId,
    required this.theories,
    required this.links,
  });

  final String caseId;
  final String issueId;
  final List<ClaimTheory> theories;
  final List<EvidenceLink> links;

  @override
  ConsumerState<_ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends ConsumerState<_ConnectionPage> {
  Future<bool> Function()? _commit;
  var _busy = false;

  Future<void> _continue() async {
    setState(() => _busy = true);
    final ok = await _commit?.call() ?? true;
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    context.go(
      AuthRoutes.caseConditionPanel(
        widget.caseId,
        widget.issueId,
        nextConditionPanel('connection', laterClosed: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NestedForm(
      title: 'How this connects to service',
      intro: 'The facts that tie this to service or to another condition. How often it happens and what it limits is the next part.',
      footer: FormActions(
        onBack: () => openPreviousConditionPart(
          context,
          caseId: widget.caseId,
          issueId: widget.issueId,
          panel: 'connection',
        ),
        onPrimary: _continue,
        busy: _busy,
      ),
      child: ConnectionForm(
        issueId: widget.issueId,
        theories: widget.theories,
        links: widget.links,
        onBind: (commit) => _commit = commit,
      ),
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
    return issues.when(
      loading: () => const NestedForm(
        expandChild: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => NestedForm(
        title: heading,
        child: const Text('This condition could not be opened.'),
      ),
      data: (all) {
        final issue = findClaimIssue(all, caseId, issueId);
        if (issue == null) {
          return NestedForm(
            title: heading,
            child: const Text('This condition is not on this claim.'),
          );
        }
        if (kind == 'doctorDraft') {
          final lanes = ref.watch(claimLanesProvider(caseId));
          IssueLaneResult? lane;
          for (final item in lanes) {
            if (item.issueId == issue.id) lane = item;
          }
          if (lane != null && !lane.needsNexus) {
            return NestedForm(
              title: heading,
              intro: intro,
              footer: FormActions(
                onBack: () => openPreviousConditionPart(
                  context,
                  caseId: caseId,
                  issueId: issue.id,
                  panel: 'doctor',
                ),
                onPrimary: () => context.go(
                  AuthRoutes.caseConditionPanel(caseId, issue.id, null),
                ),
              ),
              child: InfoNote(
                text: '${lane.label}. A nexus letter is not prepared for this.',
              ),
            );
          }
          final nexusKind = (lane != null && lane.nexusKind.isNotEmpty)
              ? lane.nexusKind
              : 'direct';
          return NexusLettersPanel(
            key: ValueKey('${issue.id}-nexus'),
            caseId: caseId,
            issueId: issue.id,
            heading: heading,
            intro: intro,
            nexusKind: nexusKind,
          );
        }
        final statement = ref.watch(issueStatementProvider((issueId, kind)));
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

/// The Nexus Letters step. A short adaptive interview fills the gaps the saved
/// facts leave, then both letters are generated automatically and shown in a
/// two-tab preview with a continuous "ask for a change" loop. State lives on
/// the server; this panel reads and drives it one step at a time.
enum _NexusPhase { loading, interview, generating, letters }

class NexusLettersPanel extends ConsumerStatefulWidget {
  const NexusLettersPanel({
    super.key,
    required this.caseId,
    required this.issueId,
    required this.heading,
    required this.intro,
    required this.nexusKind,
  });

  final String caseId;
  final String issueId;
  final String heading;
  final String intro;
  final String nexusKind;

  @override
  ConsumerState<NexusLettersPanel> createState() => _NexusLettersPanelState();
}

class _NexusLettersPanelState extends ConsumerState<NexusLettersPanel> {
  final _answer = TextEditingController();
  _NexusPhase _phase = _NexusPhase.loading;
  NexusQuestion? _question;
  int _answered = 0;
  int _total = 0;
  var _busy = false;
  var _downloading = false;
  String? _error;
  Uint8List? _doctorBytes;
  Uint8List? _vetBytes;
  var _tab = 0; // 0 = doctor draft, 1 = veteran statement.
  final List<String> _doctorTweaks = [];
  final List<String> _vetTweaks = [];

  FormPreparationService get _service =>
      ref.read(formPreparationServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _step({String? answer, bool restart = false}) async {
    try {
      final state = await _service.nexusInterviewStep(
        caseId: widget.caseId,
        issueId: widget.issueId,
        nexusKind: widget.nexusKind,
        answer: answer,
        restart: restart,
      );
      if (!mounted) return;
      _answered = state.answered;
      _total = state.total;
      if (state.done) {
        await _generate();
      } else {
        setState(() {
          _question = state.question;
          _answer.clear();
          _busy = false;
          _phase = _NexusPhase.interview;
        });
      }
    } on ClaimGuideFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
          _phase = _NexusPhase.interview;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'This could not be opened. Try again.';
          _busy = false;
          _phase = _NexusPhase.interview;
        });
      }
    }
  }

  Future<void> _open() async {
    setState(() {
      _phase = _NexusPhase.loading;
      _error = null;
    });
    await _step();
  }

  Future<void> _submitAnswer() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await _step(answer: _answer.text.trim());
  }

  Future<void> _restart() async {
    setState(() {
      _phase = _NexusPhase.loading;
      _error = null;
      _doctorBytes = null;
      _vetBytes = null;
      _doctorTweaks.clear();
      _vetTweaks.clear();
      _tab = 0;
    });
    await _step(restart: true);
  }

  Future<void> _generate() async {
    setState(() {
      _phase = _NexusPhase.generating;
      _busy = false;
      _error = null;
    });
    try {
      final letters = await _service.generateNexusLetters(
        caseId: widget.caseId,
        issueId: widget.issueId,
      );
      if (!mounted) return;
      setState(() {
        _doctorBytes = letters.doctorBytes;
        _vetBytes = letters.vetBytes;
        _phase = _NexusPhase.letters;
      });
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The letters could not be prepared. Try again.',
        );
      }
    }
  }

  Future<bool> _revise(String letter, String instruction) async {
    try {
      final bytes = await _service.reviseNexusLetter(
        caseId: widget.caseId,
        issueId: widget.issueId,
        letter: letter,
        instruction: instruction,
      );
      if (!mounted) return false;
      setState(() {
        if (letter == 'doctor') {
          _doctorBytes = bytes;
          _doctorTweaks.add(instruction);
        } else {
          _vetBytes = bytes;
          _vetTweaks.add(instruction);
        }
      });
      return true;
    } on ClaimGuideFailure catch (error) {
      throw AiRefineFailure(error.message);
    }
  }

  Future<void> _download(String letter) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      final bytes = await _service.downloadNexusLetter(
        caseId: widget.caseId,
        issueId: widget.issueId,
        letter: letter,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: letter == 'doctor'
            ? 'Nexus-letter-doctor-draft.pdf'
            : 'Nexus-letter-statement.pdf',
      );
      if (mounted) setState(() => _downloading = false);
    } on ClaimGuideFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _downloading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'The copy could not be downloaded. Try again.';
          _downloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NestedForm(
      title: widget.heading,
      intro: widget.intro,
      footer: FormActions(
        onBack: () => openPreviousConditionPart(
          context,
          caseId: widget.caseId,
          issueId: widget.issueId,
          panel: 'doctor',
        ),
        onPrimary: () => context.go(
          AuthRoutes.caseConditionPanel(
            widget.caseId,
            widget.issueId,
            nextConditionPanel('doctor', laterClosed: false),
          ),
        ),
      ),
      child: _child(theme),
    );
  }

  Widget _child(ThemeData theme) {
    switch (_phase) {
      case _NexusPhase.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        );
      case _NexusPhase.interview:
        return _interviewView(theme);
      case _NexusPhase.generating:
        return _generatingView();
      case _NexusPhase.letters:
        return _lettersView();
    }
  }

  Widget _interviewView(ThemeData theme) {
    final question = _question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LeadText(
          'Answer a few quick questions so your letters are complete. They are written automatically when you are done. Do not include Social Security or account numbers.',
        ),
        if (_total > 0) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: AppBadge.primary(label: '$_answered of $_total answered'),
          ),
        ],
        const SizedBox(height: 16),
        if (question != null) ...[
          Text(question.prompt, style: theme.textTheme.titleMedium),
          if (question.help.isNotEmpty) ...[
            const SizedBox(height: 6),
            LeadText(question.help),
          ],
          const SizedBox(height: 12),
          AiChatInput(
            controller: _answer,
            onSend: (_) => _submitAnswer(),
            busy: _busy,
            hintText: 'Type your answer',
            maxLength: nexusAnswerMaxLength,
            minLines: 3,
            maxLines: 6,
            allowEmptySend: true,
          ),
        ],
        if (_error != null) ...[const SizedBox(height: 12), ErrorText(_error!)],
      ],
    );
  }

  Widget _generatingView() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorText(_error!),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _generate,
              child: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _restart,
              child: const Text('Edit answers'),
            ),
          ],
        ),
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Preparing your letters…'),
          ],
        ),
      ),
    );
  }

  Widget _lettersView() {
    final doctorActive = _tab == 0;
    final bytes = doctorActive ? _doctorBytes : _vetBytes;
    final letter = doctorActive ? 'doctor' : 'veteran';
    final tweaks = doctorActive ? _doctorTweaks : _vetTweaks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTabs(
          tabs: const [
            AppTab(label: 'Doctor draft'),
            AppTab(label: 'Your statement'),
          ],
          selected: _tab,
          onChanged: (index) => setState(() => _tab = index),
        ),
        const SizedBox(height: 16),
        LeadText(
          doctorActive
              ? 'An unsigned draft to take to your own physician to review, edit, and sign only if they agree. The diagnosis, rationale, and opinion are left for the doctor. The preview is watermarked — use Download PDF for a clean copy.'
              : 'A statement in support of claim that you can sign and file yourself. It lays out the legal points that support this claim and is not a medical opinion. The preview is watermarked — use Download PDF for a clean copy.',
        ),
        const SizedBox(height: 16),
        AiRefinePanel(
          key: ValueKey('refine-$letter'),
          enabled: !_busy,
          history: tweaks,
          onSubmit: (instruction) => _revise(letter, instruction),
          child: _preview(bytes, letter),
        ),
        if (_error != null) ...[const SizedBox(height: 12), ErrorText(_error!)],
      ],
    );
  }

  /// The framed PDF with a floating Download control pinned to its top-right,
  /// so the clean copy is one obvious tap away instead of buried below the
  /// scroll. The shared [PdfPreviewPane] stays read-only underneath.
  Widget _preview(Uint8List? bytes, String letter) {
    return Stack(
      children: [
        PdfPreviewPane(bytes: bytes),
        if (bytes != null)
          Positioned(
            top: 10,
            right: 10,
            child: Tooltip(
              message: 'Download a clean, unwatermarked PDF to print and sign',
              child: FilledButton(
                style: secondaryFilledStyle().copyWith(
                  elevation: const WidgetStatePropertyAll(3),
                  minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                onPressed: _downloading ? null : () => _download(letter),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.download_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(_downloading ? 'Preparing…' : 'Download PDF'),
                  ],
                ),
              ),
            ),
          ),
      ],
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
        title: 'New or already decided',
        child: Text('This condition could not be opened.'),
      ),
      data: (all) {
        final issue = findClaimIssue(all, caseId, issueId);
        if (issue == null) {
          return const NestedForm(
            title: 'New or already decided',
            child: Text('This condition is not on this claim.'),
          );
        }
        final saved = decisions.maybeWhen(
          data: (value) => value,
          orElse: () => const <RecordedDecision>[],
        );
        return _DecisionForm(caseId: caseId, issue: issue, decisions: saved);
      },
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
  late final TextEditingController _frequency;
  late final TextEditingController _duration;
  late final TextEditingController _impact;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final effects = LayEffects.fromBody(widget.saved?.body ?? '');
    _frequency = TextEditingController(text: effects.frequency);
    _duration = TextEditingController(text: effects.duration);
    _impact = TextEditingController(text: effects.impact);
  }

  @override
  void dispose() {
    _frequency.dispose();
    _duration.dispose();
    _impact.dispose();
    super.dispose();
  }

  String get _bodyText => LayEffects(
    frequency: _frequency.text,
    duration: _duration.text,
    impact: _impact.text,
  ).toBody();

  Future<bool> _save() async {
    final body = _bodyText;
    setState(() {
      _busy = true;
      _error = null;
    });
    var saved = false;
    try {
      if (body.isEmpty) {
        if (widget.saved != null) {
          await ref.read(removeStatementProvider)(
            issueId: widget.issueId,
            kind: widget.kind,
          );
        }
      } else {
        await ref.read(saveStatementProvider)(
          issueId: widget.issueId,
          kind: widget.kind,
          body: body,
        );
      }
      saved = true;
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return saved;
  }

  Future<void> _continue() async {
    final saved = await _save();
    if (!saved || !mounted) return;
    context.go(
      AuthRoutes.caseConditionPanel(
        widget.caseId,
        widget.issueId,
        nextConditionPanel('lay', laterClosed: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NestedForm(
      title: widget.heading,
      intro: widget.intro,
      footer: FormActions(
        onBack: () => openPreviousConditionPart(
          context,
          caseId: widget.caseId,
          issueId: widget.issueId,
          panel: 'lay',
        ),
        onPrimary: _continue,
        busy: _busy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextInputChain(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _EffectsTitle(
                  label: 'How often does this happen?',
                  message: 'Daily, a few times a week, only during flares — however you notice it. Frequency is a rating fact (38 CFR Part 4).',
                ),
                const SizedBox(height: 8),
                ChainTextField(
                  controller: _frequency,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 2000,
                ),
                const SizedBox(height: 16),
                const _EffectsTitle(
                  label: 'How long does it last?',
                  message: 'Minutes, hours, days, or how long you have lived with it. Duration is a rating fact (38 CFR Part 4).',
                ),
                const SizedBox(height: 8),
                ChainTextField(
                  controller: _duration,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 2000,
                ),
                const SizedBox(height: 16),
                const _EffectsTitle(
                  label: 'What does it keep you from doing?',
                  message: 'Work, sleep, walking, relationships, or anything else it changes. Functional impact is a rating fact (38 CFR Part 4).',
                ),
                const SizedBox(height: 8),
                ChainTextField(
                  controller: _impact,
                  enabled: !_busy,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                ),
              ],
            ),
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

class _EffectsTitle extends StatelessWidget {
  const _EffectsTitle({required this.label, required this.message});

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
        Tooltip(
          message: message,
          triggerMode: TooltipTriggerMode.tap,
          constraints: const BoxConstraints(maxWidth: 320),
          showDuration: const Duration(seconds: 12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.info_outline,
              size: 20,
              semanticLabel: 'About $label',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
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
  LaneAnswers? _draft;

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

  bool get _decisionStarted {
    return _date.text.trim().isNotEmpty ||
        _effective.text.trim().isNotEmpty ||
        _outcome != null ||
        _rating >= 0;
  }

  bool get _decisionFormOpen => widget.decisions.isEmpty || _adding;

  RecordedDecision? get _latest {
    if (widget.decisions.isEmpty) return null;
    final sorted = [...widget.decisions]
      ..sort((a, b) => b.decisionDate.compareTo(a.decisionDate));
    return sorted.first;
  }

  LaneAnswers _saved() {
    return ref
        .read(issueLaneAnswersProvider(widget.issue.id))
        .maybeWhen(data: (value) => value, orElse: () => LaneAnswers.empty);
  }

  void _edit(LaneAnswers answers) {
    setState(() {
      _draft = answers;
      _error = null;
    });
  }

  String? _decisionError() {
    final outcome = _outcome;
    final date = _date.text.trim();
    final effective = _effective.text.trim();
    if (outcome == null || !validIsoDate(date)) {
      return 'Enter the decision date and the outcome.';
    }
    if (effective.isNotEmpty && !validIsoDate(effective)) {
      return 'Enter a month, day, and year.';
    }
    if (_needsRating && _rating < 0) {
      return 'Choose the rating on that decision.';
    }
    return null;
  }

  Future<void> _storeDecision() async {
    final effective = _effective.text.trim();
    await ref.read(saveDecisionProvider)(
      caseId: widget.caseId,
      issueId: widget.issue.id,
      displayName: widget.issue.displayName,
      decisionDate: _date.text.trim(),
      outcome: _outcome!,
      ratingPercent: _needsRating ? _rating : null,
      effectiveDate: effective.isEmpty ? null : effective,
    );
    _adding = false;
    _outcome = null;
    _rating = -1;
    _date.clear();
    _effective.clear();
    _formKey++;
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

  Future<void> _continue() async {
    final answers = _draft ?? _saved();
    if (answers.origin != 'new' && answers.origin != 'decided') {
      setState(() => _error = 'Choose whether this is new or already decided.');
      return;
    }
    if (answers.origin == 'new' && !answers.pursueAnswered) {
      setState(() => _error = 'Choose whether to pursue this condition.');
      return;
    }
    final saveDecision =
        answers.origin == 'decided' &&
        _decisionFormOpen &&
        !(widget.decisions.isNotEmpty && !_decisionStarted);
    if (saveDecision) {
      final error = _decisionError();
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    final theories = ref
        .read(issueTheoriesProvider(widget.issue.id))
        .maybeWhen(
          data: (value) => {for (final theory in value) theory.type},
          orElse: () => <String>{},
        );
    var laneDecision = latestLaneDecision(widget.decisions);
    if (saveDecision) {
      final added = LaneDecision(
        decisionId: '',
        decisionIssueId: '',
        outcome: _outcome!,
        decisionDate: _date.text.trim(),
        displayName: widget.issue.displayName,
        reasonCategories: const [],
      );
      final current = laneDecision;
      if (current == null ||
          added.decisionDate.compareTo(current.decisionDate) >= 0) {
        laneDecision = added;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (saveDecision) await _storeDecision();
      await ref.read(saveLaneProvider)(
        issueId: widget.issue.id,
        answers: answers,
      );
      final uid = ref.read(authControllerProvider).session?.uid;
      final latest = _latest;
      if (uid != null && latest != null && latest.outcome != 'deferred') {
        await syncLaneReviews(
          ref: ref,
          uid: uid,
          caseId: widget.caseId,
          issue: widget.issue,
          decision: latest,
          answers: answers,
        );
      }
      if (!mounted) return;
      final lane = resolveIssueLane(
        issueId: widget.issue.id,
        displayName: widget.issue.displayName,
        decision: laneDecision,
        answers: answers,
        theoryTypes: theories,
        today: DateTime.now(),
      );
      context.go(
        AuthRoutes.caseConditionPanel(
          widget.caseId,
          widget.issue.id,
          nextConditionPanel(
            'decisions',
            laterClosed: lane.filing == IssueFiling.leave,
          ),
        ),
      );
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That choice could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref
        .watch(issueLaneAnswersProvider(widget.issue.id))
        .maybeWhen(data: (value) => value, orElse: () => LaneAnswers.empty);
    final answers = _draft ?? saved;
    return NestedForm(
      title: 'New or already decided',
      intro: 'Say whether this condition is new or already decided. A new condition can be pursued for disability compensation. A decision already received can continue as a new claim, a Supplemental Claim, a Higher-Level Review, or a Board Appeal. This does not file a claim.',
      footer: FormActions(
        onBack: () => openPreviousConditionPart(
          context,
          caseId: widget.caseId,
          issueId: widget.issue.id,
          panel: 'decisions',
        ),
        onPrimary: _continue,
        busy: _busy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OriginTabs(
            newTab: _OriginTab(
              open: answers.origin == 'new',
              card: _ChoiceCard(
                title: 'This is a new condition',
                subtitle: 'It has not been filed with the VA.',
                selected: answers.origin == 'new',
                linked: answers.origin == 'new',
                onTap: _busy
                    ? null
                    : () => _edit(
                        answers.copyWith(
                          origin: 'new',
                          choice: '',
                          againPath: '',
                          hasNewEvidence: false,
                          lawChanged: false,
                          medicalLinkMissing: false,
                        ),
                      ),
              ),
              body: _NewPursuit(answers: answers, busy: _busy, onEdit: _edit),
            ),
            decidedTab: _OriginTab(
              open: answers.origin == 'decided',
              card: _ChoiceCard(
                title: 'I already received a decision for this',
                subtitle: 'A decision is already on record for this condition.',
                selected: answers.origin == 'decided',
                linked: answers.origin == 'decided',
                onTap: _busy
                    ? null
                    : () => _edit(
                        answers.copyWith(
                          origin: 'decided',
                          pursue: false,
                          pursueAnswered: false,
                        ),
                      ),
              ),
              body: _DecidedBody(
                issue: widget.issue,
                decisions: widget.decisions,
                answers: answers,
                latest: _latest,
                busy: _busy,
                adding: _adding,
                formKey: _formKey,
                date: _date,
                effective: _effective,
                outcome: _outcome,
                rating: _rating,
                needsRating: _needsRating,
                onOutcome: (value) => setState(() => _outcome = value),
                onRating: (value) => setState(() => _rating = value ?? -1),
                onEdit: _edit,
                onAddAnother: _busy
                    ? null
                    : () => setState(() => _adding = true),
                onCancel: () => setState(() {
                  _adding = false;
                  _error = null;
                }),
                onRemove: _remove,
              ),
            ),
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

class _NewPursuit extends StatelessWidget {
  const _NewPursuit({
    required this.answers,
    required this.busy,
    required this.onEdit,
  });

  final LaneAnswers answers;
  final bool busy;
  final ValueChanged<LaneAnswers> onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Do you want this on the claim?',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Choose one.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _ChoicePair(
          matchHeight: true,
          first: _ChoiceCard(
            title: 'Pursue disability compensation',
            subtitle: 'Prepare the forms for this condition, including a nexus letter when one is needed.',
            tone: _ChoiceTone.suggest,
            selected: answers.pursueAnswered && answers.pursue,
            onTap: busy
                ? null
                : () => onEdit(
                    answers.copyWith(
                      origin: 'new',
                      pursue: true,
                      pursueAnswered: true,
                    ),
                  ),
          ),
          second: _ChoiceCard(
            title: 'Not on this claim',
            subtitle: 'Keep it on the list. No forms are prepared for it.',
            tone: _ChoiceTone.caution,
            selected: answers.pursueAnswered && !answers.pursue,
            onTap: busy
                ? null
                : () => onEdit(
                    answers.copyWith(
                      origin: 'new',
                      pursue: false,
                      pursueAnswered: true,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _DecidedBody extends StatelessWidget {
  const _DecidedBody({
    required this.issue,
    required this.decisions,
    required this.answers,
    required this.latest,
    required this.busy,
    required this.adding,
    required this.formKey,
    required this.date,
    required this.effective,
    required this.outcome,
    required this.rating,
    required this.needsRating,
    required this.onOutcome,
    required this.onRating,
    required this.onEdit,
    required this.onAddAnother,
    required this.onCancel,
    required this.onRemove,
  });

  final ClaimIssue issue;
  final List<RecordedDecision> decisions;
  final LaneAnswers answers;
  final RecordedDecision? latest;
  final bool busy;
  final bool adding;
  final int formKey;
  final TextEditingController date;
  final TextEditingController effective;
  final String? outcome;
  final int rating;
  final bool needsRating;
  final ValueChanged<String?> onOutcome;
  final ValueChanged<int?> onRating;
  final ValueChanged<LaneAnswers> onEdit;
  final VoidCallback? onAddAnother;
  final VoidCallback onCancel;
  final Future<void> Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Record the decision you received.',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        RepeatableEntries(
          entries: [
            for (final decision in decisions)
              EntryCard(
                onRemove: busy ? null : () => onRemove(decision.id),
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
          addingAnother: adding,
          onAddAnother: onAddAnother,
          onCancel: onCancel,
          form: TextInputChain(
            child: Column(
              key: ValueKey(formKey),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IsoDateField(
                  controller: date,
                  label: 'Decision date',
                  enabled: !busy,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: outcome,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Outcome'),
                  items: [
                    for (final entry in decisionOutcomes.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy ? null : onOutcome,
                ),
                if (needsRating) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: rating,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Rating on that decision',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('Choose a rating'),
                      ),
                      for (var value = 0; value <= 100; value += 10)
                        DropdownMenuItem(value: value, child: Text('$value')),
                    ],
                    onChanged: busy ? null : onRating,
                  ),
                ],
                const SizedBox(height: 12),
                IsoDateField(
                  controller: effective,
                  label: 'Effective date',
                  enabled: !busy,
                ),
              ],
            ),
          ),
        ),
        if (latest != null && latest!.outcome != 'deferred')
          IssueLanePanel(
            issue: issue,
            decision: latest!,
            answers: answers,
            busy: busy,
            onChanged: onEdit,
          )
        else if (latest?.outcome == 'deferred') ...[
          const SizedBox(height: 12),
          const InfoNote(text: 'The VA has not finished this.'),
        ],
      ],
    );
  }
}

class _OriginTabs extends StatelessWidget {
  const _OriginTabs({required this.newTab, required this.decidedTab});

  final Widget newTab;
  final Widget decidedTab;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [newTab, const SizedBox(height: 12), decidedTab],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: newTab),
            const SizedBox(width: 12),
            Expanded(child: decidedTab),
          ],
        );
      },
    );
  }
}

class _OriginTab extends StatelessWidget {
  const _OriginTab({
    required this.open,
    required this.card,
    required this.body,
  });

  final bool open;
  final Widget card;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    if (!open) return card;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            border: Border(
              left: BorderSide(color: scheme.primary, width: 2),
              right: BorderSide(color: scheme.primary, width: 2),
              bottom: BorderSide(color: scheme.primary, width: 2),
            ),
          ),
          child: Padding(padding: const EdgeInsets.all(16), child: body),
        ),
      ],
    );
  }
}

class _ChoicePair extends StatelessWidget {
  const _ChoicePair({
    required this.first,
    required this.second,
    this.matchHeight = false,
  });

  final Widget first;
  final Widget second;
  final bool matchHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          );
        }
        final row = Row(
          crossAxisAlignment: matchHeight
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            Expanded(child: _fill(first)),
            const SizedBox(width: 12),
            Expanded(child: _fill(second)),
          ],
        );
        if (!matchHeight) return row;
        return IntrinsicHeight(child: row);
      },
    );
  }

  Widget _fill(Widget child) {
    if (!matchHeight) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxHeight.isFinite) return child;
        return SizedBox(
          height: constraints.maxHeight,
          width: double.infinity,
          child: child,
        );
      },
    );
  }
}

enum _ChoiceTone { plain, suggest, caution }

/// Empty ring until the card is chosen, then a filled mark.
class _ChoiceMark extends StatelessWidget {
  const _ChoiceMark({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : scheme.outline,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.linked = false,
    this.tone = _ChoiceTone.plain,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final bool linked;
  final _ChoiceTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = switch (tone) {
      _ChoiceTone.suggest => AppColors.money,
      _ChoiceTone.caution => AppColors.sand,
      _ChoiceTone.plain => scheme.primary,
    };
    final color = selected ? accent : scheme.outline;
    final width = selected ? 2.0 : 1.0;
    final radius = linked
        ? const BorderRadius.vertical(top: Radius.circular(12))
        : BorderRadius.circular(12);
    final fill = switch (tone) {
      _ChoiceTone.suggest => AppColors.money.withValues(
        alpha: selected ? 0.26 : 0.14,
      ),
      _ChoiceTone.caution => AppColors.sand.withValues(
        alpha: selected ? 0.2 : 0.12,
      ),
      _ChoiceTone.plain =>
        selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
    };
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: Border(
            top: BorderSide(color: color, width: width),
            left: BorderSide(color: color, width: width),
            right: BorderSide(color: color, width: width),
            bottom: linked
                ? BorderSide.none
                : BorderSide(color: color, width: width),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
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
                    const SizedBox(width: 12),
                    _ChoiceMark(selected: selected, color: accent),
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

/// Back from a condition part. Questions returns to the conditions list.
/// A later part returns to the previous open part.
void openPreviousConditionPart(
  BuildContext context, {
  required String caseId,
  required String issueId,
  required String panel,
  bool laterClosed = false,
}) {
  final previous = previousConditionPanel(panel, laterClosed: laterClosed);
  context.go(
    previous == null
        ? AuthRoutes.caseConditions(caseId)
        : AuthRoutes.caseConditionPanel(caseId, issueId, previous),
  );
}
