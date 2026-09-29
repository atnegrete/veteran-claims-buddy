import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import 'auth_scaffold.dart';

class MfaEnrollScreen extends ConsumerWidget {
  const MfaEnrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      title: 'Add a phone number',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your email is verified. A phone number is required before any claim information. Veteran Claims Buddy uses it only as a second sign-in check.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Text-message enrollment is not open yet. This app still needs phone verification registered with Firebase. Sign out and return after that setup is finished.',
          ),
          const SizedBox(height: 16),
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

class MfaChallengeScreen extends ConsumerWidget {
  const MfaChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      title: 'Text-message check',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This account needs its text-message code to finish signing in. Sending that code is not available until phone verification is registered for this app.',
          ),
          const SizedBox(height: 12),
          const Text(
            'A password reset does not skip this check. If you lost the phone, contact support.',
          ),
          TextButton(
            onPressed: () => context.go(AuthRoutes.recovery),
            child: const Text('Lost your phone?'),
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
    return AuthScaffold(
      title: 'Onboarding',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Phone enrollment is confirmed. Onboarding is the next step and is not open yet.',
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
