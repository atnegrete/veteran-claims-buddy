import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_redirect.dart';
import '../../cases/cases_progress.dart';
import '../../cases/veteran_case.dart';
import 'shell_pages.dart';
import 'signed_in_bar.dart';

class CasesScreen extends ConsumerWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(casesProvider);
    final workingId = ref.watch(workingCaseIdProvider);
    final error = ref.watch(caseEnsureProvider);
    final items = cases.maybeWhen(
      data: (value) => value,
      orElse: () => const <VeteranCase>[],
    );
    return ShellPage(
      title: 'Claims',
      wrapInCard: false,
      child: SurfaceCard(
        child: cases.isLoading && items.isEmpty
            ? const Text('Opening your claim.')
            : items.isEmpty
            ? _EmptyCases(error: error)
            : Column(
                children: [
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(caseDisplayName(item.displayName)),
                      subtitle: Text(
                        item.id == workingId
                            ? '${caseStatusLabel(item.status)} · Open'
                            : caseStatusLabel(item.status),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(AuthRoutes.caseStep(item.id)),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EmptyCases extends ConsumerWidget {
  const _EmptyCases({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (error == null) return const Text('Opening your claim.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => ref.read(caseEnsureProvider.notifier).retry(),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}
