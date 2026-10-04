import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../app/app_theme.dart';
import '../../forms/iso_date_field.dart';
import '../../forms/repeatable_entries.dart';
import '../../forms/text_input_chain.dart';
import '../../auth/auth_redirect.dart';
import '../../onboarding/onboarding_progress.dart';
import '../../onboarding/onboarding_repository.dart';
import '../../onboarding/onboarding_step.dart';
import 'onboarding_frame.dart';

class ServiceScreen extends ConsumerStatefulWidget {
  const ServiceScreen({super.key});

  @override
  ConsumerState<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends ConsumerState<ServiceScreen> {
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _occupation = TextEditingController();
  String? _branch;
  String? _component;
  var _stillServing = false;
  var _addingAnother = false;
  var _loading = true;
  var _busy = false;
  String? _error;
  List<ServicePeriod> _periods = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _occupation.dispose();
    super.dispose();
  }

  Future<void> _load({bool added = false}) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    final periods = await ref
        .read(onboardingRepositoryProvider)
        .servicePeriods(uid);
    if (!mounted) return;
    if (added) {
      _start.clear();
      _end.clear();
      _occupation.clear();
    }
    setState(() {
      _periods = periods;
      _loading = false;
      if (added) {
        _branch = null;
        _component = null;
        _stillServing = false;
        _addingAnother = false;
      }
    });
  }

  Future<void> _add() async {
    final rangeError = validateDateRange(
      startDate: _start.text,
      endDate: _stillServing ? '' : _end.text,
      endOptional: _stillServing,
    );
    if (_branch == null || _component == null) {
      setState(() => _error = 'Choose a branch and a component.');
      return;
    }
    if (rangeError != null) {
      setState(() => _error = rangeError);
      return;
    }
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .saveServicePeriod(
            uid: uid,
            branch: _branch!,
            component: _component!,
            startDate: _start.text.trim(),
            endDate: _stillServing ? null : _end.text.trim(),
            occupation: _occupation.text.trim().isEmpty
                ? null
                : _occupation.text.trim(),
          );
      await _load(added: true);
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearForm() {
    _start.clear();
    _end.clear();
    _occupation.clear();
    setState(() {
      _branch = null;
      _component = null;
      _stillServing = false;
    });
  }

  void _cancelAdd() {
    _clearForm();
    setState(() {
      _addingAnother = false;
      _error = null;
    });
  }

  Future<void> _remove(String id) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .deleteServicePeriod(uid: uid, id: id);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    if (_periods.isEmpty) {
      setState(() => _error = 'Add at least one service period.');
      return;
    }
    final session = ref.read(authControllerProvider).session;
    if (session?.email == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .saveStep(
            uid: session!.uid,
            email: session.email!,
            step: OnboardingStep.deployments,
            complete: false,
          );
      if (mounted) context.go('${AuthRoutes.onboarding}/deployments');
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      step: OnboardingStep.service,
      title: 'Service',
      busy: _busy || _loading,
      onNext: _continue,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add each period of service. You can still be serving.',
                ),
                const SizedBox(height: 12),
                RepeatableEntries(
                  entries: [
                    for (final period in _periods)
                      EntryCard(
                        fields: _periodFields(period),
                        onRemove: _busy ? null : () => _remove(period.id),
                      ),
                  ],
                  addingAnother: _addingAnother,
                  onAddAnother: _busy
                      ? null
                      : () => setState(() {
                          _error = null;
                          _addingAnother = true;
                        }),
                  onCancel: _busy ? null : _cancelAdd,
                  form: _periodForm(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  List<EntryField> _periodFields(ServicePeriod period) {
    final job = period.occupation?.trim();
    return [
      EntryField(
        label: 'Branch',
        value: serviceBranches[period.branch] ?? period.branch,
      ),
      EntryField(
        label: 'Component',
        value: serviceComponents[period.component] ?? period.component,
      ),
      EntryField(label: 'Start date', value: period.startDate),
      EntryField(label: 'End date', value: period.endDate ?? 'Present'),
      if (job != null) EntryField(label: 'Job or occupation', value: job),
    ];
  }

  Widget _periodForm() {
    return TextInputChain(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _branch,
            decoration: const InputDecoration(labelText: 'Branch'),
            items: [
              for (final entry in serviceBranches.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _branch = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _component,
            decoration: const InputDecoration(labelText: 'Component'),
            items: [
              for (final entry in serviceComponents.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _component = value),
          ),
          const SizedBox(height: 12),
          IsoDateField(
            controller: _start,
            label: 'Start date',
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _stillServing,
            onChanged: _busy
                ? null
                : (value) => setState(() => _stillServing = value ?? false),
            title: const Text('I am still serving'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (!_stillServing)
            IsoDateField(controller: _end, label: 'End date', enabled: !_busy),
          const SizedBox(height: 12),
          ChainTextField(
            controller: _occupation,
            decoration: const InputDecoration(labelText: 'Job or occupation'),
            maxLength: 80,
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: secondaryFilledStyle(),
            onPressed: _busy ? null : _add,
            child: const Text('Add this period'),
          ),
        ],
      ),
    );
  }
}
