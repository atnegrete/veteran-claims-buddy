import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_ui.dart';
import '../../account/profile.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_failure.dart';
import '../../auth/phone_number.dart';
import '../../claim/identifiers_repository.dart';
import '../../onboarding/onboarding_progress.dart';
import '../../forms/text_input_chain.dart';
import 'auth_scaffold.dart';

class MfaEnrollScreen extends ConsumerStatefulWidget {
  const MfaEnrollScreen({super.key});

  @override
  ConsumerState<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends ConsumerState<MfaEnrollScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _message;
  bool _messageIsError = true;
  bool _busy = false;
  bool _agreed = false;
  bool _codeSent = false;
  String? _sentLabel;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final e164 = toE164(_phone.text);
    if (e164 == null) {
      setState(() {
        _message = 'Enter a valid mobile number.';
        _messageIsError = true;
      });
      return;
    }
    if (!_agreed) {
      setState(() {
        _message =
            'Agree to use this number for sign-in before sending a code.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).sendEnrollmentCode(e164);
      setState(() {
        _codeSent = true;
        _sentLabel = maskPhoneNumber(e164);
        _message = null;
      });
    } on AuthFailure catch (failure) {
      setState(() {
        _message = failure.message;
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() {
        _message = 'Enter the 6-digit code.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .confirmEnrollmentCode(code);
      final session = ref.read(authControllerProvider).session;
      final phone = toE164(_phone.text);
      if (session != null && phone != null) {
        try {
          await ref
              .read(onboardingRepositoryProvider)
              .ensureUserDocument(
                uid: session.uid,
                email: session.email ?? '',
                timezone: profileTimezoneOrDefault(null),
              );
          await ref
              .read(identifiersRepositoryProvider)
              .seedFormContact(
                uid: session.uid,
                phone: phone,
                email: session.email,
              );
        } catch (_) {
          if (mounted) {
            setState(() {
              _message = 'Your phone is enrolled. The number for your forms could not be saved. You can add it on your profile.';
              _messageIsError = true;
            });
          }
        }
      }
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _message = failure.message;
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(authControllerProvider);
    final enrolled = gate.session?.mfaEnrolled ?? false;
    if (!enrolled && gate.serverAuthConfirmed && gate.serverConfirmFailed) {
      return AuthScaffold(
        eyebrow: 'Security',
        title: 'Add a phone number',
        lead: 'The phone was removed, and security setup did not finish.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthMessageText('Security setup did not finish. Try again.'),
            FilledButton(
              onPressed: () {
                ref
                    .read(authControllerProvider.notifier)
                    .clearServerAuthState();
              },
              child: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            AuthTextLink(
              label: 'Sign out',
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
      );
    }

    if (enrolled && !gate.serverAuthConfirmed) {
      return AuthScaffold(
        eyebrow: 'Security',
        title: 'Add a phone number',
        lead: 'Your phone number is enrolled. Finishing security setup.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!gate.serverConfirmFailed)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              const AuthMessageText(
                'Security setup did not finish. Try again.',
              ),
              FilledButton(
                onPressed: () {
                  ref
                      .read(authControllerProvider.notifier)
                      .confirmServerAuthState();
                },
                child: const Text('Try again'),
              ),
            ],
            const SizedBox(height: 8),
            AuthTextLink(
              label: 'Sign out',
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      eyebrow: 'Security',
      title: 'Add a phone number',
      lead: 'A phone number is required before any claim information. It is only a second sign-in check.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_codeSent) ...[
            MobileNumberField(controller: _phone),
            const SizedBox(height: 8),
            MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _agreed = value ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'I agree to use this mobile number as a second sign-in check.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AuthMessageText(_message, isError: _messageIsError),
            FilledButton(
              onPressed: _busy ? null : _sendCode,
              child: Text(_busy ? 'Sending…' : 'Send code'),
            ),
          ] else ...[
            LeadText('Enter the 6-digit code sent to $_sentLabel.'),
            const SizedBox(height: 12),
            ChainTextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '6-digit code',
                counterText: '',
              ),
              onSubmitted: (_) => _confirm(),
            ),
            const SizedBox(height: 16),
            AuthMessageText(_message, isError: _messageIsError),
            FilledButton(
              onPressed: _busy ? null : _confirm,
              child: Text(_busy ? 'Checking…' : 'Confirm phone'),
            ),
            const SizedBox(height: 4),
            AuthTextLink(
              label: 'Use a different number',
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _codeSent = false;
                      _code.clear();
                      _message = null;
                    }),
            ),
          ],
          const SizedBox(height: 4),
          AuthTextLink(
            label: 'Sign out',
            onPressed: _busy
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}
