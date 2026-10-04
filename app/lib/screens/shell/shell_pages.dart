import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_redirect.dart';
import '../../cases/cases_progress.dart';
import 'signed_in_bar.dart';

class ShellPage extends StatelessWidget {
  const ShellPage({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.wrapInCard = true,
    this.expandChild = false,
    this.maxWidth = 720,
  });

  final String title;
  final Widget child;

  /// Stays at the bottom of the card while [child] scrolls.
  final Widget? footer;

  final bool wrapInCard;

  /// The child receives the card's height and handles its own scrolling.
  final bool expandChild;

  /// The page column stays this wide. Pass [double.infinity] to fill the pane.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final body = expandChild
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: SingleChildScrollView(child: child)),
              if (footer != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                footer!,
              ],
            ],
          );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                Expanded(child: wrapInCard ? SurfaceCard(child: body) : body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EarlierClaimNote extends ConsumerWidget {
  const EarlierClaimNote({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openId = ref.watch(workingCaseIdProvider);
    if (openId == null || openId == caseId) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'This is an earlier claim. Your open claim is still the one that opens when you sign in.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.go(AuthRoutes.caseStep(openId)),
            child: const Text('Back to your open claim'),
          ),
        ),
      ],
    );
  }
}
