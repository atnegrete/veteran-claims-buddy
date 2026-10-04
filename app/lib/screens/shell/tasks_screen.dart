import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_redirect.dart';
import '../../app/app_badge.dart';
import '../../claim/next_action_repository.dart';
import 'shell_pages.dart';

/// The stored current step. Not a section in the claim list.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(claimTaskProvider(caseId));
    return ShellPage(
      title: 'Current step',
      child: task.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('That step could not be loaded.'),
        data: (value) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (value == null)
                const Text('The current step is on your claim.')
              else ...[
                Text(
                  value.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(value.description),
                const SizedBox(height: 12),
                const AppBadge.notFiled(),
                if (value.route != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go(value.route!),
                    child: const Text('Open'),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go(AuthRoutes.caseTimeline(caseId)),
                child: const Text('Timeline'),
              ),
            ],
          );
        },
      ),
    );
  }
}
