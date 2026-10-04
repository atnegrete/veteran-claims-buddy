import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'claim_guide.dart';
import 'claim_issue.dart';

class ClaimIssueRepository {
  ClaimIssueRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<ClaimIssue>> watch(String uid) {
    return _issues(uid).snapshots().map((snapshot) {
      return [
        for (final doc in snapshot.docs)
          ClaimIssue.fromData(doc.id, doc.data()),
      ];
    });
  }

  Future<void> addToClaim({
    required String uid,
    required String caseId,
    required String conditionId,
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
    final ref = _issues(uid).doc(conditionId);
    final existing = await ref.get();
    if (existing.exists) return;
    await ref.set({
      'conditionId': conditionId,
      'displayName': displayName,
      'caseIds': [caseId],
      'activeCaseId': caseId,
      'status': 'potential',
      'claimPurpose': 'initial',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });
  }

  CollectionReference<Map<String, dynamic>> _issues(String uid) {
    return _firestore.collection('users').doc(uid).collection('claimIssues');
  }
}

final claimIssueRepositoryProvider = Provider<ClaimIssueRepository>((ref) {
  return ClaimIssueRepository(FirebaseFirestore.instance);
});

final claimIssuesProvider = StreamProvider<List<ClaimIssue>>((ref) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(claimIssueRepositoryProvider).watch(uid);
});

typedef AddClaimIssue = Future<void> Function({
  required String caseId,
  required String conditionId,
  required String displayName,
});

final addClaimIssueProvider = Provider<AddClaimIssue>((ref) {
  final repository = ref.watch(claimIssueRepositoryProvider);
  return ({
    required String caseId,
    required String conditionId,
    required String displayName,
  }) {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.addToClaim(
      uid: uid,
      caseId: caseId,
      conditionId: conditionId,
      displayName: displayName,
    );
  };
});
