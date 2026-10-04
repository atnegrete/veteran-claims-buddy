import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../cases/cases_progress.dart';
import '../../cases/veteran_case.dart';
import 'shell_pages.dart';
import 'signed_in_bar.dart';

class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final claimCount = activeCaseCount(
      ref
          .watch(casesProvider)
          .maybeWhen(
            data: (value) => value,
            orElse: () => const <VeteranCase>[],
          ),
    );
    return ShellPage(
      title: 'Account',
      wrapInCard: false,
      child: Column(
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (session?.email != null) Text(session!.email!),
                if (session?.maskedPhone != null) ...[
                  const SizedBox(height: 8),
                  Text(session!.maskedPhone!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              children: [
                _YouLink(
                  title: 'Support',
                  onTap: () => context.go(AuthRoutes.support),
                ),
                _YouLink(
                  title: 'Billing',
                  onTap: () => context.go(AuthRoutes.billingPremium),
                ),
                _YouLink(
                  title: 'Profile',
                  onTap: () => context.go(AuthRoutes.profile),
                ),
                _YouLink(
                  title: 'Security',
                  onTap: () => context.go(AuthRoutes.security),
                ),
                _YouLink(
                  title: 'Notifications',
                  onTap: () => context.go(AuthRoutes.notifications),
                ),
                _YouLink(
                  title: 'Legal',
                  onTap: () => context.go(AuthRoutes.legal),
                ),
                if (claimCount > 1)
                  _YouLink(
                    title: 'Claims',
                    onTap: () => context.go(AuthRoutes.cases),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              style: dangerTextStyle(),
              onPressed: () => context.go(AuthRoutes.deleteAccount),
              child: const Text('Delete account'),
            ),
          ),
        ],
      ),
    );
  }
}

class _YouLink extends StatelessWidget {
  const _YouLink({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class BillingPremiumScreen extends StatelessWidget {
  const BillingPremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShellPage(
      title: 'Billing',
      wrapInCard: false,
      child: Column(
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Premium is not active.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      context.go('${AuthRoutes.plans}?reason=home'),
                  child: const Text('Compare plans'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('No case is unlocked.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(AuthRoutes.billingCases),
                  child: const Text('Case unlocks'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BillingCasesScreen extends StatelessWidget {
  const BillingCasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShellPage(
      title: 'Case unlocks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'No case is unlocked. A claim package needs Premium, or a one-time unlock for that case.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('${AuthRoutes.plans}?reason=home'),
            child: const Text('Compare plans'),
          ),
        ],
      ),
    );
  }
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellPage(
      title: 'Legal',
      child: Text(
        'Privacy, terms, subscription terms, refunds, and the AI disclosure are published on the marketing site. That site is not connected yet.',
      ),
    );
  }
}
