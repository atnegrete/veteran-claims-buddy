import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_redirect.dart';
import '../../cases/cases_progress.dart';
import '../../home/home_snapshot.dart';
import 'shell_pages.dart';
import 'signed_in_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeSnapshotProvider);
    return ShellPage(
      title: 'Home',
      wrapInCard: false,
      child: Column(
        children: [
          _WorkingCaseSection(home: home),
          const SizedBox(height: 12),
          _NextActionSection(home: home),
          const SizedBox(height: 12),
          _DeadlinesSection(home: home),
          const SizedBox(height: 12),
          _QuickLinks(premiumActive: home.premiumActive),
          if (!home.premiumActive) ...[
            const SizedBox(height: 12),
            const _PremiumSection(),
          ],
        ],
      ),
    );
  }
}

class _WorkingCaseSection extends StatelessWidget {
  const _WorkingCaseSection({required this.home});

  final HomeSnapshot home;

  @override
  Widget build(BuildContext context) {
    final working = home.workingCase;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Working case', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (working == null)
            const _OpeningCase()
          else ...[
            Text(working.displayName),
            const SizedBox(height: 4),
            Text(working.statusLabel),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AuthRoutes.caseOverview(working.id)),
              child: const Text('Open case'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpeningCase extends ConsumerWidget {
  const _OpeningCase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(caseEnsureProvider);
    if (error == null) {
      return const Text('Opening your case.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => ref.read(caseEnsureProvider.notifier).retry(),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _NextActionSection extends StatelessWidget {
  const _NextActionSection({required this.home});

  final HomeSnapshot home;

  @override
  Widget build(BuildContext context) {
    final action = home.nextAction;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Next action', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            action?.title ?? 'There is no next step until a case exists.',
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(action.path),
              child: const Text('Open'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeadlinesSection extends StatelessWidget {
  const _DeadlinesSection({required this.home});

  final HomeSnapshot home;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Deadlines', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (home.deadlines.isEmpty)
            const Text(
              'No deadlines. Dates from other cases show here, without medical details.',
            )
          else
            for (final deadline in home.deadlines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(deadline.title),
                subtitle: Text(deadline.whenLabel),
                onTap: () => context.go(deadline.path),
              ),
        ],
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.premiumActive});

  final bool premiumActive;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quick links', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Calculator'),
            subtitle: const Text('Combined rating estimate. It does not change a case.'),
            onTap: () => context.go(AuthRoutes.calculator),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add symptom event'),
            subtitle: const Text('Premium is required to add one.'),
            onTap: () => context.go(
              symptomDestination(premiumActive: premiumActive),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vet Buddy'),
            onTap: () => context.go(AuthRoutes.buddy),
          ),
        ],
      ),
    );
  }
}

class _PremiumSection extends StatelessWidget {
  const _PremiumSection();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Premium', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Premium is \$30 a month. A single Case unlock is \$250.',
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
