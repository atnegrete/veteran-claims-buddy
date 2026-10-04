import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/account_deletion.dart';
import '../../app/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_failure.dart';
import '../../forms/text_input_chain.dart';
import 'shell_pages.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  var _understood = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _schedule() async {
    if (_password.text.isEmpty || !_understood) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .reauthenticate(_password.text);
      await ref.read(accountDeletionClientProvider).schedule();
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
    final canSubmit = _understood && _password.text.isNotEmpty && !_busy;
    return ShellPage(
      title: 'Delete account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(deletionWarning),
          const SizedBox(height: 12),
          const Text(
            'Deleting the account does not cancel Premium. Cancel it in the App Store, Google Play, or on the web billing page. A Print & Mail order already sent still prints and is non-refundable.',
          ),
          const SizedBox(height: 16),
          ChainTextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            maxLength: 128,
            countVisibleFrom: authCountVisibleFrom,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _understood,
            onChanged: _busy
                ? null
                : (value) => setState(() => _understood = value ?? false),
            title: const Text(
              'I understand this schedules deletion in 30 days.',
            ),
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
            style: dangerFilledStyle(),
            onPressed: canSubmit ? _schedule : null,
            child: Text(_busy ? 'Scheduling…' : 'Schedule deletion'),
          ),
        ],
      ),
    );
  }
}
