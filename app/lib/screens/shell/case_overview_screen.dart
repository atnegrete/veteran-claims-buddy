import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_redirect.dart';
import '../../cases/cases_progress.dart';
import '../../cases/cases_repository.dart';
import '../../cases/veteran_case.dart';
import 'shell_pages.dart';
import 'signed_in_bar.dart';

class CaseOverviewScreen extends ConsumerStatefulWidget {
  const CaseOverviewScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<CaseOverviewScreen> createState() => _CaseOverviewScreenState();
}

class _CaseOverviewScreenState extends ConsumerState<CaseOverviewScreen> {
  var _busy = false;
  String? _error;

  Future<void> _use() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(casesRepositoryProvider).setWorkingCase(widget.caseId);
    } on CaseFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cases = ref.watch(casesProvider);
    final workingId = ref.watch(workingCaseIdProvider);
    final items = cases.maybeWhen(
      data: (value) => value,
      orElse: () => const <VeteranCase>[],
    );
    VeteranCase? item;
    for (final candidate in items) {
      if (candidate.id == widget.caseId) item = candidate;
    }
    if (cases.isLoading && item == null) {
      return const ShellPage(
        title: 'Case',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (item == null) {
      return ShellPage(
        title: 'Case',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('That case is not on this account.'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(AuthRoutes.cases),
              child: const Text('All cases'),
            ),
          ],
        ),
      );
    }
    final working = item.id == workingId;
    return ShellPage(
      title: caseDisplayName(item.displayName),
      wrapInCard: false,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(caseStatusLabel(item.status)),
            const SizedBox(height: 8),
            Text(
              working
                  ? 'This is the working case. The Case tab opens here.'
                  : 'This is not the working case.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Issues, evidence, exams, and the claim package are still closed. Nothing here is filed with the VA.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            if (!working)
              FilledButton(
                onPressed: _busy ? null : _use,
                child: Text(_busy ? 'Saving…' : 'Use this case'),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go(AuthRoutes.cases),
                child: const Text('All cases'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
