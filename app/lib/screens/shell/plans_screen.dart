import 'package:flutter/material.dart';

import 'shell_pages.dart';
import 'signed_in_bar.dart';

/// Lead sentence for `/plans`, based on why the page was opened.
String plansLead({String? reason}) {
  switch (reason) {
    case 'symptoms':
      return 'Adding a symptom event needs Premium.';
    case 'package':
      return 'Generating a claim package needs Premium, or a one-time unlock for that case.';
    default:
      return 'Premium and a one-time Case unlock are two ways to generate a claim package.';
  }
}

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key, this.reason, this.caseId});

  final String? reason;
  final String? caseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ShellPage(
      title: 'Plans',
      wrapInCard: false,
      child: Column(
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plansLead(reason: reason), style: theme.textTheme.titleMedium),
                if (caseId != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'This page was opened for one case. Paying to unlock that case is not open yet.',
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Buying is not open in this version. Nothing on this page charges a card.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Case unlock — \$250'),
                SizedBox(height: 8),
                Text(
                  'One payment covers digital claim-package generation for that case, including later reviews of the same case. A different case needs its own unlock, unless Premium is active when that package is generated. Files already generated stay available.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Premium — \$30 a month'),
                SizedBox(height: 8),
                Text(
                  'While Premium is active it covers package generation and new symptom entries. There is no annual plan. When it ends, cases, symptom history, and files already generated stay. New symptom entries stop, and a new package needs Premium again or a Case unlock.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
