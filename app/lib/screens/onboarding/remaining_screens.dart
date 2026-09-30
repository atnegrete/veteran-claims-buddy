import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../auth/auth_controller.dart';
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

  Future<void> _load() async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    final exposures = await ref.read(onboardingRepositoryProvider).exposures(uid);
    if (mounted) {
      setState(() {
        _exposures = exposures;
        _loading = false;
      });
    }
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
      await ref.read(onboardingRepositoryProvider).saveExposure(
            uid: uid,
            type: _type!,
            description: _description.text.trim(),
          );
      _description.clear();
      _type = null;
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
      await ref.read(onboardingRepositoryProvider).deleteExposure(
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
            step: OnboardingStep.discovery,
            complete: false,
          );
      if (mounted) context.go('${AuthRoutes.onboarding}/discovery');
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
                const Text(
                  'Add exposures you know about. A suggestion from the app would stay unconfirmed until you accept it. You can continue without one.',
                ),
                const SizedBox(height: 12),
                for (final exposure in _exposures) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${exposureTypes[exposure.type] ?? exposure.type}: ${exposure.description}',
                        ),
                      ),
                      TextButton(
                        style: dangerTextStyle(),
                        onPressed: _busy ? null : () => _remove(exposure.id),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final entry in exposureTypes.entries)
                      DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: _busy ? null : (value) => setState(() => _type = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'What happened'),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                  onPressed: _busy ? null : _add,
                  child: const Text('Add this exposure'),
                ),
              ],
            ),
    );
  }
}

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  var _busy = false;
  String? _error;

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
      step: OnboardingStep.discovery,
      title: 'What bothers you',
      busy: _busy,
      onNext: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Condition discovery starts from symptoms, not from a list of claimable disabilities. That questionnaire is not open yet. Nothing is filed from this step.',
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
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
      await ref.read(onboardingRepositoryProvider).saveStep(
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
          const Text(
            'No potential conditions yet. Nothing is filed from here. Home opens when you finish.',
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }
}
