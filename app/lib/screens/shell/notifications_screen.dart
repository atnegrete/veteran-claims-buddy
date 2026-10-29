import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/notification_preferences.dart';
import '../../app/app_ui.dart';
import 'shell_pages.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider);
    return preferences.when(
      loading: () => const ShellPage(
        title: 'Notifications',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const ShellPage(
        title: 'Notifications',
        child: Text('Notification choices could not be opened. Try again.'),
      ),
      data: (value) => _NotificationForm(initial: value),
    );
  }
}

class _NotificationForm extends ConsumerStatefulWidget {
  const _NotificationForm({required this.initial});

  final NotificationPreferences initial;

  @override
  ConsumerState<_NotificationForm> createState() => _NotificationFormState();
}

class _NotificationFormState extends ConsumerState<_NotificationForm> {
  late bool _exams;
  late bool _tasks;
  String? _error;

  @override
  void initState() {
    super.initState();
    _exams = widget.initial.examReminders;
    _tasks = widget.initial.taskReminders;
  }

  Future<void> _save({bool? exams, bool? tasks}) async {
    final next = NotificationPreferences(
      examReminders: exams ?? _exams,
      taskReminders: tasks ?? _tasks,
    );
    setState(() {
      _exams = next.examReminders;
      _tasks = next.taskReminders;
      _error = null;
    });
    try {
      await ref.read(saveNotificationPreferencesProvider)(next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exams = widget.initial.examReminders;
        _tasks = widget.initial.taskReminders;
        _error = 'That could not be saved. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShellPage(
      title: 'Notifications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LeadText(
            'Reminders arrive as push notifications. The lock screen stays general and never names a condition or claim.',
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Exam reminders'),
            value: _exams,
            onChanged: (value) => _save(exams: value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Task reminders'),
            value: _tasks,
            onChanged: (value) => _save(tasks: value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorText(_error!),
          ],
        ],
      ),
    );
  }
}
