import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_redirect.dart';
import '../../forms/step_form.dart';
import '../../onboarding/onboarding_progress.dart';
import '../../onboarding/onboarding_step.dart';
import '../shell/signed_in_bar.dart';

String onboardingSaveMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'This account cannot save yet. Sign out, sign in, and try again.';
  }
  return 'Could not save. Try again.';
}

class OnboardingFrame extends ConsumerWidget {
  const OnboardingFrame({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    this.onNext,
    this.nextLabel = 'Continue',
    this.busy = false,
  });

  final OnboardingStep step;
  final String title;
  final Widget child;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = onboardingStepOrder.indexOf(step);
    final saved = ref.watch(onboardingDocProvider).maybeWhen(
      data: savedOnboardingStep,
      orElse: () => step,
    );
    final savedIndex = onboardingStepOrder.indexOf(saved);
    final farthestIndex = savedIndex > currentIndex ? savedIndex : currentIndex;
    return SignedInScaffold(
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                SurfaceCard(
                  child: StepForm(
                    labels: [
                      for (final item in onboardingStepOrder) item.label,
                    ],
                    currentIndex: currentIndex,
                    farthestIndex: farthestIndex,
                    busy: busy,
                    onNext: onNext,
                    nextLabel: nextLabel,
                    onStepSelected: (index) {
                      context.go(
                        '${AuthRoutes.onboarding}/${onboardingStepOrder[index].name}',
                      );
                    },
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
