import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../billing/billing_repository.dart';
import '../../billing/entitlement_service.dart';
import '../../billing/premium_status_view.dart';
import '../../billing/revenuecat_service.dart';
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
                if (session?.email != null)
                  Text(
                    session!.email!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                if (session?.maskedPhone != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    session!.maskedPhone!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 4),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppNavRow(title: title, onTap: onTap),
    );
  }
}

String _formatDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
}

class BillingPremiumScreen extends ConsumerWidget {
  const BillingPremiumScreen({super.key});

  Future<void> _manage(BuildContext context, WidgetRef ref) async {
    final billing = ref.read(billingRepositoryProvider);
    final uri = billing.customerPortalUri();
    if (uri == null) {
      if (!context.mounted) return;
      // No static portal URL: mobile subscriptions are managed in the store,
      // and web (RevenueCat Billing) subscribers get a management link in their
      // billing email.
      final message = kIsWeb
          ? 'To manage or cancel, open the management link in your subscription '
              'email from RevenueCat Billing.'
          : 'Manage or cancel your subscription in the App Store or Google Play.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    await ref.read(revenueCatServiceProvider).restorePurchases();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checked for past purchases.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShellPage(
      title: 'Billing',
      wrapInCard: false,
      child: PremiumStatusBuilder(
        builder: (context, premium) => _body(context, ref, premium),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, PremiumStatus premium) {
    final supportsStore = ref.read(revenueCatServiceProvider).isSupported;

    final String statusLine;
    if (premium.subscriptionActive) {
      final until = premium.premiumUntil;
      statusLine = until == null
          ? 'Premium is active.'
          : premium.willRenew
              ? 'Premium is active. It renews on ${_formatDate(context, until)}.'
              : 'Premium is active until ${_formatDate(context, until)}.';
    } else if (premium.fromCaseUnlock) {
      final until = premium.premiumUntil;
      statusLine = until == null
          ? 'A Case unlock is active.'
          : 'A Case unlock gives you Premium for one case until ${_formatDate(context, until)}.';
    } else {
      statusLine = 'Premium is not active.';
    }

    return Column(
      children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (premium.expired)
                  ExpiredPremiumNotice(
                    status: premium,
                    onRenew: () =>
                        context.go('${AuthRoutes.plans}?reason=home'),
                  )
                else ...[
                  LeadText(statusLine),
                  if (premium.fromCaseUnlock) ...[
                    const SizedBox(height: 12),
                    const InfoNote(
                      text:
                          'A Case unlock covers one active case at a time. Complete it to unlock another, or go Premium for every case.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (premium.isActive)
                    OutlinedButton(
                      onPressed: () => _manage(context, ref),
                      child: const Text('Manage subscription'),
                    )
                  else
                    FilledButton(
                      onPressed: () =>
                          context.go('${AuthRoutes.plans}?reason=home'),
                      child: const Text('Compare plans'),
                    ),
                ],
                if (supportsStore) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _restore(context, ref),
                    child: const Text('Restore purchases'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LeadText('See the cases you have unlocked.'),
                const SizedBox(height: 16),
                FilledButton(
                  style: secondaryFilledStyle(),
                  onPressed: () => context.go(AuthRoutes.billingCases),
                  child: const Text('Unlocked cases'),
                ),
              ],
            ),
          ),
        ],
    );
  }
}

class BillingCasesScreen extends ConsumerWidget {
  const BillingCasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref
        .watch(caseUnlocksProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <String>{});
    final cases = ref
        .watch(casesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <VeteranCase>[]);
    final unlockedCases = cases.where((item) => unlocked.contains(item.id)).toList();

    return ShellPage(
      title: 'Unlocked cases',
      child: unlockedCases.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LeadText(
                  'No case is unlocked. A claim package needs Premium, or a one-time unlock for that case.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('${AuthRoutes.plans}?reason=home'),
                  child: const Text('Compare plans'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LeadText(
                  'A Case unlock gives one case a year of Premium. You keep completed cases forever.',
                ),
                const SizedBox(height: 12),
                for (final item in unlockedCases) ...[
                  AppNavRow(
                    title: caseDisplayName(item.displayName),
                    subtitle: caseStatusLabel(item.status),
                    onTap: () => context.go(AuthRoutes.caseStep(item.id)),
                  ),
                  const SizedBox(height: 8),
                ],
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
      child: LeadText(
        'Privacy, terms, subscription terms, refunds, and the AI disclosure are published on our website.',
      ),
    );
  }
}
