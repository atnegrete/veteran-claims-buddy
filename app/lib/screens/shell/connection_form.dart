import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_ui.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_issue.dart';
import '../../claim/issue_record_repository.dart';
import '../../forms/repeatable_entries.dart';
import '../../forms/text_input_chain.dart';

/// One saved path and the evidence notes that belong with it.
class _PairedPath {
  const _PairedPath({required this.theory, required this.links});

  final ClaimTheory theory;
  final List<EvidenceLink> links;

  EvidenceLink? linkOf(String type) {
    for (final link in links) {
      if (link.evidenceType == type) return link;
    }
    return null;
  }
}

/// Paths a veteran can choose here. An increase stays on New or already decided.
const _pathLabels = <String, String>{
  'direct': 'Directly from service',
  'secondary': 'Connected to another condition',
  'aggravation': 'Made worse in service',
  'presumptive': 'One service may presume',
};

const _pathTooltip =
    'Each path needs different facts. How often this happens and what it '
    'limits is the next part. Direct needs an in-service event (Shedden; '
    '38 CFR 3.303). Secondary needs the other service-connected condition '
    '(38 CFR 3.310). Before service needs what it was and how service made it '
    'worse (38 CFR 3.306). Presumptive needs qualifying service or exposure '
    '(38 CFR 3.307, 3.309). Rating facts are 38 CFR Part 4.';

const _serviceTooltip =
    'The injury, illness, event, or exposure you remember. Date or place if '
    'you have one. Shedden; 38 CFR 3.303. This note goes on the 21-526EZ '
    'explanation line.';

const _otherConditionTooltip =
    'Name it. It can already be rated, or it can be another condition on this '
    'claim. 38 CFR 3.310; Wallin. It does not need its own in-service event.';

const _beforeTooltip =
    'What the condition was before you served. 38 CFR 3.306.';

const _worseTooltip =
    'The duty, injury, or conditions of service — not a medical explanation. '
    '38 CFR 3.306. This note goes on the 21-526EZ line.';

const _exposureTooltip =
    'Where you served, when, or what you were exposed to. 38 CFR 3.307, 3.309. '
    'You do not have to prove the exposure, and a doctor’s letter is not '
    'prepared.';

/// Groups evidence notes onto the path that asks for them. Notes that do not
/// belong to a path stay in [leftOver] so they can still be removed.
({List<_PairedPath> paired, List<EvidenceLink> leftOver}) pairConnectionNotes({
  required List<ClaimTheory> theories,
  required List<EvidenceLink> links,
}) {
  final unused = [...links];
  EvidenceLink? take(String type) {
    final index = unused.indexWhere((link) => link.evidenceType == type);
    if (index < 0) return null;
    return unused.removeAt(index);
  }

  final paired = <_PairedPath>[];
  for (final theory in theories) {
    final attached = <EvidenceLink>[];
    if (theory.type == 'aggravation') {
      final before = take('inServiceEvent');
      if (before != null) attached.add(before);
    }
    paired.add(_PairedPath(theory: theory, links: attached));
  }
  return (paired: paired, leftOver: unused);
}

class ConnectionForm extends ConsumerStatefulWidget {
  const ConnectionForm({
    super.key,
    required this.issueId,
    required this.theories,
    required this.links,
    this.onBind,
  });

  final String issueId;
  final List<ClaimTheory> theories;
  final List<EvidenceLink> links;

  /// Receives the action that saves an open path. True means Continue can move on.
  final void Function(Future<bool> Function() commit)? onBind;

  @override
  ConsumerState<ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends ConsumerState<ConnectionForm> {
  final _service = TextEditingController();
  final _related = TextEditingController();
  final _before = TextEditingController();
  final _worse = TextEditingController();
  final _exposure = TextEditingController();
  String? _type;
  var _adding = false;
  var _busy = false;
  var _formKey = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.onBind?.call(_commit);
  }

  bool get _formOpen {
    final grouped = pairConnectionNotes(
      theories: widget.theories,
      links: widget.links,
    );
    final empty = grouped.paired.isEmpty && grouped.leftOver.isEmpty;
    return empty || _adding;
  }

  bool get _started {
    return _type != null ||
        _service.text.trim().isNotEmpty ||
        _related.text.trim().isNotEmpty ||
        _before.text.trim().isNotEmpty ||
        _worse.text.trim().isNotEmpty ||
        _exposure.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _service.dispose();
    _related.dispose();
    _before.dispose();
    _worse.dispose();
    _exposure.dispose();
    super.dispose();
  }

  Future<void> _saveNote(String type, String summary) async {
    final text = summary.trim();
    if (text.isEmpty) return;
    await ref.read(saveEvidenceLinkProvider)(
      issueId: widget.issueId,
      evidenceType: type,
      relationship: 'supports',
      summary: text,
    );
  }

  Future<bool> _commit() async {
    if (!_formOpen || !_started) return true;
    final type = _type;
    final service = _service.text.trim();
    final related = _related.text.trim();
    final before = _before.text.trim();
    final worse = _worse.text.trim();
    final exposure = _exposure.text.trim();
    if (type == null) {
      setState(() => _error = 'Choose how this connects to service.');
      return false;
    }
    final summary = switch (type) {
      'direct' => service,
      'secondary' => related,
      'aggravation' => worse,
      'presumptive' => exposure,
      _ => '',
    };
    final missing = switch (type) {
      'direct' => service.isEmpty,
      'secondary' => related.isEmpty,
      'aggravation' => before.isEmpty || worse.isEmpty,
      'presumptive' => exposure.isEmpty,
      _ => summary.isEmpty,
    };
    if (missing) {
      setState(() => _error = 'Answer each question for this path.');
      return false;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    var saved = false;
    try {
      await ref.read(saveTheoryProvider)(
        issueId: widget.issueId,
        type: type,
        summary: summary,
        relatedConditionName: type == 'secondary' ? related : null,
      );
      if (type == 'aggravation') await _saveNote('inServiceEvent', before);
      saved = true;
      if (!mounted) return saved;
      setState(() {
        _adding = false;
        _type = null;
        _service.clear();
        _related.clear();
        _before.clear();
        _worse.clear();
        _exposure.clear();
        _formKey++;
      });
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return saved;
  }

  Future<void> _removePath(_PairedPath pair) async {
    try {
      await ref.read(removeTheoryProvider)(
        issueId: widget.issueId,
        theoryId: pair.theory.id,
      );
      for (final link in pair.links) {
        await ref.read(removeEvidenceLinkProvider)(linkId: link.id);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'That could not be removed.');
    }
  }

  Future<void> _removeLink(String id) async {
    try {
      await ref.read(removeEvidenceLinkProvider)(linkId: id);
    } catch (_) {
      if (mounted) setState(() => _error = 'That note could not be removed.');
    }
  }

  List<EntryField> _fields(_PairedPath pair) {
    final theory = pair.theory;
    final fields = <EntryField>[
      EntryField(
        label: 'How it may be connected',
        value: connectionTypes[theory.type] ?? theory.type,
      ),
    ];
    switch (theory.type) {
      case 'direct':
        fields.add(
          EntryField(label: 'What happened in service', value: theory.summary),
        );
      case 'secondary':
        fields.add(
          EntryField(
            label: 'What other condition',
            value: theory.relatedConditionName ?? theory.summary,
          ),
        );
      case 'aggravation':
        final before = pair.linkOf('inServiceEvent');
        if (before != null) {
          fields.add(
            EntryField(
              label: 'What you had before service',
              value: before.summary,
            ),
          );
        }
        fields.add(
          EntryField(
            label: 'What in service made it worse',
            value: theory.summary,
          ),
        );
      case 'presumptive':
        fields.add(
          EntryField(
            label: 'What service, place, or exposure',
            value: theory.summary,
          ),
        );
      default:
        fields.add(
          EntryField(label: 'How it may be connected', value: theory.summary),
        );
    }
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = pairConnectionNotes(
      theories: widget.theories,
      links: widget.links,
    );
    final labels = {
      for (final row in directEvidenceMatrix) row.type: row.label,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepeatableEntries(
          entries: [
            for (final pair in grouped.paired)
              EntryCard(
                onRemove: _busy ? null : () => _removePath(pair),
                fields: _fields(pair),
              ),
            for (final link in grouped.leftOver)
              EntryCard(
                onRemove: _busy ? null : () => _removeLink(link.id),
                fields: [
                  EntryField(
                    label: 'About',
                    value: labels[link.evidenceType] ?? link.evidenceType,
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
          form: TextInputChain(
            child: Column(
              key: ValueKey(_formKey),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _QuestionTitle(
                  label: 'How it may be connected',
                  message: _pathTooltip,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'How it may be connected',
                  ),
                  items: [
                    for (final entry in _pathLabels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _type = value),
                ),
                if (_type == 'direct') ...[
                  const SizedBox(height: 16),
                  _noteField(
                    controller: _service,
                    label: 'What happened in service',
                    message: _serviceTooltip,
                  ),
                ],
                if (_type == 'secondary') ...[
                  const SizedBox(height: 16),
                  _noteField(
                    controller: _related,
                    label: 'What other condition',
                    message: _otherConditionTooltip,
                    minLines: 1,
                    maxLines: 2,
                    maxLength: 120,
                  ),
                ],
                if (_type == 'aggravation') ...[
                  const SizedBox(height: 16),
                  _noteField(
                    controller: _before,
                    label: 'What you had before service',
                    message: _beforeTooltip,
                  ),
                  const SizedBox(height: 16),
                  _noteField(
                    controller: _worse,
                    label: 'What in service made it worse',
                    message: _worseTooltip,
                  ),
                ],
                if (_type == 'presumptive') ...[
                  const SizedBox(height: 16),
                  _noteField(
                    controller: _exposure,
                    label: 'What service, place, or exposure',
                    message: _exposureTooltip,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 12), ErrorText(_error!)],
      ],
    );
  }

  Widget _noteField({
    required TextEditingController controller,
    required String label,
    required String message,
    int minLines = 2,
    int maxLines = 4,
    int maxLength = 500,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestionTitle(label: label, message: message),
        const SizedBox(height: 8),
        ChainTextField(
          controller: controller,
          enabled: !_busy,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
        ),
      ],
    );
  }
}

class _QuestionTitle extends StatelessWidget {
  const _QuestionTitle({required this.label, required this.message});

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
