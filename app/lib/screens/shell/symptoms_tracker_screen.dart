import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../auth/auth_redirect.dart';
import '../../cases/cases_progress.dart';
import '../../claim/claim_issue.dart';
import '../../claim/claim_issue_repository.dart';
import '../../claim/symptom_entry.dart';
import '../../claim/symptom_repository.dart';
import '../../forms/form_actions.dart';
import '../../forms/iso_date_field.dart';
import '../../forms/text_input_chain.dart';
import '../../home/home_snapshot.dart';
import 'shell_pages.dart';

class SymptomsTrackerScreen extends ConsumerWidget {
  const SymptomsTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(homeSnapshotProvider).premiumActive;
    final entries = ref
        .watch(symptomEntriesProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <SymptomEntry>[],
        );
    return ShellPage(
      title: 'Symptoms Tracker',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Track symptoms over time here. This is separate from the questions on your claim. It is not a diagnosis.',
          ),
          if (entries.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('No entries yet.'),
          ] else ...[
            const SizedBox(height: 16),
            for (final entry in entries) ...[
              _EntryTile(entry: entry),
              const SizedBox(height: 8),
            ],
          ],
          if (!premium) ...[
            const SizedBox(height: 8),
            const Text('New entries need Premium.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  context.go(symptomDestination(premiumActive: false)),
              child: const Text('Compare plans'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              onPressed: () => context.go(AuthRoutes.symptomCheckIn),
              child: const Text('Check in'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: secondaryFilledStyle().copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(160, 48)),
              ),
              onPressed: () => context.go(AuthRoutes.symptomEventNew),
              child: const Text('Add an event'),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final SymptomEntry entry;

  @override
  Widget build(BuildContext context) {
    final when = entry.isEvent
        ? '${entry.occurredDate} ${entry.occurredTime}'
        : entry.occurredDate;
    final title = entry.isEvent ? 'Event' : 'Check-in';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('$title · $when'),
      subtitle: Text('Severity ${entry.severity}. ${entry.durationLabel}'),
      onTap: () => context.go(AuthRoutes.symptomEntry(entry.id)),
    );
  }
}

class SymptomFormScreen extends ConsumerStatefulWidget {
  const SymptomFormScreen({super.key, required this.event});

  final bool event;

  @override
  ConsumerState<SymptomFormScreen> createState() => _SymptomFormScreenState();
}

class _SymptomFormScreenState extends ConsumerState<SymptomFormScreen> {
  final _date = TextEditingController();
  final _time = TextEditingController();
  var _severity = 0;
  var _duration = 'underOneHour';
  var _affectedWork = false;
  var _limitedActivity = false;
  var _rested = false;
  var _tookTreatment = false;
  var _conditionId = '';
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _date.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final issues = ref
        .read(claimIssuesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <ClaimIssue>[]);
    final conditionName = _conditionId.isEmpty
        ? ''
        : issues
                  .where((issue) => issue.id == _conditionId)
                  .map((issue) => issue.displayName)
                  .firstOrNull ??
              '';
    final draft = SymptomDraft(
      entryType: widget.event ? 'event' : 'checkIn',
      occurredDate: _date.text,
      occurredTime: widget.event ? _time.text : '',
      severity: _severity,
      duration: _duration,
      affectedWork: _affectedWork,
      limitedActivity: _limitedActivity,
      rested: _rested,
      tookTreatment: _tookTreatment,
      conditionId: conditionName.isEmpty ? '' : _conditionId,
      conditionName: conditionName,
    );
    final error = symptomDraftError(draft);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(saveSymptomEntryProvider)(draft);
      if (mounted) context.go(AuthRoutes.symptoms);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'That entry could not be saved.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(homeSnapshotProvider).premiumActive;
    if (!premium) {
      return ShellPage(
        title: widget.event ? 'Add an event' : 'Check in',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('New entries need Premium.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  context.go(symptomDestination(premiumActive: false)),
              child: const Text('Compare plans'),
            ),
          ],
        ),
      );
    }
    final issues = ref
        .watch(claimIssuesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <ClaimIssue>[]);
    return ShellPage(
      title: widget.event ? 'Add an event' : 'Check in',
      footer: FormActions(
        onBack: () => context.go(AuthRoutes.symptoms),
        onPrimary: _save,
        primaryLabel: 'Save',
        busy: _saving,
      ),
      child: TextInputChain(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            IsoDateField(controller: _date, label: 'Date'),
            if (widget.event) ...[
              const SizedBox(height: 12),
              TimeField(controller: _time, label: 'Time'),
            ],
            const SizedBox(height: 12),
            Text('Severity $_severity'),
            Slider(
              value: _severity.toDouble(),
              max: 10,
              divisions: 10,
              label: '$_severity',
              onChanged: (value) => setState(() => _severity = value.round()),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('duration-$_duration'),
              initialValue: _duration,
              decoration: const InputDecoration(labelText: 'How long'),
              items: [
                for (final item in symptomDurations.entries)
                  DropdownMenuItem(value: item.key, child: Text(item.value)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _duration = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('condition-$_conditionId-${issues.length}'),
              initialValue: _conditionId,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Not tied to a condition'),
                ),
                for (final issue in issues)
                  DropdownMenuItem(
                    value: issue.id,
                    child: Text(issue.displayName),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _conditionId = value);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _affectedWork,
              onChanged: (value) =>
                  setState(() => _affectedWork = value ?? false),
              title: const Text('It affected work'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _limitedActivity,
              onChanged: (value) =>
                  setState(() => _limitedActivity = value ?? false),
              title: const Text('It limited activity'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _rested,
              onChanged: (value) => setState(() => _rested = value ?? false),
              title: const Text('I needed to rest'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _tookTreatment,
              onChanged: (value) =>
                  setState(() => _tookTreatment = value ?? false),
              title: const Text('I used a treatment'),
            ),
          ],
        ),
      ),
    );
  }
}

class SymptomDetailScreen extends ConsumerWidget {
  const SymptomDetailScreen({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref
        .watch(symptomEntriesProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <SymptomEntry>[],
        );
    final entry = entries.where((item) => item.id == entryId).firstOrNull;
    return ShellPage(
      title: entry == null
          ? 'Entry'
          : entry.isEvent
          ? 'Event'
          : 'Check-in',
      footer: FormActions(onBack: () => context.go(AuthRoutes.symptoms)),
      child: entry == null
          ? const Text('That entry is not on this account.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(entry.isEvent ? 'Event' : 'Check-in'),
                const SizedBox(height: 8),
                Text(
                  entry.isEvent
                      ? '${entry.occurredDate} ${entry.occurredTime}'
                      : entry.occurredDate,
                ),
                const SizedBox(height: 8),
                Text('Severity ${entry.severity}'),
                Text(entry.durationLabel),
                if (entry.conditionName.isNotEmpty) Text(entry.conditionName),
                if (entry.affectedWork) const Text('It affected work'),
                if (entry.limitedActivity) const Text('It limited activity'),
                if (entry.rested) const Text('I needed to rest'),
                if (entry.tookTreatment) const Text('I used a treatment'),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    style: dangerTextStyle(),
                    onPressed: () async {
                      await ref.read(removeSymptomEntryProvider)(entry.id);
                      if (context.mounted) context.go(AuthRoutes.symptoms);
                    },
                    child: const Text('Remove'),
                  ),
                ),
              ],
            ),
    );
  }
}

class SymptomSummaryScreen extends StatelessWidget {
  const SymptomSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShellPage(
      title: 'Summary',
      footer: FormActions(onBack: () => context.go(AuthRoutes.symptoms)),
      child: const Text(
        'A monthly summary is not ready. One is saved only after you confirm it.',
      ),
    );
  }
}
