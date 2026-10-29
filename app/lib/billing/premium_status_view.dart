import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_ui.dart';
import 'entitlement_service.dart';

/// A quiet loading indicator shown while the server-authoritative Premium
/// projection is still resolving (auth restoring after a reload, then the first
/// Firestore snapshot).
///
/// Screens show this instead of flashing the inactive/plans view on load. The
/// label stays muted (`onSurfaceVariant`) per the color rules — no color on the
/// text, just a small spinner.
class PremiumStatusLoading extends StatelessWidget {
  const PremiumStatusLoading({super.key, this.label = 'Checking your plan…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A friendly card shown when the account held Premium before and it lapsed.
///
/// Renders the kind of plan that expired, the (user-friendly) end date, and a
/// Renew button that returns the Veteran to the paywall. Only show it when
/// [PremiumStatus.expired] is true; it renders nothing otherwise.
class ExpiredPremiumNotice extends StatelessWidget {
  const ExpiredPremiumNotice({
    super.key,
    required this.status,
    required this.onRenew,
    this.renewLabel = 'Renew',
  });

  final PremiumStatus status;
  final VoidCallback onRenew;
  final String renewLabel;

  @override
  Widget build(BuildContext context) {
    if (!status.expired) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final kind = status.source == 'caseUnlock' ? 'Case unlock' : 'Premium';
    final until = status.premiumUntil;
    final endedOn = until == null
        ? ''
        : ' on ${MaterialLocalizations.of(context).formatMediumDate(until.toLocal())}';
    return InfoNote(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Looks like your $kind expired$endedOn.',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Renew to turn your Premium features back on.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onRenew,
              child: Text(renewLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Watches [premiumStatusProvider] and builds with the resolved [PremiumStatus],
/// showing [PremiumStatusLoading] while it resolves so no screen assumes Premium
/// is inactive during load. An error resolves to [PremiumStatus.inactive] (the
/// safe default) so gating never opens on a failed read.
class PremiumStatusBuilder extends ConsumerWidget {
  const PremiumStatusBuilder({super.key, required this.builder, this.loading});

  final Widget Function(BuildContext context, PremiumStatus status) builder;
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(premiumStatusProvider)
        .when(
          loading: () => loading ?? const PremiumStatusLoading(),
          error: (_, _) => builder(context, PremiumStatus.inactive),
          data: (status) => builder(context, status),
        );
  }
}
