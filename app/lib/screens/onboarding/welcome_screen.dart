import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../onboarding/onboarding_progress.dart';
import '../../onboarding/onboarding_step.dart';
import 'onboarding_frame.dart';

class OnboardingResumeScreen extends ConsumerWidget {
  const OnboardingResumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(onboardingDocProvider);
    return doc.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const OnboardingFrame(
        step: OnboardingStep.welcome,
        title: 'Welcome',
        child: Text('Could not open onboarding. Try again.'),
      ),
      data: (data) {
        final step = savedOnboardingStep(data);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('${AuthRoutes.onboarding}/${step.name}');
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
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
            step: OnboardingStep.service,
            complete: false,
          );
      if (mounted) context.go('${AuthRoutes.onboarding}/service');
    } catch (error) {
      if (mounted) setState(() => _error = onboardingSaveMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      step: OnboardingStep.welcome,
      title: 'Welcome',
      busy: _busy,
      onNext: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Veteran Claims Buddy helps you organize a disability claim: your service, what you were exposed to, and the evidence you already have.',
          ),
          const SizedBox(height: 12),
          const Text(
            'This account is for one Veteran. It is not a shared family login.',
          ),
          const SizedBox(height: 12),
          const Text('Nothing on these screens is filed with the VA.'),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }
}
