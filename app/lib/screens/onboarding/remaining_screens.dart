import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../forms/repeatable_entries.dart';
import '../../forms/text_input_chain.dart';
import '../../auth/auth_redirect.dart';
import '../../onboarding/onboarding_progress.dart';
import '../../onboarding/onboarding_repository.dart';
import '../../onboarding/onboarding_step.dart';
import 'onboarding_frame.dart';

class ExposuresScreen extends ConsumerStatefulWidget {
  const ExposuresScreen({super.key});

  @override
  ConsumerState<ExposuresScreen> createState() => _ExposuresScreenState();
}

class _ExposuresScreenState extends ConsumerState<ExposuresScreen> {
  final _description = TextEditingController();
  String? _type;
  var _addingAnother = false;
  var _loading = true;
  var _busy = false;
  String? _error;
  List<ExposureEntry> _exposures = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _load({bool added = false}) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    final exposures = await ref
        .read(onboardingRepositoryProvider)
        .exposures(uid);
    if (!mounted) return;
    if (added) {
      _description.clear();
    }
    setState(() {
      _exposures = exposures;
      _loading = false;
      if (added) {
        _type = null;
        _addingAnother = false;
      }
    });
  }

  Future<void> _add() async {
    if (_type == null) {
      setState(() => _error = 'Choose an exposure type.');
      return;
    }
    if (_description.text.trim().isEmpty) {
      setState(() => _error = 'Describe the exposure.');
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
          .saveExposure(
            uid: uid,
            type: _type!,
            description: _description.text.trim(),
          );
      await _load(added: true);
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearForm() {
    _description.clear();
    setState(() => _type = null);
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
          .deleteExposure(uid: uid, id: id);
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
            step: OnboardingStep.review,
            complete: false,
          );
      if (mounted) context.go('${AuthRoutes.onboarding}/review');
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      step: OnboardingStep.exposures,
      title: 'Exposures',
      busy: _busy || _loading,
      onNext: _continue,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LeadText(
                  'Add exposures you know about. You can continue without one.',
                ),
                const SizedBox(height: 16),
                RepeatableEntries(
                  entries: [
                    for (final exposure in _exposures)
                      EntryCard(
                        fields: [
                          EntryField(
                            label: 'Type',
                            value:
                                exposureTypes[exposure.type] ?? exposure.type,
                          ),
                          EntryField(
                            label: 'What happened',
                            value: exposure.description,
                          ),
                        ],
                        onRemove: _busy ? null : () => _remove(exposure.id),
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
                  form: _exposureForm(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorText(_error!),
                ],
              ],
            ),
    );
  }

  Widget _exposureForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _type,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            for (final entry in exposureTypes.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _busy ? null : (value) => setState(() => _type = value),
        ),
        const SizedBox(height: 12),
        ChainTextField(
          controller: _description,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          decoration: const InputDecoration(labelText: 'What happened'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: secondaryFilledStyle(),
          onPressed: _busy ? null : _add,
          child: const Text('Add this exposure'),
        ),
      ],
    );
  }
}

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  var _busy = false;
  String? _error;

  Future<void> _finish() async {
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
            step: OnboardingStep.review,
            complete: true,
          );
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      step: OnboardingStep.review,
      title: 'Review',
      busy: _busy,
      nextLabel: 'Finish',
      onNext: _finish,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LeadText(
            'Nothing is filed from here. Your claim opens when you finish.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorText(_error!),
          ],
        ],
      ),
    );
  }
}
