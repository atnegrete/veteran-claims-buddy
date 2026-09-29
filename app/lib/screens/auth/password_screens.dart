import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_failure.dart';
import '../../auth/auth_redirect.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _message;
  bool _messageIsError = true;
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_email.text.contains('@')) {
      setState(() {
        _message = 'Enter a valid email address.';
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
          .sendPasswordReset(_email.text);
      setState(() {
        _sent = true;
        _messageIsError = false;
        _message =
            'If an account exists for that email, a reset link is on the way. Resetting the password does not skip the text-message check.';
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

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot password',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          AuthMessageText(_message, isError: _messageIsError),
          FilledButton(
            onPressed: _busy || _sent ? null : _submit,
            child: Text(_busy ? 'Sending…' : 'Send reset link'),
          ),
          TextButton(
            onPressed: () => context.go(AuthRoutes.signIn),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.code});

  final String? code;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _message;
  bool _messageIsError = true;
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = widget.code;
    if (code == null || code.isEmpty) return;
    if (_password.text.length < 6) {
      setState(() {
        _message = 'Use at least 6 characters.';
        _messageIsError = true;
      });
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() {
        _message = 'Passwords do not match.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).confirmPasswordReset(
            code: code,
            newPassword: _password.text,
          );
      setState(() {
        _done = true;
        _messageIsError = false;
        _message = 'Password updated. Sign in with the new password.';
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

  @override
  Widget build(BuildContext context) {
    final missingCode = widget.code == null || widget.code!.isEmpty;
    return AuthScaffold(
      title: 'Reset password',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (missingCode)
            const Text(
              'Open the reset link from your email, or request a new one.',
            )
          else ...[
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              onSubmitted: (_) => _submit(),
            ),
          ],
          const SizedBox(height: 16),
          AuthMessageText(_message, isError: _messageIsError),
          if (!missingCode)
            FilledButton(
              onPressed: _busy || _done ? null : _submit,
              child: Text(_busy ? 'Updating…' : 'Update password'),
            ),
          TextButton(
            onPressed: () => context.go(
              missingCode ? AuthRoutes.forgotPassword : AuthRoutes.signIn,
            ),
            child: Text(missingCode ? 'Request a new link' : 'Back to sign in'),
          ),
        ],
      ),
    );
  }
}
