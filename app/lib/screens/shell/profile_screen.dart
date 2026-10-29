import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/profile.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../auth/phone_number.dart';
import '../../claim/claim_guide.dart';
import '../../claim/identifiers_repository.dart';
import '../../forms/iso_date_field.dart';
import '../../forms/mailing_address.dart';
import '../../forms/text_input_chain.dart';
import '../../onboarding/onboarding_progress.dart';
import 'shell_pages.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(onboardingDocProvider);
    final identifiers = ref.watch(identifiersProvider);
    if (account.isLoading || identifiers.isLoading) {
      return const ShellPage(
        title: 'Profile',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (account.hasError || identifiers.hasError) {
      return const ShellPage(
        title: 'Profile',
        child: Text('Profile could not be opened. Try again.'),
      );
    }
    return _ProfileForm(
      data: account.asData?.value,
      identifiers: identifiers.asData?.value ?? Identifiers.empty,
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.data, required this.identifiers});

  final Map<String, dynamic>? data;
  final Identifiers identifiers;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _first;
  late final TextEditingController _middle;
  late final TextEditingController _last;
  late final TextEditingController _dob;
  late final TextEditingController _street;
  late final TextEditingController _unit;
  late final TextEditingController _city;
  late final TextEditingController _zip;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late String _timezone;
  late String _state;
  var _busy = false;
  String? _error;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    final ids = widget.identifiers;
    _first = TextEditingController(text: ids.legalFirstName);
    _middle = TextEditingController(text: ids.legalMiddleName);
    _last = TextEditingController(text: ids.legalLastName);
    _dob = TextEditingController(text: ids.dateOfBirth);
    _dob.addListener(_edited);
    _street = TextEditingController(text: ids.mailingStreet);
    _unit = TextEditingController(text: ids.mailingUnit);
    _city = TextEditingController(text: ids.mailingCity);
    _zip = TextEditingController(text: ids.mailingZip);
    _state = ids.mailingState;
    _email = TextEditingController(text: ids.email);
    _phone = TextEditingController(
      text: ids.phone.isEmpty ? '' : formatUsPhone(ids.phone),
    );
    _timezone = profileTimezoneOrDefault(widget.data?['timezone'] as String?);
  }

  @override
  void dispose() {
    _first.dispose();
    _middle.dispose();
    _last.dispose();
    _dob.removeListener(_edited);
    _dob.dispose();
    _street.dispose();
    _unit.dispose();
    _city.dispose();
    _zip.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _edited() {
    if (_saved) setState(() => _saved = false);
  }

  Future<void> _save() async {
    final first = _first.text.trim();
    final middle = _middle.text.trim();
    final last = _last.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(() => _error = 'Enter your first and last name.');
      return;
    }
    final dob = _dob.text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dob)) {
      setState(() => _error = 'Enter the date of birth as YYYY-MM-DD.');
      return;
    }
    final addressError = mailingRequiredMessage(
      street: _street.text,
      city: _city.text,
      state: _state,
      zip: _zip.text,
    );
    if (addressError != null) {
      setState(() => _error = addressError);
      return;
    }
    final digits = nationalDigits(_phone.text);
    final phone = digits.isEmpty
        ? ''
        : (toE164(_phone.text) ?? _phone.text.trim());
    final email = _email.text.trim();
    final name = joinLegalName(first: first, middle: middle, last: last);
    final next = Identifiers(
      legalFirstName: first,
      legalMiddleName: middle,
      legalLastName: last,
      dateOfBirth: dob,
      ssn: widget.identifiers.ssn,
      vaFileNumber: widget.identifiers.vaFileNumber,
      phone: phone,
      email: email,
      mailingStreet: _street.text,
      mailingUnit: _unit.text,
      mailingCity: _city.text,
      mailingState: _state,
      mailingZip: _zip.text,
    );
    final invalid = identifiersError(next);
    if (invalid != null || !profileNameOk(name)) {
      setState(() {
        _error = invalid ?? 'Use $profileNameMax characters or fewer.';
      });
      return;
    }
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) {
      setState(() => _error = 'Sign in again, then try again.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _saved = false;
    });
    try {
      await ref.read(identifiersRepositoryProvider).save(uid: uid, value: next);
      await ref.read(saveProfileProvider)(
        displayName: name,
        timezone: _timezone,
      );
      if (mounted) setState(() => _saved = true);
    } on ProfileFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
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
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return ShellPage(
      title: 'Profile',
      child: TextInputChain(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Eyebrow('Personal information'),
            const SizedBox(height: 12),
            ChainTextField(
              controller: _first,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              maxLength: 30,
              onChanged: (_) => _edited(),
              decoration: const InputDecoration(labelText: 'First name'),
            ),
            const SizedBox(height: 12),
            ChainTextField(
              controller: _middle,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              maxLength: 30,
              onChanged: (_) => _edited(),
              decoration: const InputDecoration(labelText: 'Middle name'),
            ),
            const SizedBox(height: 12),
            ChainTextField(
              controller: _last,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              onChanged: (_) => _edited(),
              decoration: const InputDecoration(labelText: 'Last name'),
            ),
            const SizedBox(height: 12),
            IsoDateField(
              controller: _dob,
              enabled: !_busy,
              label: 'Date of birth',
            ),
            const SizedBox(height: 28),
            MailingAddressFields(
              street: _street,
              unit: _unit,
              city: _city,
              zip: _zip,
              state: _state,
              enabled: !_busy,
              onChanged: _edited,
              onState: (value) => setState(() {
                _state = value;
                _saved = false;
              }),
            ),
            const SizedBox(height: 12),
            ChainTextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              maxLength: 254,
              onChanged: (_) => _edited(),
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            Text(
              'This address fills VA forms. Changing it does not change the email you use to sign in.',
              style: muted,
            ),
            const SizedBox(height: 12),
            MobileNumberField(
              controller: _phone,
              enabled: !_busy,
              onChanged: (_) => _edited(),
            ),
            const SizedBox(height: 8),
            Text(
              'This number fills VA forms. Changing it does not change the number you use to sign in.',
              style: muted,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_timezone),
              initialValue: _timezone,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Time zone'),
              items: [
                for (final entry in profileTimezones.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _timezone = value;
                        _saved = false;
                      });
                    },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorText(_error!),
            ],
            if (_saved) ...[
              const SizedBox(height: 12),
              const LeadText('Saved.'),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
