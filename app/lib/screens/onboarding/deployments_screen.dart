import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../forms/iso_date_field.dart';
import '../../auth/auth_redirect.dart';
import '../../onboarding/onboarding_progress.dart';
import '../../onboarding/onboarding_repository.dart';
import '../../onboarding/onboarding_step.dart';
import 'onboarding_frame.dart';

class DeploymentsScreen extends ConsumerStatefulWidget {
  const DeploymentsScreen({super.key});

  @override
  ConsumerState<DeploymentsScreen> createState() => _DeploymentsScreenState();
}

class _DeploymentsScreenState extends ConsumerState<DeploymentsScreen> {
  final _notes = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  String? _periodId;
  var _combat = false;
  var _loading = true;
  var _busy = false;
  String? _error;
  List<ServicePeriod> _periods = const [];
  List<DeploymentEntry> _deployments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    final repo = ref.read(onboardingRepositoryProvider);
    final periods = await repo.servicePeriods(uid);
    final deployments = await repo.deployments(uid);
    if (mounted) {
      setState(() {
        _periods = periods;
        _deployments = deployments;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    if (_notes.text.trim().isEmpty) {
      setState(() => _error = 'Describe the deployment.');
      return;
    }
    if (_periodId == null) {
      setState(() => _error = 'Choose the service period for this deployment.');
      return;
    }
    final rangeError = validateYearMonthRange(
      start: _start.text,
      end: _end.text,
    );
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
      await ref.read(onboardingRepositoryProvider).saveDeployment(
            uid: uid,
            servicePeriodId: _periodId!,
            notes: _notes.text.trim(),
            startDate: yearMonthToIsoDate(_start.text),
            endDate: yearMonthToIsoDate(_end.text),
            combatRelated: _combat,
          );
      _notes.clear();
      _start.clear();
      _end.clear();
      _combat = false;
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String id) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(onboardingRepositoryProvider).deleteDeployment(
            uid: uid,
            id: id,
          );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    final session = ref.read(authControllerProvider).session;
    if (session?.email == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(onboardingRepositoryProvider).saveStep(
            uid: session!.uid,
            email: session.email!,
            step: OnboardingStep.exposures,
            complete: false,
          );
      if (mounted) context.go('${AuthRoutes.onboarding}/exposures');
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      step: OnboardingStep.deployments,
      title: 'Deployments',
      busy: _busy || _loading,
      onNext: _continue,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add a deployment if you have one. A month and year is enough, and a best guess is fine. You can continue without one.',
                ),
                const SizedBox(height: 12),
                for (final deployment in _deployments) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(deployment.summary),
                      ),
                      TextButton(
                        style: dangerTextStyle(),
                        onPressed: _busy ? null : () => _remove(deployment.id),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
                if (_periods.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _periodId,
                    decoration: const InputDecoration(labelText: 'Service period'),
                    items: [
                      for (final period in _periods)
                        DropdownMenuItem(
                          value: period.id,
                          child: Text(
                            '${serviceBranches[period.branch] ?? period.branch}, ${period.startDate}',
                          ),
                        ),
                    ],
                    onChanged: _busy ? null : (value) => setState(() => _periodId = value),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'About this deployment',
                    hintText:
                        'Countries, a unit such as a MEU, ships, or anything else you remember',
                  ),
                ),
                const SizedBox(height: 12),
                YearMonthField(
                  controller: _start,
                  label: 'Start',
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                YearMonthField(
                  controller: _end,
                  label: 'End',
                  enabled: !_busy,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _combat,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _combat = value ?? false),
                  title: const Text('Combat related'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                  onPressed: _busy ? null : _add,
                  child: const Text('Add this deployment'),
                ),
              ],
            ),
    );
  }
}
