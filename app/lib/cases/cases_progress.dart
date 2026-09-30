import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../home/home_snapshot.dart';
import '../onboarding/onboarding_progress.dart';
import 'cases_repository.dart';
import 'veteran_case.dart';

final casesRepositoryProvider = Provider<CasesRepository>((ref) {
  return CasesRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: 'us-central1'),
    FirebaseAuth.instance,
  );
});

final casesProvider = StreamProvider<List<VeteranCase>>((ref) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(casesRepositoryProvider).watchCases(uid);
});

final workingCaseIdProvider = Provider<String?>((ref) {
  final id = ref.watch(onboardingDocProvider).maybeWhen(
    data: (data) => data?['currentWorkingCaseId'] as String?,
    orElse: () => null,
  );
  if (id == null || id.isEmpty) return null;
  return id;
});

final ensureWorkingCaseCallerProvider = Provider<Future<String> Function()>((ref) {
  return () => ref.read(casesRepositoryProvider).ensureWorkingCase();
});

class CaseEnsure extends Notifier<String?> {
  var _attempted = false;
  var _running = false;

  @override
  String? build() => null;

  Future<void> ensureIfNeeded(List<VeteranCase> cases) async {
    if (_attempted || _running || activeCaseCount(cases) > 0) return;
    _attempted = true;
    await _open();
  }

  Future<void> retry() async {
    _attempted = true;
    await _open();
  }

  Future<void> _open() async {
    if (_running) return;
    _running = true;
    state = null;
    try {
      await ref.read(ensureWorkingCaseCallerProvider)();
    } on CaseFailure catch (error) {
      _attempted = false;
      state = error.message;
    } finally {
      _running = false;
    }
  }
}

final caseEnsureProvider = NotifierProvider<CaseEnsure, String?>(CaseEnsure.new);

final homeSnapshotProvider = Provider<HomeSnapshot>((ref) {
  final cases = ref.watch(casesProvider).maybeWhen(
    data: (value) => value,
    orElse: () => const <VeteranCase>[],
  );
  return homeSnapshotFrom(
    cases: cases,
    workingCaseId: ref.watch(workingCaseIdProvider),
  );
});
