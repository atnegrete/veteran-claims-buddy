import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
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

class AccountReactivateScreen extends ConsumerWidget {
  const AccountReactivateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      title: 'Reactivate account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This account is scheduled for deletion. Other pages stay closed during that period. Reactivation is not available in this version yet.',
          ),
          TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class OnboardingHoldScreen extends ConsumerWidget {
  const OnboardingHoldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maskedPhone = ref.watch(authControllerProvider).session?.maskedPhone;
    return AuthScaffold(
      title: 'Onboarding',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Phone enrollment is confirmed. Onboarding is the next step and is not open yet.',
          ),
          if (maskedPhone != null) ...[
            const SizedBox(height: 12),
            Text(maskedPhone),
          ],
          TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
