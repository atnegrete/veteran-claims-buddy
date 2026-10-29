import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../account/profile.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_guide.dart';
import '../../claim/identifiers_repository.dart';
import '../../forms/iso_date_field.dart';
import '../../forms/mailing_address.dart';
import '../../forms/text_input_chain.dart';
import '../../onboarding/onboarding_progress.dart';
import '../../onboarding/onboarding_step.dart';
import 'onboarding_frame.dart';

class OnboardingResumeScreen extends ConsumerWidget {
  const OnboardingResumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(onboardingDocProvider);
    return doc.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const OnboardingFrame(
        step: OnboardingStep.welcome,
        title: 'Welcome',
        child: Text('Could not open onboarding. Try again.'),
      ),
      data: (data) {
        final step = savedOnboardingStep(data);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('${AuthRoutes.onboarding}/${step.name}');
          }
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _dob = TextEditingController();
  final _street = TextEditingController();
  final _unit = TextEditingController();
  final _city = TextEditingController();
  final _zip = TextEditingController();
  var _state = '';
  var _prefilled = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _middle.dispose();
    _last.dispose();
    _dob.dispose();
    _street.dispose();
    _unit.dispose();
    _city.dispose();
    _zip.dispose();
    super.dispose();
  }

  void _prefill(Identifiers value) {
    if (_prefilled) return;
    _prefilled = true;
    _first.text = value.legalFirstName;
    _middle.text = value.legalMiddleName;
    _last.text = value.legalLastName;
    _dob.text = value.dateOfBirth;
    _street.text = value.mailingStreet;
    _unit.text = value.mailingUnit;
    _city.text = value.mailingCity;
    _zip.text = value.mailingZip;
    _state = value.mailingState;
  }

  Future<void> _continue() async {
    final session = ref.read(authControllerProvider).session;
    if (session?.email == null) return;
    final first = _first.text.trim();
    final middle = _middle.text.trim();
    final last = _last.text.trim();
    final dob = _dob.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(() => _error = 'Enter your first and last name.');
      return;
    }
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
    final name = joinLegalName(first: first, middle: middle, last: last);
    if (!profileNameOk(name)) {
      setState(() => _error = 'Use $profileNameMax characters or fewer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final timezone = profileTimezoneOrDefault(
        ref.read(onboardingDocProvider).asData?.value?['timezone'] as String?,
      );
      await ref
          .read(onboardingRepositoryProvider)
          .ensureUserDocument(
            uid: session!.uid,
            email: session.email!,
            timezone: timezone,
          );
      await ref
          .read(identifiersRepositoryProvider)
          .saveLegalName(
            uid: session.uid,
            first: first,
            middle: middle,
            last: last,
            dateOfBirth: dob,
            emailIfEmpty: session.email,
            mailingStreet: _street.text,
            mailingUnit: _unit.text,
            mailingCity: _city.text,
            mailingState: _state,
            mailingZip: _zip.text,
          );
      await ref
          .read(profileRepositoryProvider)
          .save(uid: session.uid, displayName: name, timezone: timezone);
      await ref
          .read(onboardingRepositoryProvider)
          .saveStep(
            uid: session.uid,
            email: session.email!,
            step: OnboardingStep.service,
            complete: false,
          );
      if (mounted) context.go('${AuthRoutes.onboarding}/service');
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ProfileFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(identifiersProvider).whenData(_prefill);
    return OnboardingFrame(
      step: OnboardingStep.welcome,
      title: 'Welcome',
      busy: _busy,
      onNext: _continue,
      child: TextInputChain(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LeadText(
              'Veteran Claims Buddy helps you organize a disability claim: your service, what you were exposed to, and the evidence you already have.',
            ),
            const SizedBox(height: 16),
            const InfoNote(
              text:
                  'This account is for you, the Veteran. It does not prepare forms for a spouse, a survivor, or someone filing on a Veteran’s behalf. At this time we only support direct to Veteran accounts.',
            ),
            const SizedBox(height: 28),
            const Eyebrow('Personal information'),
            const SizedBox(height: 12),
            _PersonalFields(
              first: _first,
              middle: _middle,
              last: _last,
              dob: _dob,
              enabled: !_busy,
            ),
            const SizedBox(height: 28),
            MailingAddressFields(
              street: _street,
              unit: _unit,
              city: _city,
              zip: _zip,
              state: _state,
              enabled: !_busy,
              onState: (value) => setState(() => _state = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorText(_error!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonalFields extends StatelessWidget {
  const _PersonalFields({
    required this.first,
    required this.middle,
    required this.last,
    required this.dob,
    required this.enabled,
  });

  final TextEditingController first;
  final TextEditingController middle;
  final TextEditingController last;
  final TextEditingController dob;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final firstField = ChainTextField(
      controller: first,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      maxLength: 30,
      decoration: const InputDecoration(labelText: 'First name'),
    );
    final middleField = ChainTextField(
      controller: middle,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      maxLength: 30,
      decoration: const InputDecoration(labelText: 'Middle name (optional)'),
    );
    final lastField = ChainTextField(
      controller: last,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      maxLength: 40,
      decoration: const InputDecoration(labelText: 'Last name'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 520;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: firstField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: middleField),
                ],
              )
            else ...[
              firstField,
              const SizedBox(height: 12),
              middleField,
            ],
            const SizedBox(height: 12),
            lastField,
            const SizedBox(height: 12),
            IsoDateField(
              controller: dob,
              enabled: enabled,
              label: 'Date of birth',
            ),
          ],
        );
      },
    );
  }
}
