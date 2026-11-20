import 'package:flutter/material.dart';

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
      eyebrow: 'Security',
      title: 'Opening your account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!failed)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            const AuthMessageText('Security setup did not finish. Try again.'),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
          const SizedBox(height: 8),
          AuthTextLink(label: 'Sign out', onPressed: onSignOut),
        ],
      ),
    );
  }
}
