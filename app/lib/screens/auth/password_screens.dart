import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_failure.dart';
import '../../auth/auth_redirect.dart';
import '../../forms/form_actions.dart';
import '../../forms/text_input_chain.dart';
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
        _message = 'If an account exists, a reset link is on the way.';
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
      eyebrow: 'Account',
      title: 'Forgot password',
      lead: 'A reset link is emailed when an account exists. The text-message check still applies.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChainTextField(
            controller: _email,
            enabled: !_sent && !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            maxLength: 254,
            countVisibleFrom: authCountVisibleFrom,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          AuthMessageText(_message, isError: _messageIsError),
          FormActions(
            onBack: () => context.go(AuthRoutes.signIn),
            onPrimary: _sent ? null : _submit,
            primaryLabel: 'Send reset link',
            busy: _busy,
            busyLabel: 'Sending…',
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
      await ref
          .read(authControllerProvider.notifier)
          .confirmPasswordReset(code: code, newPassword: _password.text);
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
      eyebrow: 'Account',
      title: 'Reset password',
      lead: missingCode
          ? 'Open the reset link from your email, or request a new one.'
          : 'Choose a new password for this account.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!missingCode)
            TextInputChain(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasswordField(
                    controller: _password,
                    label: 'New password',
                    enabled: !_done && !_busy,
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _confirm,
                    label: 'Confirm password',
                    enabled: !_done && !_busy,
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
          if (!missingCode) const SizedBox(height: 16),
          AuthMessageText(_message, isError: _messageIsError),
          FormActions(
            onBack: () => context.go(AuthRoutes.signIn),
            onPrimary: missingCode
                ? () => context.go(AuthRoutes.forgotPassword)
                : _done
                ? null
                : _submit,
            primaryLabel: missingCode
                ? 'Request a new link'
                : 'Update password',
            busy: _busy,
            busyLabel: 'Updating…',
          ),
        ],
      ),
    );
  }
}
