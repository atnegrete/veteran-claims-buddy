import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_badge.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_guide.dart';
import '../../claim/discovery_questions.dart';
import '../../claim/questionnaire_catalog.dart';
import '../../claim/questionnaire_repository.dart';
import '../../forms/form_actions.dart';
import '../../forms/iso_date_field.dart';
import '../../forms/text_input_chain.dart';
import 'issues_screen.dart';
import 'shell_pages.dart';

class QuestionsScreen extends ConsumerWidget {
  const QuestionsScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(questionnaireSessionProvider);
    return ShellPage(
      title: 'Questions',
      expandChild: true,
      child: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('Those questions could not be opened.'),
        data: (value) {
          if (value.questions.isEmpty) {
            return const Text('Those questions could not be opened.');
          }
          return CatalogPanel(caseId: caseId);
        },
      ),
    );
  }
}

class CatalogPanel extends ConsumerStatefulWidget {
  const CatalogPanel({
    super.key,
    required this.caseId,
    this.onlyPageId,
    this.onLeave,
    this.onContinue,
  });

  final String? caseId;

  /// When set, only this topic is shown. Back returns through [onLeave].
  /// Continue uses [onContinue] when it is set, and [onLeave] otherwise.
  final String? onlyPageId;
  final VoidCallback? onLeave;
  final VoidCallback? onContinue;

  @override
  ConsumerState<CatalogPanel> createState() => _CatalogPanelState();
}

class _CatalogPanelState extends ConsumerState<CatalogPanel> {
  List<CatalogQuestion>? _questions;
  Map<String, List<String>>? _answers;
  String? _pageId;
  List<CatalogQuestion> _shown = const [];
  var _hasEarlier = false;
  var _returnToReview = false;
  var _seeded = false;
  var _busy = false;
  var _dirty = false;
  var _leaving = false;
  var _showErrors = false;
  String? _error;
  SaveQuestionnaire? _saver;
  final _scroll = ScrollController();
  final _anchors = <String, GlobalKey>{};
  final _fields = <String, TextEditingController>{};

  @override
  void dispose() {
    _leaving = true;
    _scroll.dispose();
    final page = _currentPage();
    if (page != null) _flush(page);
    if (_dirty) unawaited(_persist());
    for (final controller in _fields.values) {
      controller.removeListener(_markDirty);
      controller.dispose();
    }
    super.dispose();
  }

  void _seed(QuestionnaireSession session) {
    if (_seeded) return;
    _seeded = true;
    _questions = session.questions;
    _answers = {
      for (final entry in session.answers.entries)
        entry.key: List<String>.from(entry.value),
    };
    _place(
      widget.onlyPageId ?? resumeCatalogPageId(session.questions, _answers!),
    );
  }

  CatalogPage? _currentPage() {
    final pageId = _pageId;
    if (pageId == null) return null;
    return CatalogPage(
      id: pageId,
      title: catalogSectionTitles[pageId] ?? pageId,
      questions: _shown,
    );
  }

  void _place(String? pageId) {
    final questions = _questions;
    final answers = _answers;
    if (questions == null || answers == null) return;
    final pages = catalogPages(questions, answers);
    if (pageId == null || pages.isEmpty) {
      if (widget.onlyPageId != null) {
        _pageId = widget.onlyPageId;
        _shown = const [];
        _hasEarlier = true;
        return;
      }
      _pageId = null;
      _shown = const [];
      _hasEarlier = pages.isNotEmpty;
      return;
    }
    var index = pages.indexWhere((page) => page.id == pageId);
    if (index < 0) {
      if (widget.onlyPageId != null) {
        _pageId = widget.onlyPageId;
        _shown = const [];
        _hasEarlier = true;
        return;
      }
      index = pages.length - 1;
    }
    _pageId = pages[index].id;
    _shown = _pageQuestions(questions, pages[index]);
    _hasEarlier = widget.onlyPageId != null || index > 0;
  }

  List<CatalogQuestion> _pageQuestions(
    List<CatalogQuestion> questions,
    CatalogPage page,
  ) {
    if (page.id == 'gates') return page.questions;
    return catalogTopicQuestions(questions, page.id);
  }

  void _openCondition(DiscoveryCondition condition) {
    final questions = _questions;
    if (questions == null) return;
    final pageId = catalogPageIdForCondition(questions, condition.id);
    if (pageId == null) return;
    setState(() {
      _returnToReview = true;
      _place(pageId);
      _error = null;
      _showErrors = false;
    });
    _showTop();
  }

  void _closeReviewTopic() {
    final questions = _questions;
    final answers = _answers;
    setState(() {
      _returnToReview = false;
      _pageId = null;
      _shown = const [];
      _hasEarlier =
          questions != null &&
          answers != null &&
          catalogPages(questions, answers).isNotEmpty;
      _error = null;
      _showErrors = false;
    });
    _showTop();
  }

  void _rememberSaver() {
    _saver = ref.read(saveQuestionnaireProvider);
  }

  void _markDirty() {
    _dirty = true;
    if (_showErrors && mounted) setState(() {});
  }

  GlobalKey _anchor(String id) => _anchors.putIfAbsent(id, GlobalKey.new);

  String? _problem(CatalogQuestion question) {
    final questions = _questions;
    final answers = _answers;
    if (questions != null &&
        answers != null &&
        !catalogQuestionVisible(question, answers)) {
      return null;
    }
    if (question.isYearMonth) {
      final text = _fields[question.id]?.text.trim() ?? '';
      if (text.isNotEmpty && !validYearMonth(text)) {
        return 'Enter a month and year.';
      }
      if (question.required && text.isEmpty) return 'Enter a month and year.';
      return null;
    }
    if (question.isNote) {
      if (!question.required) return null;
      final text = _fields[question.id]?.text.trim() ?? '';
      if (text.isEmpty) return 'Add a short note.';
      return null;
    }
    if (!question.required) return null;
    if (!catalogAnswered(question, _answers ?? const {})) {
      return question.isMulti ? 'Choose at least one.' : 'Choose an answer.';
    }
    return null;
  }

  String? _footerMessage(CatalogPage page) {
    if (_error != null) return _error;
    if (!_showErrors) return null;
    final messages = [
      for (final question in page.questions)
        if (_problem(question) != null) _problem(question)!,
    ];
    if (messages.isEmpty) return null;
    if (messages.length == 1) return messages.first;
    return 'Answer the questions marked on this page.';
  }

  void _setAnswer(CatalogQuestion question, List<String> values) {
    final questions = _questions;
    final answers = _answers;
    if (questions == null || answers == null) return;
    final current = answers[question.id];
    if (values.isEmpty && current == null) return;
    if (current != null && sameAnswerValues(current, values)) return;
    final next = applyCatalogAnswer(questions, answers, question.id, values);
    _dropClearedFields(answers, next);
    setState(() {
      _answers = next;
      _error = null;
      _dirty = true;
    });
  }

  void _dropClearedFields(
    Map<String, List<String>> before,
    Map<String, List<String>> after,
  ) {
    for (final id in before.keys) {
      if (after.containsKey(id)) continue;
      final field = _fields[id];
      if (field != null && field.text.isNotEmpty) {
        field.text = '';
      }
    }
  }

  TextEditingController _field(CatalogQuestion question) {
    final existing = _fields[question.id];
    if (existing != null) return existing;
    final stored = _answers?[question.id];
    final initial =
        stored == null || stored.isEmpty || stored.first == 'skipped'
        ? ''
        : stored.first;
    final controller = TextEditingController(text: initial);
    controller.addListener(_markDirty);
    _fields[question.id] = controller;
    return controller;
  }

  void _flush(CatalogPage page) {
    final starting = _answers;
    if (starting == null) return;
    final answers = Map<String, List<String>>.of(starting);
    var changed = false;
    for (final question in page.questions) {
      if (!question.isYearMonth && !question.isNote) continue;
      if (!catalogQuestionVisible(question, answers)) continue;
      final text = _fields[question.id]?.text.trim() ?? '';
      if (question.isYearMonth && text.isNotEmpty && !validYearMonth(text)) {
        continue;
      }
      if (text.isEmpty && question.required) continue;
      final values = text.isEmpty ? const ['skipped'] : [text];
      final current = answers[question.id];
      if (current != null && sameAnswerValues(current, values)) continue;
      answers[question.id] = values;
      changed = true;
    }
    if (!changed) return;
    _answers = answers;
    _dirty = true;
  }

  String? _pageError(CatalogPage page) {
    for (final question in page.questions) {
      final problem = _problem(question);
      if (problem != null) return problem;
    }
    return null;
  }

  Future<void> _persist() async {
    final questions = _questions;
    if (questions == null) return;
    while (_dirty) {
      final page = _currentPage();
      if (page != null) _flush(page);
      if (!_dirty) return;
      final save = _saver;
      if (save == null) return;
      _dirty = false;
      final snapshot = {
        for (final entry in _answers!.entries)
          entry.key: List<String>.from(entry.value),
      };
      try {
        await save(
          caseId: widget.caseId,
          questions: questions,
          answers: snapshot,
        );
      } on ClaimGuideFailure catch (error) {
        _dirty = true;
        if (!_leaving && mounted) setState(() => _error = error.message);
        return;
      } catch (_) {
        _dirty = true;
        if (!_leaving && mounted) {
          setState(() => _error = 'That could not be saved. Try again.');
        }
        return;
      }
    }
  }

  Future<void> _continue() async {
    final page = _currentPage();
    final questions = _questions;
    if (page == null || questions == null || _busy) return;
    final error = _pageError(page);
    if (error != null) {
      final first = page.questions
          .where((question) => _problem(question) != null)
          .first;
      setState(() => _showErrors = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _anchor(first.id).currentContext;
        if (target == null || !target.mounted) return;
        Scrollable.ensureVisible(
          target,
          alignment: 0.05,
          duration: const Duration(milliseconds: 250),
        );
      });
      return;
    }
    _rememberSaver();
    _flush(page);
    _answers = activeCatalogAnswers(questions, _answers!);
    final pages = catalogPages(questions, _answers!);
    final index = pages.indexWhere((item) => item.id == page.id);
    setState(() {
      _busy = true;
      _error = null;
      _dirty = true;
    });
    try {
      await _persist();
      if (!mounted) return;
      if (widget.onlyPageId != null) {
        (widget.onContinue ?? widget.onLeave)?.call();
        return;
      }
      if (_returnToReview) {
        _closeReviewTopic();
        return;
      }
      setState(() {
        _showErrors = false;
        if (index < 0 || index + 1 >= pages.length) {
          _pageId = null;
          _shown = const [];
          _hasEarlier = pages.isNotEmpty;
        } else {
          _pageId = pages[index + 1].id;
          _shown = _pageQuestions(questions, pages[index + 1]);
          _hasEarlier = true;
        }
      });
      _showTop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showTop() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(0);
  }

  void _back() {
    final questions = _questions;
    final answers = _answers;
    final page = _currentPage();
    if (questions == null || answers == null || page == null) return;
    if (_returnToReview) {
      _flush(page);
      _rememberSaver();
      _dirty = true;
      unawaited(_persist());
      _closeReviewTopic();
      return;
    }
    if (widget.onlyPageId != null) {
      _flush(page);
      _rememberSaver();
      _dirty = true;
      unawaited(_persist());
      widget.onLeave?.call();
      return;
    }
    _flush(page);
    _rememberSaver();
    _dirty = true;
    final pages = catalogPages(questions, _answers!);
    final index = pages.indexWhere((item) => item.id == page.id);
    if (index <= 0) return;
    setState(() {
      _pageId = pages[index - 1].id;
      _shown = _pageQuestions(questions, pages[index - 1]);
      _hasEarlier = index - 1 > 0;
      _error = null;
      _showErrors = false;
    });
    _showTop();
    unawaited(_persist());
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(questionnaireSessionProvider);
    if (_answers == null) {
      return stored.when(
        data: (session) {
          _seed(session);
          return _body();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('Those questions could not be opened.'),
      );
    }
    return _body();
  }

  Widget _body() {
    final questions = _questions ?? const <CatalogQuestion>[];
    final answers = _answers ?? const <String, List<String>>{};
    final page = _currentPage();
    if (widget.onlyPageId != null && (page == null || page.questions.isEmpty)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LeadText('These questions are not open for this condition.'),
          FormActions(onBack: widget.onLeave),
        ],
      );
    }
    if (page == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                child: ConditionReview(
                  caseId: widget.caseId,
                  conditions: catalogConditions(questions, answers),
                  questions: questions,
                  onOpenQuestions: _busy ? null : _openCondition,
                ),
              ),
            ),
          ),
          FormActions(
            onPrimary: widget.caseId == null
                ? null
                : () => context.go(AuthRoutes.caseConditions(widget.caseId!)),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(page.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Expanded(
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              child: TextInputChain(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < page.questions.length; i++) ...[
                      if (i > 0) const Divider(height: 20),
                      _questionBlock(
                        page.questions[i],
                        index: i,
                        pageQuestions: page.questions,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_footerMessage(page) != null) ...[
          const SizedBox(height: 16),
          ErrorText(_footerMessage(page)!),
        ],
        FormActions(
          onBack: _returnToReview || _hasEarlier ? _back : null,
          onPrimary: _continue,
          busy: _busy,
        ),
      ],
    );
  }

  Widget _questionBlock(
    CatalogQuestion question, {
    required int index,
    required List<CatalogQuestion> pageQuestions,
  }) {
    final questions = _questions ?? const <CatalogQuestion>[];
    final answers = _answers ?? const <String, List<String>>{};
    final labels = {
      for (var i = 0; i < pageQuestions.length; i++)
        pageQuestions[i].id: '${i + 1}. ${pageQuestions[i].prompt}',
    };
    final blocked = catalogBlockedLabel(
      question,
      questions,
      answers,
      labels: labels,
    );
    final enabled = blocked == null && !_busy;
    final problem = _showErrors ? _problem(question) : null;
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: _anchor(question.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${index + 1}. ${question.prompt}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: blocked == null
                  ? null
                  : theme.colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
          if (blocked != null) ...[
            const SizedBox(height: 8),
            AppBadge.quiet(label: blocked),
          ],
          const SizedBox(height: 4),
          _answer(question, enabled: enabled),
          if (problem != null) ...[
            const SizedBox(height: 4),
            ErrorText(problem),
          ],
        ],
      ),
    );
  }

  Widget _answer(CatalogQuestion question, {required bool enabled}) {
    if (question.isMulti) return _multi(question, enabled: enabled);
    if (question.isYearMonth || question.isNote) {
      return _textEntry(question, enabled: enabled);
    }
    return _single(question, enabled: enabled);
  }

  Widget _single(CatalogQuestion question, {required bool enabled}) {
    final selected = _answers?[question.id];
    final group = selected == null || selected.isEmpty ? null : selected.first;
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.38,
        child: RadioGroup<String>(
          groupValue: group,
          onChanged: (value) {
            if (value == null) return;
            _setAnswer(question, [value]);
          },
          child: Column(
            children: [
              for (final choice in question.options)
                RadioListTile<String>(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minTileHeight: 28,
                  contentPadding: EdgeInsets.zero,
                  value: choice.value,
                  title: Text(
                    choice.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _multi(CatalogQuestion question, {required bool enabled}) {
    final picked = _answers?[question.id] ?? const <String>[];
    final crisis = question.options.any(
      (choice) => choice.crisisNotice != null && picked.contains(choice.value),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1 : 0.38,
            child: Column(
              children: [
                for (final choice in question.options)
                  CheckboxListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minTileHeight: 28,
                    contentPadding: EdgeInsets.zero,
                    value: picked.contains(choice.value),
                    title: Text(
                      choice.label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: enabled
                        ? (checked) {
                            final next = [...picked];
                            if (checked ?? false) {
                              if (!next.contains(choice.value)) {
                                next.add(choice.value);
                              }
                            } else {
                              next.remove(choice.value);
                            }
                            _setAnswer(question, next);
                          }
                        : null,
                  ),
              ],
            ),
          ),
        ),
        if (crisis) ...[
          const SizedBox(height: 8),
          const InfoNote(
            text: 'If this is an emergency, call or text 988, then press 1.',
          ),
        ],
      ],
    );
  }

  Widget _textEntry(CatalogQuestion question, {required bool enabled}) {
    if (question.isYearMonth) {
      return YearMonthField(
        controller: _field(question),
        label: 'Month and year',
        enabled: enabled,
      );
    }
    return ChainTextField(
      controller: _field(question),
      enabled: enabled,
      minLines: 3,
      maxLines: 6,
      maxLength: 2000,
      decoration: const InputDecoration(labelText: 'Details'),
    );
  }
}
