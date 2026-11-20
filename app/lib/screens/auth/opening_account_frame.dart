import 'package:flutter/material.dart';

import '../../app/app_ui.dart';
import 'auth_scaffold.dart';

/// Waiting frame for a phone that is already enrolled.
///
/// The enroll form stays off this frame. It shows only while the server
/// marker is still being confirmed, including when that check fails.
class OpeningAccountFrame extends StatelessWidget {
  const OpeningAccountFrame({
    super.key,
    required this.failed,
    required this.onRetry,
    required this.onSignOut,
  });

  final bool failed;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Opening your account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!failed)
            const Center(child: CircularProgressIndicator())
          else ...[
            const ErrorText('Security setup did not finish. Try again.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
          TextButton(onPressed: onSignOut, child: const Text('Sign out')),
        ],
      ),
    );
  }
}
