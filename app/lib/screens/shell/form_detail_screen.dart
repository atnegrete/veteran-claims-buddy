import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_guide.dart';
import '../../claim/form_preparation.dart';
import '../../claim/form_recommender.dart';
import '../../forms/form_actions.dart';
import '../../forms/form_catalog.dart';
import '../../forms/form_questions.dart';
import '../../forms/nested_split.dart';
import '../../forms/package_form.dart';
import '../../claim/package_form_repository.dart';
import '../../forms/text_input_chain.dart';
import 'disability_drafts.dart';
import 'form_field_editor.dart';
import 'shell_pages.dart';

/// One form, opened beside the Forms list. This page is the description and the
/// copies already in the package. Opening one copy is a separate screen for
/// questions, Draft with AI, and the watermarked preview. Nothing is filed.
class FormDetailScreen extends ConsumerStatefulWidget {
  const FormDetailScreen({
    super.key,
    required this.caseId,
    required this.formNumber,
    this.copyKey = '',
    this.packetName = '',
    this.nexusKind = '',
  });

  final String caseId;
  final String formNumber;
  final String copyKey;
  final String packetName;
  final String nexusKind;

  @override
  ConsumerState<FormDetailScreen> createState() => _FormDetailScreenState();
}

class _FormDetailScreenState extends ConsumerState<FormDetailScreen> {
  /// Set only when the Veteran opens one package copy, or starts adding one.
  /// A form card is a link to this form's overview, so both clear when the
  /// form changes. The copy screen does not carry over.
  String? _openId;
  bool _creating = false;

  @override
  void didUpdateWidget(FormDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caseId != widget.caseId ||
        oldWidget.formNumber != widget.formNumber) {
      _creating = false;
      _openId = null;
    }
  }

  bool _needsSave(VaFormDef def) {
    return questionsFor(def.formNumber).isNotEmpty || def.needsStatement;
  }

  String get _copyIssueId {
    final parts = widget.copyKey.split(':');
    if (parts.length < 2) return '';
    return parts.sublist(1).join(':');
  }

  void _openNew(VaFormDef def) {
    if (!_needsSave(def)) {
      _addDirectly(def);
      return;
    }
    setState(() {
      _creating = true;
      _openId = null;
    });
  }

  Future<void> _addDirectly(VaFormDef def) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    final caseId = widget.caseId;
    final formNumber = def.formNumber;
    try {
      final id = await ref
          .read(packageFormRepositoryProvider)
          .add(
            uid: uid,
            caseId: caseId,
            formNumber: formNumber,
            displayLabel: def.shortTitle,
            multiplicityKey: widget.copyKey,
            packet: widget.packetName,
            conditionId: _copyIssueId,
            nexusKind: widget.nexusKind,
          );
      if (!mounted ||
          widget.caseId != caseId ||
          widget.formNumber != formNumber) {
        return;
      }
      setState(() {
        _creating = false;
        _openId = id;
      });
    } on ClaimGuideFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That could not be added. Try again.')),
      );
    }
  }

  void _openEntry(PackageForm entry) => setState(() {
    _openId = entry.id;
    _creating = false;
  });

  void _closeEditor() => setState(() {
    _creating = false;
    _openId = null;
  });

  PackageForm? _opened(List<PackageForm> entries) {
    final id = _openId;
    if (id == null) return null;
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final def = formDefFor(widget.formNumber);
    if (def == null) {
      return const NestedForm(
        child: LeadText('This form is not supported yet.'),
      );
    }
    final entries = ref
        .watch(packageFormsProvider(widget.caseId))
        .maybeWhen(
          data: (all) => [
            for (final form in all)
              if (form.formNumber == def.formNumber &&
                  (widget.copyKey.isEmpty ||
                      form.multiplicityKey == widget.copyKey))
                form,
          ],
          orElse: () => const <PackageForm>[],
        );
    final opened = _opened(entries);
    final inEditor = _creating || _openId != null;

    final listHidden = NestedListHidden.of(context);
    final formTitle = listHidden ? def.shortTitle : null;
    final close = listHidden
        ? NestedCloseButton(
            onPressed: () => context.go(AuthRoutes.casePrepare(widget.caseId)),
          )
        : null;

    if (inEditor && opened == null && !_creating) {
      return NestedForm(
        expandChild: true,
        title: formTitle,
        headerAction: close,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (inEditor) {
      return NestedForm(
        expandChild: true,
        title: formTitle,
        headerAction: close,
        child: _EntryEditor(
          key: ValueKey(_creating ? 'new' : opened!.id),
          caseId: widget.caseId,
          def: def,
          entry: opened,
          copyKey: widget.copyKey,
          packetName: widget.packetName,
          nexusKind: widget.nexusKind,
          conditionId: _copyIssueId,
          onSaved: (_) => _closeEditor(),
          onCancel: _closeEditor,
        ),
      );
    }

    return NestedForm(
      title: formTitle,
      headerAction: close,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EarlierClaimNote(caseId: widget.caseId),
          _InfoCard(def: def, inPackage: entries.isNotEmpty),
          const SizedBox(height: 12),
          const FilingNote(),
          const SizedBox(height: 20),
          _PackageSection(
            def: def,
            entries: entries,
            onAdd: () => _openNew(def),
            onOpen: _openEntry,
            onRemove: (entry) => _remove(entry),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(PackageForm entry) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    try {
      await ref
          .read(packageFormRepositoryProvider)
          .remove(uid: uid, packageFormId: entry.id);
      if (mounted && _openId == entry.id) {
        setState(() => _openId = null);
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That entry could not be removed.')),
      );
    }
  }
}

/// The info card: what this form is, and where it goes when submitted. This is
/// the clickable, readable replacement for the old bare external link.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.def, required this.inPackage});

  final VaFormDef def;
  final bool inPackage;

  bool get _intent => def.formNumber == '21-0966';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_intent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Eyebrow('Do this first')),
              if (!inPackage) const AppBadge.primary(label: 'Free to download'),
            ],
          ),
          const SizedBox(height: 8),
          Text(def.whatItIs, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          Text(
            def.whereItGoes,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          const InfoNote(
            text: 'This app does not send the form. Download it, check it, and mail it or upload it on VA.gov. Compensation is checked for a disability claim. You can have only one active Intent to File. Starting a disability claim on VA.gov also sets this date, so you do not need both.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('What this is'),
        const SizedBox(height: 8),
        Text(def.whatItIs, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        InfoNote(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where it goes', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                def.whereItGoes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The package section: how many of this form are on the claim, each entry, and
/// the add control (respecting single vs multiple multiplicity).
class _PackageSection extends StatelessWidget {
  const _PackageSection({
    required this.def,
    required this.entries,
    required this.onAdd,
    required this.onOpen,
    required this.onRemove,
  });

  final VaFormDef def;
  final List<PackageForm> entries;
  final VoidCallback onAdd;
  final void Function(PackageForm entry) onOpen;
  final void Function(PackageForm entry) onRemove;

  @override
  Widget build(BuildContext context) {
    final count = entries.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Eyebrow('In your package')),
            if (addedCountLabel(count) != null)
              AppBadge.primary(label: addedCountLabel(count)!),
          ],
        ),
        const SizedBox(height: 12),
        if (count == 0)
          LeadText(
            def.isMultiple
                ? 'Not added yet. You can add more than one of these.'
                : 'Not added yet.',
          )
        else
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _EntryRow(
              def: def,
              entry: entries[i],
              onOpen: () => onOpen(entries[i]),
              onRemove: () => onRemove(entries[i]),
            ),
          ],
        const SizedBox(height: 16),
        if (count == 0 || def.isMultiple)
          FilledButton(
            style: secondaryFilledStyle(),
            onPressed: onAdd,
            child: Text(
              count == 0
                  ? (def.formNumber == '21-0966'
                        ? 'Prepare this form'
                        : 'Add to Package')
                  : 'Add another',
            ),
          ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.def,
    required this.entry,
    required this.onOpen,
    required this.onRemove,
  });

  final VaFormDef def;
  final PackageForm entry;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  String get _statusLabel => switch (entry.status) {
    PackageFormStatus.ready => 'Ready to preview',
    PackageFormStatus.needsInput => 'Needs your input',
    PackageFormStatus.draft => 'Auto-filled',
  };

  @override
  Widget build(BuildContext context) {
    final label = entry.displayLabel.isEmpty
        ? def.shortTitle
        : entry.displayLabel;
    return AppNavRow(
      title: label,
      subtitle: _statusLabel,
      onTap: onOpen,
      trailing: TextButton(
        style: dangerTextStyle().copyWith(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onRemove,
        child: const Text('Remove'),
      ),
    );
  }
}

/// The inline editor for one entry: the question set, the AI draft (statement
/// forms), and the field preview. Saving adds or updates the package entry.
class _EntryEditor extends ConsumerStatefulWidget {
  const _EntryEditor({
    super.key,
    required this.caseId,
    required this.def,
    required this.entry,
    this.copyKey = '',
    this.packetName = '',
    this.nexusKind = '',
    this.conditionId = '',
    required this.onSaved,
    required this.onCancel,
  });

  final String caseId;
  final VaFormDef def;
  final PackageForm? entry;
  final String copyKey;
  final String packetName;
  final String nexusKind;
  final String conditionId;
  final ValueChanged<String> onSaved;
  final VoidCallback onCancel;

  @override
  ConsumerState<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<_EntryEditor> {
  final Map<String, TextEditingController> _answers = {};
  final _statement = TextEditingController();
  var _sectionDrafts = <String, String>{};
  var _busy = false;
  var _drafting = false;
  String? _error;

  bool get _is526 => widget.def.formNumber == '21-526EZ';

  @override
  void initState() {
    super.initState();
    for (final question in questionsFor(widget.def.formNumber)) {
      _answers[question.id] = TextEditingController(
        text: widget.entry?.answers[question.id] ?? '',
      );
    }
    _statement.text = widget.entry?.statementBody ?? '';
    _sectionDrafts = Map<String, String>.from(
      widget.entry?.sectionDrafts ?? const {},
    );
  }

  @override
  void dispose() {
    for (final controller in _answers.values) {
      controller.dispose();
    }
    _statement.dispose();
    super.dispose();
  }

  Map<String, String> _collectedAnswers() {
    final result = <String, String>{};
    _answers.forEach((key, controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) result[key] = value;
    });
    return result;
  }

  Future<void> _draft() async {
    setState(() {
      _drafting = true;
      _error = null;
    });
    try {
      final body = await ref
          .read(formPreparationServiceProvider)
          .draftStatement(
            caseId: widget.caseId,
            formNumber: widget.def.formNumber,
            kind: widget.def.statement,
            answers: _collectedAnswers(),
            nexusKind: widget.nexusKind,
          );
      if (!mounted) return;
      setState(() => _statement.text = body);
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'The draft could not be written.');
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  Future<void> _save() async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final answers = _collectedAnswers();
    final label = entryLabelFor(widget.def, answers);
    final statement = _statement.text.trim();
    final repo = ref.read(packageFormRepositoryProvider);
    try {
      var packageFormId = widget.entry?.id;
      if (packageFormId == null) {
        packageFormId = await repo.add(
          uid: uid,
          caseId: widget.caseId,
          formNumber: widget.def.formNumber,
          multiplicityKey: widget.copyKey.isNotEmpty
              ? widget.copyKey
              : widget.def.isMultiple
              ? _multiplicityKey(answers)
              : '',
          displayLabel: label,
          answers: answers,
          packet: widget.packetName,
          conditionId: widget.conditionId,
          nexusKind: widget.nexusKind,
        );
      } else {
        await repo.updateAnswers(
          uid: uid,
          packageFormId: packageFormId,
          answers: answers,
          displayLabel: label,
        );
      }
      if (widget.def.needsStatement && statement.isNotEmpty) {
        await repo.setStatement(
          uid: uid,
          packageFormId: packageFormId,
          body: statement,
        );
      }
      if (_is526) {
        await repo.setSectionDraft(
          uid: uid,
          packageFormId: packageFormId,
          sectionDrafts: _sectionDrafts,
        );
      }
      if (!mounted) return;
      widget.onSaved(packageFormId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved for this form.')));
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

  String _multiplicityKey(Map<String, String> answers) {
    final key = labelQuestionId[widget.def.formNumber];
    final value = key == null ? null : answers[key];
    if (value != null && value.isNotEmpty) return value.toLowerCase();
    // No natural key: a unique one so many blank-labelled entries can coexist.
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  bool get _hasTypedFields {
    return questionsFor(widget.def.formNumber).isNotEmpty ||
        widget.def.needsStatement;
  }

  bool get _needsSave {
    return _hasTypedFields || (_is526 && _sectionDrafts.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final questions = questionsFor(widget.def.formNumber);
    final isNew = widget.entry == null;
    final needsSave = _needsSave;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(112, 48)),
            onPressed: _busy ? null : widget.onCancel,
            child: const Text('Back'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: TextInputChain(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_hasTypedFields) ...[
                    Eyebrow(isNew ? 'Add to package' : 'Edit entry'),
                    const SizedBox(height: 12),
                  ],
                  for (final question in questions) ...[
                    ChainTextField(
                      controller: _answers[question.id]!,
                      enabled: !_busy && !_drafting,
                      maxLength: question.maxLength,
                      minLines: question.multiline ? 3 : 1,
                      maxLines: question.multiline ? null : 1,
                      textCapitalization: question.multiline
                          ? TextCapitalization.sentences
                          : TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: question.label,
                        hintText: question.hint,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.def.needsStatement) ...[
                    _StatementSection(
                      def: widget.def,
                      controller: _statement,
                      drafting: _drafting,
                      enabled: !_busy,
                      onDraft: _draft,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_is526 && widget.entry != null) ...[
                    DisabilityDrafts(
                      caseId: widget.caseId,
                      entry: widget.entry!,
                      onChanged: (drafts) =>
                          setState(() => _sectionDrafts = drafts),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.entry != null) ...[
                    FormPdfPreview(
                      packageFormId: widget.entry!.id,
                      sectionDrafts: _sectionDrafts,
                      caseId: widget.caseId,
                      formNumber: widget.def.formNumber,
                      download: widget.def.download,
                    ),
                    PdfKeyDebug(formNumber: widget.def.formNumber),
                  ] else
                    const InfoNote(
                      text: 'Add this form to your package to see a preview filled from your saved details.',
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 12), ErrorText(_error!)],
        if (needsSave)
          FormActions(
            onBack: widget.onCancel,
            backLabel: 'Cancel',
            onPrimary: _save,
            primaryLabel: isNew ? 'Add to Package' : 'Save',
            busy: _busy,
            busyLabel: 'Saving…',
          ),
      ],
    );
  }
}

class _StatementSection extends StatelessWidget {
  const _StatementSection({
    required this.def,
    required this.controller,
    required this.drafting,
    required this.enabled,
    required this.onDraft,
  });

  final VaFormDef def;
  final TextEditingController controller;
  final bool drafting;
  final bool enabled;
  final VoidCallback onDraft;

  @override
  Widget build(BuildContext context) {
    final doctorDraft = def.statement == FormStatementKind.doctorDraft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('Statement'),
        const SizedBox(height: 8),
        LeadText(
          doctorDraft
              ? 'AI writes an unsigned draft for you to take to your own physician. It is not a medical opinion. Read and edit it before you use it.'
              : 'AI drafts a first-person statement from your answers and your claim. Read and edit it; these are your words.',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            style: secondaryFilledStyle(),
            onPressed: enabled && !drafting ? onDraft : null,
            child: Text(drafting ? 'Drafting…' : 'Draft with AI'),
          ),
        ),
        const SizedBox(height: 12),
        ChainTextField(
          controller: controller,
          enabled: enabled && !drafting,
          maxLength: statementBodyMaxLength,
          minLines: 6,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Statement',
            alignLabelWithHint: true,
          ),
        ),
        if (doctorDraft) ...[
          const SizedBox(height: 8),
          const InfoNote(
            text: 'This is a draft for your physician to review, edit, and sign only if they agree. It is not a medical opinion and nothing here is filed with the VA.',
          ),
        ],
      ],
    );
  }
}
