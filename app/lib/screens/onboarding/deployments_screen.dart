import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../forms/iso_date_field.dart';
import '../../forms/repeatable_entries.dart';
import '../../forms/text_input_chain.dart';
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
  var _addingAnother = false;
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

  Future<void> _load({bool added = false}) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    final repo = ref.read(onboardingRepositoryProvider);
    final periods = await repo.servicePeriods(uid);
    final deployments = await repo.deployments(uid);
    if (!mounted) return;
    if (added) {
      _notes.clear();
      _start.clear();
      _end.clear();
    }
    setState(() {
      _periods = periods;
      _deployments = deployments;
      _loading = false;
      if (added) {
        _periodId = null;
        _combat = false;
        _addingAnother = false;
      }
    });
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
      await ref
          .read(onboardingRepositoryProvider)
          .saveDeployment(
            uid: uid,
            servicePeriodId: _periodId!,
            notes: _notes.text.trim(),
            startDate: yearMonthToIsoDate(_start.text),
            endDate: yearMonthToIsoDate(_end.text),
            combatRelated: _combat,
          );
      await _load(added: true);
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearForm() {
    _notes.clear();
    _start.clear();
    _end.clear();
    setState(() {
      _periodId = null;
      _combat = false;
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
          .deleteDeployment(uid: uid, id: id);
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
      await ref
          .read(onboardingRepositoryProvider)
          .saveStep(
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
                const LeadText(
                  'Add a deployment if you have one. A month and year is enough, and a best guess is fine. You can continue without one.',
                ),
                const SizedBox(height: 16),
                RepeatableEntries(
                  entries: [
                    for (final deployment in _deployments)
                      EntryCard(
                        fields: _deploymentFields(deployment),
                        onRemove: _busy ? null : () => _remove(deployment.id),
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
                  form: _deploymentForm(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorText(_error!),
                ],
              ],
            ),
    );
  }

  List<EntryField> _deploymentFields(DeploymentEntry deployment) {
    final about = deployment.notes.trim().isNotEmpty
        ? deployment.notes.trim()
        : deployment.country.trim();
    final end = deployment.endDate;
    return [
      EntryField(
        label: 'Service period',
        value: _servicePeriodLabel(deployment),
      ),
      EntryField(label: 'About this deployment', value: about),
      EntryField(label: 'Start', value: displayYearMonth(deployment.startDate)),
      if (end != null && end.isNotEmpty)
        EntryField(label: 'End', value: displayYearMonth(end)),
      if (deployment.combatRelated)
        const EntryField(label: 'Combat related', value: 'Yes'),
    ];
  }

  String _servicePeriodLabel(DeploymentEntry deployment) {
    for (final period in _periods) {
      if (period.id == deployment.servicePeriodId) {
        final branch = serviceBranches[period.branch] ?? period.branch;
        return '$branch, ${period.startDate}';
      }
    }
    return '';
  }

  Widget _deploymentForm() {
    return TextInputChain(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_periods.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _periodId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Service period'),
              items: [
                for (final period in _periods)
                  DropdownMenuItem(
                    value: period.id,
                    child: Text(
                      '${serviceBranches[period.branch] ?? period.branch}, ${period.startDate}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _periodId = value),
            ),
            const SizedBox(height: 12),
          ],
          ChainTextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'About this deployment',
              hintText: 'Countries, a unit such as a MEU, ships, or anything else you remember',
            ),
          ),
          const SizedBox(height: 12),
          YearMonthField(controller: _start, label: 'Start', enabled: !_busy),
          const SizedBox(height: 12),
          YearMonthField(controller: _end, label: 'End', enabled: !_busy),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _combat,
            onChanged: _busy
                ? null
                : (value) => setState(() => _combat = value ?? false),
            title: const Text('Combat related'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          FilledButton(
            style: secondaryFilledStyle(),
            onPressed: _busy ? null : _add,
            child: const Text('Add this deployment'),
          ),
        ],
      ),
    );
  }
}
