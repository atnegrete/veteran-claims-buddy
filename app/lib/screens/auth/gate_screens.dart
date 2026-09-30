import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../account/account_deletion.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_failure.dart';
import '../../auth/auth_redirect.dart';
import 'auth_scaffold.dart';

class AccountRecoveryScreen extends StatelessWidget {
  const AccountRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Account recovery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'There is no self-serve way to skip the text-message check. Email $supportEmail and we will verify it is you before anyone changes the phone on the account.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Do not send a Social Security number or medical records in that email.',
          ),
          TextButton(
            onPressed: () => context.go(AuthRoutes.signIn),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

class AccountReactivateScreen extends ConsumerStatefulWidget {
  const AccountReactivateScreen({super.key});

  @override
  ConsumerState<AccountReactivateScreen> createState() =>
      _AccountReactivateScreenState();
}

class _AccountReactivateScreenState
    extends ConsumerState<AccountReactivateScreen> {
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _reactivate() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .reauthenticate(_password.text);
      await ref.read(accountDeletionClientProvider).cancel();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on AccountDeletionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reactivate account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(deletionWarning),
          const SizedBox(height: 12),
          const Text(
            'Other pages stay closed until you reactivate. Enter your password to keep the account.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _password.text.isEmpty ? null : _reactivate,
            child: Text(_busy ? 'Reactivating…' : 'Reactivate'),
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
