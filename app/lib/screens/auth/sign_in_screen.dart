import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_failure.dart';
import '../../auth/auth_redirect.dart';
import 'auth_scaffold.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      await ref.read(authControllerProvider.notifier).signIn(
            email: _email.text,
            password: _password.text,
          );
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validate() {
    if (!_email.text.contains('@')) return 'Enter a valid email address.';
    if (_password.text.length < 6) return 'Use at least 6 characters.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Sign in',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          AuthMessageText(_error),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Signing in…' : 'Sign in'),
          ),
          TextButton(
            onPressed: () => context.go(AuthRoutes.forgotPassword),
            child: const Text('Forgot password'),
          ),
          TextButton(
            onPressed: () => context.go(AuthRoutes.register),
            child: const Text('Create account'),
          ),
          TextButton(
            onPressed: () => context.go(AuthRoutes.recovery),
            child: const Text('Lost your phone?'),
          ),
        ],
      ),
    );
  }
}
