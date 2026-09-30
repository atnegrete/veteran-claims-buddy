import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_failure.dart';
import 'auth_scaffold.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  String? _message;
  bool _messageIsError = false;
  bool _busy = false;

  Future<void> _checkVerified() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).refreshSession();
      final verified =
          ref.read(authControllerProvider).session?.emailVerified ?? false;
      if (!verified && mounted) {
        setState(() {
          _message =
              'Still waiting on verification. Open the link, then try again.';
          _messageIsError = true;
        });
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

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).sendEmailVerification();
      if (mounted) {
        setState(() {
          _message = 'Verification email sent.';
          _messageIsError = false;
        });
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
    final email = ref.watch(authControllerProvider).session?.email;
    final sentTo = email == null || email.isEmpty ? 'your email' : email;
    return AuthScaffold(
      title: 'Verify your email',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Open the verification link sent to $sentTo. Claim information stays closed until that link is confirmed.',
          ),
          const SizedBox(height: 16),
          AuthMessageText(_message, isError: _messageIsError),
          FilledButton(
            onPressed: _busy ? null : _checkVerified,
            child: Text(_busy ? 'Checking…' : 'I verified my email'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _resend,
            child: const Text('Resend email'),
          ),
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
