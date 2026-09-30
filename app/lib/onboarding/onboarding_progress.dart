import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'onboarding_repository.dart';
import 'onboarding_step.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(FirebaseFirestore.instance);
});

final onboardingDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) return Stream.value(null);
  return ref.watch(onboardingRepositoryProvider).watchUser(session.uid);
});

/// False until the Veteran finishes review. Tests can override this.
final onboardingCompleteProvider = Provider<bool>((ref) {
  final doc = ref.watch(onboardingDocProvider);
  return doc.maybeWhen(
    data: (data) => data?['onboardingStatus'] == 'complete',
    orElse: () => false,
  );
});

OnboardingStep savedOnboardingStep(Map<String, dynamic>? data) {
  return onboardingStepFromName(data?['onboardingStep'] as String?) ??
      OnboardingStep.welcome;
}
