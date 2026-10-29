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
        _messageIsError = false;
        _message = 'Enter the 6-digit code from the text message.';
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
          await ref.read(onboardingRepositoryProvider).ensureUserDocument(
                uid: session.uid,
                email: session.email ?? '',
                timezone: profileTimezoneOrDefault(null),
              );
          await ref.read(identifiersRepositoryProvider).seedFormContact(
                uid: session.uid,
                phone: phone,
                email: session.email,
              );
        } catch (_) {
          if (mounted) {
            setState(() {
              _message =
                  'Your phone is enrolled. The number for your forms could not be saved. You can add it on your profile.';
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
        title: 'Add a phone number',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LeadText(
              'The phone was removed, and security setup did not finish.',
            ),
            const SizedBox(height: 16),
            const AuthMessageText('Security setup did not finish. Try again.'),
            FilledButton(
              onPressed: () {
                ref
                    .read(authControllerProvider.notifier)
                    .clearServerAuthState();
              },
              child: const Text('Try again'),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
    }

    if (enrolled && !gate.serverAuthConfirmed) {
      return AuthScaffold(
        title: 'Add a phone number',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LeadText(
              'Your phone number is enrolled. Finishing security setup.',
            ),
            const SizedBox(height: 16),
            if (!gate.serverConfirmFailed)
              const Center(child: CircularProgressIndicator())
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
            TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'Add a phone number',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LeadText(
            'A phone number is required before any claim information. It is only a second sign-in check.',
          ),
          const SizedBox(height: 16),
          if (!_codeSent) ...[
            MobileNumberField(controller: _phone),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _agreed,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _agreed = value ?? false),
              title: const Text(
                'I agree to use this mobile number as a second sign-in check.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            AuthMessageText(_message, isError: _messageIsError),
            FilledButton(
              onPressed: _busy ? null : _sendCode,
              child: Text(_busy ? 'Sending…' : 'Send code'),
            ),
          ] else ...[
            Text('Code sent for $_sentLabel.'),
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
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _codeSent = false;
                      _code.clear();
                      _message = null;
                    }),
              child: const Text('Use a different number'),
            ),
          ],
          TextButton(
            onPressed: _busy
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
