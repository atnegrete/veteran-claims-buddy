import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../auth/phone_number.dart';
import '../../claim/claim_guide.dart';
import '../../claim/identifiers_repository.dart';
import '../../forms/form_actions.dart';
import '../../forms/identifier_fields.dart';
import '../../forms/iso_date_field.dart';
import '../../forms/text_input_chain.dart';
import 'shell_pages.dart';

/// Collects the protected identifiers a VA form needs (legal name, date of
/// birth, SSN, VA file number, phone). Separate from the profile, owner-only,
/// and only asked for when a form requires them. Nothing is filed with the VA.
class IdentifiersScreen extends ConsumerStatefulWidget {
  const IdentifiersScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<IdentifiersScreen> createState() => _IdentifiersScreenState();
}

class _IdentifiersScreenState extends ConsumerState<IdentifiersScreen> {
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _dob = TextEditingController();
  final _ssn = TextEditingController();
  final _fileNumber = TextEditingController();
  final _phone = TextEditingController();
  var _email = '';
  var _street = '';
  var _unit = '';
  var _city = '';
  var _stateCode = '';
  var _zip = '';

  var _loaded = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _middle.dispose();
    _last.dispose();
    _dob.dispose();
    _ssn.dispose();
    _fileNumber.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _prefill(Identifiers value) {
    if (_loaded) return;
    _loaded = true;
    _first.text = value.legalFirstName;
    _middle.text = value.legalMiddleName;
    _last.text = value.legalLastName;
    _dob.text = value.dateOfBirth;
    _ssn.text = value.ssn;
    _fileNumber.text = value.vaFileNumber;
    _phone.text = value.phone.isEmpty ? '' : formatUsPhone(value.phone);
    _email = value.email;
    _street = value.mailingStreet;
    _unit = value.mailingUnit;
    _city = value.mailingCity;
    _stateCode = value.mailingState;
    _zip = value.mailingZip;
  }

  Future<void> _save() async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final phone = _phone.text.trim().isEmpty
        ? ''
        : (toE164(_phone.text) ?? _phone.text.trim());
    try {
      await ref.read(identifiersRepositoryProvider).save(
            uid: uid,
            value: Identifiers(
              legalFirstName: _first.text.trim(),
              legalMiddleName: _middle.text.trim(),
              legalLastName: _last.text.trim(),
              dateOfBirth: _dob.text.trim(),
              ssn: _ssn.text.trim(),
              vaFileNumber: _fileNumber.text.trim(),
              phone: phone,
              email: _email,
              mailingStreet: _street,
              mailingUnit: _unit,
              mailingCity: _city,
              mailingState: _stateCode,
              mailingZip: _zip,
            ),
          );
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
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
    final async = ref.watch(identifiersProvider);
    async.whenData(_prefill);
    return ShellPage(
      title: 'Your identifiers',
      child: TextInputChain(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LeadText(
              'VA forms need these to identify you. They are stored only for your forms and are never filed from here.',
            ),
            const SizedBox(height: 12),
            const InfoNote(
              text:
                  'Your Social Security number and VA file number stay on this device-protected record. Do not put them into a statement.',
            ),
            const SizedBox(height: 16),
            ChainTextField(
              controller: _first,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Legal first name'),
            ),
            const SizedBox(height: 12),
            ChainTextField(
              controller: _middle,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Legal middle name (optional)',
              ),
            ),
            const SizedBox(height: 12),
            ChainTextField(
              controller: _last,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Legal last name'),
            ),
            const SizedBox(height: 12),
            IsoDateField(
              controller: _dob,
              label: 'Date of birth',
              enabled: !_busy,
            ),
            const SizedBox(height: 12),
            SsnField(controller: _ssn, enabled: !_busy),
            const SizedBox(height: 12),
            VaFileNumberField(controller: _fileNumber, enabled: !_busy),
            const SizedBox(height: 12),
            MobileNumberField(controller: _phone, enabled: !_busy),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorText(_error!),
            ],
            FormActions(
              onBack: _busy
                  ? null
                  : () => context.canPop() ? context.pop() : null,
              onPrimary: _busy ? null : _save,
              primaryLabel: 'Save',
              busy: _busy,
            ),
          ],
        ),
      ),
    );
  }
}
