import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_ui.dart';
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
    final active = items.where((item) => item.isOpen).toList();
    final historical = items.where((item) => !item.isOpen).toList();
    return ShellPage(
      title: 'Claims',
      wrapInCard: false,
      child: cases.isLoading && items.isEmpty
          ? const SurfaceCard(child: LeadText('Opening your claim.'))
          : active.isEmpty && historical.isEmpty
          ? SurfaceCard(child: _EmptyCases(error: error))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (active.isNotEmpty)
                  SurfaceCard(
                    child: _CaseList(
                      cases: active,
                      workingId: workingId,
                      showOpenBadge: true,
                    ),
                  ),
                if (historical.isNotEmpty) ...[
                  if (active.isNotEmpty) const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Completed claims',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const LeadText(
                          'You can always open and download a completed claim, even after Premium ends.',
                        ),
                        const SizedBox(height: 12),
                        _CaseList(
                          cases: historical,
                          workingId: workingId,
                          showOpenBadge: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _CaseList extends StatelessWidget {
  const _CaseList({
    required this.cases,
    required this.workingId,
    required this.showOpenBadge,
  });

  final List<VeteranCase> cases;
  final String? workingId;
  final bool showOpenBadge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in cases) ...[
          AppNavRow(
            title: caseDisplayName(item.displayName),
            subtitle: showOpenBadge && item.id == workingId
                ? '${caseStatusLabel(item.status)} · Open'
                : caseStatusLabel(item.status),
            selected: showOpenBadge && item.id == workingId,
            onTap: () => context.go(AuthRoutes.caseStep(item.id)),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _EmptyCases extends ConsumerWidget {
  const _EmptyCases({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (error == null) return const LeadText('Opening your claim.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ErrorText(error!),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => ref.read(caseEnsureProvider.notifier).retry(),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}
