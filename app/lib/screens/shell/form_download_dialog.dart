import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../claim/claim_guide.dart';
import '../../claim/form_preparation.dart';
import '../../claim/identifiers_repository.dart';
import '../../forms/canonical_profile.dart';
import '../../forms/va_form_mapping.dart';
import '../../forms/form_catalog.dart';
import '../../forms/identifier_fields.dart';
import '../../forms/text_input_chain.dart';

/// Opens the check-and-download dialog for one package form.
///
/// The Social Security number typed here is sent only to fill this file. It
/// is not written back to the account.
Future<void> showFormDownloadDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String packageFormId,
  required String formNumber,
  required FormDownloadPolicy policy,
  required String initialName,
  required String initialSsn,
  Map<String, String> sectionDrafts = const {},
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _FormDownloadDialog(
      packageFormId: packageFormId,
      formNumber: formNumber,
      policy: policy,
      initialName: initialName,
      initialSsn: initialSsn,
      sectionDrafts: sectionDrafts,
    ),
  );
}

class _FormDownloadDialog extends ConsumerStatefulWidget {
  const _FormDownloadDialog({
    required this.packageFormId,
    required this.formNumber,
    required this.policy,
    required this.initialName,
    required this.initialSsn,
    required this.sectionDrafts,
  });

  final String packageFormId;
  final String formNumber;
  final FormDownloadPolicy policy;
  final String initialName;
  final String initialSsn;
  final Map<String, String> sectionDrafts;

  @override
  ConsumerState<_FormDownloadDialog> createState() => _FormDownloadDialogState();
}

class _FormDownloadDialogState extends ConsumerState<_FormDownloadDialog> {
  late final TextEditingController _name;
  late final TextEditingController _ssn;
  var _certified = false;
  var _busy = false;
  bool _signedDownload = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _ssn = TextEditingController(text: widget.initialSsn);
    _name.addListener(_refresh);
    _ssn.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_refresh);
    _ssn.removeListener(_refresh);
    _name.dispose();
    _ssn.dispose();
    super.dispose();
  }

  bool get _nameOk {
    final parts = splitLegalName(_name.text);
    return (parts[CanonicalKeys.legalFirstName] ?? '').isNotEmpty &&
        (parts[CanonicalKeys.legalLastName] ?? '').isNotEmpty;
  }

  bool get _ssnOk =>
      !widget.policy.collectSsn ||
      RegExp(r'^\d{3}-\d{2}-\d{4}$').hasMatch(_ssn.text.trim());

  bool get _ready => _certified && _nameOk && _ssnOk && !_busy;

  Future<void> _download({required bool signed}) async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _signedDownload = signed;
      _error = null;
    });
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final ssn = widget.policy.collectSsn ? _ssn.text.trim() : '';
    final now = DateTime.now();
    final signedOn =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    try {
      final bytes = await ref.read(formPreparationServiceProvider).download(
            packageFormId: widget.packageFormId,
            legalName: name,
            signed: signed,
            ssn: ssn,
            signedOn: signedOn,
            sectionDrafts: widget.sectionDrafts,
          );
      await _saveName(name);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'VA-Form-${widget.formNumber}.pdf',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ClaimGuideFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'The form could not be downloaded. Try again.';
          _busy = false;
        });
      }
    }
  }

  Future<void> _saveName(String name) async {
    final parts = splitLegalName(name);
    final first = parts[CanonicalKeys.legalFirstName] ?? '';
    final last = parts[CanonicalKeys.legalLastName] ?? '';
    if (first.isEmpty || last.isEmpty) return;
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    try {
      final current =
          ref.read(identifiersProvider).asData?.value ?? Identifiers.empty;
      await ref.read(identifiersRepositoryProvider).save(
            uid: uid,
            value: Identifiers(
              legalFirstName: first,
              legalMiddleName: parts[CanonicalKeys.legalMiddleName] ?? '',
              legalLastName: last,
              dateOfBirth: current.dateOfBirth,
              ssn: current.ssn,
              vaFileNumber: current.vaFileNumber,
              phone: current.phone,
              email: current.email,
              mailingStreet: current.mailingStreet,
              mailingUnit: current.mailingUnit,
              mailingCity: current.mailingCity,
              mailingState: current.mailingState,
              mailingZip: current.mailingZip,
            ),
          );
    } on Object {
      // The file is already built. A missed name save does not block it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameStarted = _name.text.trim().isNotEmpty;
    final ssnStarted = _ssn.text.trim().isNotEmpty;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: TextInputChain(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Check this form', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                const LeadText(
                  'Read the preview and the file you download. Confirm that your information is correct and that nothing important is missing. This app does not send the form to the VA.',
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _certified,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _certified = value ?? false),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'I certify that the information on this form is correct and true to the best of my knowledge.',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ChainTextField(
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full legal name'),
                ),
                if (nameStarted && !_nameOk) ...[
                  const SizedBox(height: 8),
                  const ErrorText('Enter your first and last name.'),
                ],
                if (widget.policy.collectSsn) ...[
                  const SizedBox(height: 12),
                  SsnField(controller: _ssn, enabled: !_busy),
                  const SizedBox(height: 8),
                  Text(
                    'This number is not saved from this step. It is used only to fill the Social Security boxes on the file you download. That file contains it, because the VA form asks for it.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (ssnStarted && !_ssnOk) ...[
                    const SizedBox(height: 8),
                    const ErrorText('Enter all 9 digits.'),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorText(_error!),
                ],
                const SizedBox(height: 20),
                if (widget.policy.allowSigned)
                  FilledButton(
                    onPressed: _ready ? () => _download(signed: true) : null,
                    child: Text(
                      _busy && _signedDownload ? 'Downloading…' : 'Download signed',
                    ),
                  ),
                if (widget.policy.allowSigned && widget.policy.allowUnsigned)
                  const SizedBox(height: 12),
                if (widget.policy.allowUnsigned)
                  FilledButton(
                    style: secondaryFilledStyle(),
                    onPressed: _ready ? () => _download(signed: false) : null,
                    child: Text(
                      _busy && !_signedDownload
                          ? 'Downloading…'
                          : 'Download unsigned',
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
