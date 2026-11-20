import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_failure.dart';
import '../../auth/auth_redirect.dart';
import '../../auth/mfa_challenge.dart';
import '../../forms/text_input_chain.dart';
import 'auth_scaffold.dart';

class MfaChallengeScreen extends ConsumerStatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  ConsumerState<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends ConsumerState<MfaChallengeScreen> {
  final _code = TextEditingController();
  String? _message;
  bool _messageIsError = true;
  bool _busy = false;
  String? _selectedUid;
  bool _codeSent = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send(PhoneFactorHint hint) async {
    setState(() {
      _busy = true;
      _message = null;
      _selectedUid = hint.uid;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .sendChallengeCode(hint.uid);
      setState(() {
        _codeSent = true;
        _messageIsError = false;
        _message = 'Enter the 6-digit code sent for ${hint.label}.';
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
          .confirmChallengeCode(code);
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
    final hints = ref.watch(authControllerProvider).challengeHints;
    return AuthScaffold(
      eyebrow: 'Security',
      title: 'Text-message check',
      lead: 'Finish signing in with the code sent to a phone on this account.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hints.isEmpty)
            const LeadText(
              'No phone is available for this sign-in. If you lost the phone, contact support.',
            )
          else
            for (final hint in hints)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _send(hint),
                  child: Text(
                    _selectedUid == hint.uid && _codeSent
                        ? 'Code sent to ${hint.label}'
                        : 'Text a code to ${hint.label}',
                  ),
                ),
              ),
          if (_codeSent) ...[
            const SizedBox(height: 8),
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
              child: Text(_busy ? 'Checking…' : 'Confirm code'),
            ),
          ] else
            AuthMessageText(_message, isError: _messageIsError),
          const SizedBox(height: 8),
          AuthTextLink(
            label: 'Lost your phone?',
            onPressed: () => context.go(AuthRoutes.recovery),
          ),
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
