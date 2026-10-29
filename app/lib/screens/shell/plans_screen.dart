import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../billing/billing_repository.dart';
import '../../billing/entitlement_service.dart';
import '../../billing/premium_status_view.dart';
import '../../billing/revenuecat_service.dart';
import '../../auth/auth_redirect.dart';
import 'shell_pages.dart';
import 'signed_in_bar.dart';

/// Lead sentence for `/plans`, based on why the page was opened.
String plansLead({String? reason}) {
  switch (reason) {
    case 'symptoms':
      return 'Adding a symptom event needs Premium.';
    case 'package':
      return 'Generating a claim package needs Premium, or a one-time unlock for that case.';
    case 'form':
      return 'Downloading a filled form needs Premium, or a one-time unlock for that case.';
    default:
      return 'Premium and a one-time Case unlock are two ways to generate a claim package.';
  }
}

/// One feature line in a plan column. [included] draws a check or a dash.
class _Feature {
  const _Feature(this.label, {this.included = true});

  final String label;
  final bool included;
}

const _workspaceFeatures = <_Feature>[
  _Feature('Build your claim: questions, issues, documents'),
  _Feature('Vet Buddy guidance'),
  _Feature('VA ratings calculator'),
  _Feature('Generate the VA claim package', included: false),
  _Feature('Symptom Tracker entries', included: false),
];

const _caseFeatures = <_Feature>[
  _Feature('Everything in the free workspace'),
  _Feature('One year of Premium for a single case'),
  _Feature('Generate the package and later reviews for that case'),
  _Feature('Symptom Tracker and every Premium feature'),
  _Feature('Covers one active case at a time'),
];

const _premiumFeatures = <_Feature>[
  _Feature('Everything in the free workspace'),
  _Feature('Generate the package for every case'),
  _Feature('Later reviews of every case'),
  _Feature('Symptom Tracker entries'),
  _Feature('Billed monthly or yearly. Cancel anytime.'),
];

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key, this.reason, this.caseId});

  final String? reason;
  final String? caseId;

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  bool _busy = false;
  String? _notice;

  Future<void> _startCheckout() async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    final billing = ref.read(billingRepositoryProvider);
    String? notice;

    // When the page is opened for a specific case, record a pending Case-unlock
    // intent first so the webhook binds a Case-unlock purchase to this case. A
    // Premium subscription bought in the same sheet simply ignores the intent.
    if (widget.caseId != null) {
      try {
        await billing.createPurchaseIntent(widget.caseId!);
      } on BillingFailure catch (error) {
        notice = error.message;
      }
    }

    final revenueCat = ref.read(revenueCatServiceProvider);
    if (revenueCat.isSupported) {
      final result = await revenueCat.presentPaywall();
      if (result == null && notice == null) {
        notice = 'Plans are not available in this build yet.';
      }
    } else {
      final uri = billing.webPurchaseUri();
      if (uri == null) {
        notice = 'Checkout is not available yet.';
      } else {
        final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!opened) notice = 'Checkout could not be opened.';
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = notice;
    });
  }

  Widget _manageCta(BuildContext context, PremiumStatus premium) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        InfoNote(
          tone: InfoNoteTone.success,
          text: premium.subscriptionActive
              ? 'Premium is active on your account.'
              : 'A Case unlock is active. It covers one case for a year.',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go(AuthRoutes.billingPremium),
          child: const Text('Manage billing'),
        ),
      ],
    );
  }

  Widget _buyCta(BuildContext context, PremiumStatus premium) {
    final until = premium.premiumUntil;
    final endedOn = until == null
        ? ''
        : ' on ${MaterialLocalizations.of(context).formatMediumDate(until.toLocal())}';
    final kind = premium.source == 'caseUnlock' ? 'Case unlock' : 'Premium';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (premium.expired) ...[
          const SizedBox(height: 12),
          InfoNote(text: 'Looks like your $kind expired$endedOn. Renew below.'),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _startCheckout,
          child: Text(
            _busy ? 'Opening…' : (premium.expired ? 'Renew' : 'Choose a plan'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final premiumAsync = ref.watch(premiumStatusProvider);

    final columns = <Widget>[
      const _PlanColumn(
        name: 'Free workspace',
        price: 'Free',
        tagline: 'Organize everything before you pay.',
        features: _workspaceFeatures,
      ),
      const _PlanColumn(
        name: 'Case unlock',
        price: '\$250',
        cadence: 'one-time, one case',
        tagline: 'One year of Premium for a single claim.',
        features: _caseFeatures,
      ),
      const _PlanColumn(
        name: 'Premium',
        price: '\$29.99',
        cadence: 'per month',
        tagline: 'Every case, plus symptom tracking.',
        features: _premiumFeatures,
        badge: 'Most coverage',
        footnote: 'Or \$234.99 a year — save 34%.',
      ),
    ];
    return ShellPage(
      title: 'Plans',
      wrapInCard: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plansLead(reason: widget.reason),
                  style: theme.textTheme.titleLarge,
                ),
                premiumAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: PremiumStatusLoading(),
                  ),
                  error: (_, _) => _buyCta(context, PremiumStatus.inactive),
                  data: (premium) => premium.isActive
                      ? _manageCta(context, premium)
                      : _buyCta(context, premium),
                ),
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  InfoNote(text: _notice!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 720) {
                return Column(
                  children: [
                    for (final column in columns) ...[
                      column,
                      if (column != columns.last) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < columns.length; i++) ...[
                    Expanded(child: columns[i]),
                    if (i < columns.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlanColumn extends StatelessWidget {
  const _PlanColumn({
    required this.name,
    required this.price,
    required this.tagline,
    required this.features,
    this.cadence,
    this.badge,
    this.footnote,
  });

  final String name;
  final String price;
  final String? cadence;
  final String tagline;
  final List<_Feature> features;
  final String? badge;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: theme.textTheme.titleLarge)),
              if (badge != null) AppBadge.primary(label: badge!),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppColors.sand,
                ),
              ),
              if (cadence != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cadence!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tagline,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 4),
            Text(
              footnote!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          for (final feature in features) _FeatureRow(feature: feature),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final included = feature.included;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            included ? Icons.check : Icons.remove,
            size: 18,
            color: included ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feature.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: included ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
