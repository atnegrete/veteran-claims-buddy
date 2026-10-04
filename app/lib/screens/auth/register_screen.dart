import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_failure.dart';
import '../../auth/auth_redirect.dart';
import '../../forms/text_input_chain.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .createAccount(email: _email.text, password: _password.text);
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validate() {
    if (!_email.text.contains('@')) return 'Enter a valid email address.';
    if (_password.text.length < 6) return 'Use at least 6 characters.';
    if (_password.text != _confirm.text) return 'Passwords do not match.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create account',
      child: TextInputChain(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(independentProductDisclaimer),
            const SizedBox(height: 16),
            ChainTextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              maxLength: 254,
              countVisibleFrom: authCountVisibleFrom,
            ),
            const SizedBox(height: 12),
            ChainTextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'Password'),
              maxLength: 128,
              countVisibleFrom: authCountVisibleFrom,
            ),
            const SizedBox(height: 12),
            ChainTextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              maxLength: 128,
              countVisibleFrom: authCountVisibleFrom,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            AuthMessageText(_error),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Creating account…' : 'Create account'),
            ),
            TextButton(
              onPressed: () => context.go(AuthRoutes.signIn),
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
