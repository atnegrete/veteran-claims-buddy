import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../account/account_deletion.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_failure.dart';
import '../../auth/auth_redirect.dart';
import '../../forms/form_actions.dart';
import 'auth_scaffold.dart';

class AccountRecoveryScreen extends StatelessWidget {
  const AccountRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      eyebrow: 'Help',
      title: 'Account recovery',
      lead:
          "The text-message check can't be skipped. Email $supportEmail and we'll verify it's you before changing the phone.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoNote(
            text: 'Do not send a Social Security number or medical records in that email.',
          ),
          FormActions(onBack: () => context.go(AuthRoutes.signIn)),
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
      eyebrow: 'Account',
      title: 'Reactivate account',
      lead: 'Other pages stay closed until you reactivate. Enter your password to keep the account.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoNote(text: deletionWarning),
          const SizedBox(height: 16),
          PasswordField(
            controller: _password,
            label: 'Password',
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _reactivate(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorText(_error!),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _password.text.isEmpty ? null : _reactivate,
            child: Text(_busy ? 'Reactivating…' : 'Reactivate'),
          ),
          const SizedBox(height: 8),
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
