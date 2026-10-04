import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

class ClaimGuideFailure implements Exception {
  const ClaimGuideFailure(this.message);

  final String message;
}

class ClaimGuideRepository {
  ClaimGuideRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> saveFirstClaim({
    required String uid,
    required bool firstClaim,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
    await _firestore.collection('users').doc(uid).set({
      'firstVaDisabilityClaim': firstClaim,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final claimGuideRepositoryProvider = Provider<ClaimGuideRepository>((ref) {
  return ClaimGuideRepository(FirebaseFirestore.instance);
});

typedef SaveFirstClaim = Future<void> Function(bool firstClaim);

final saveFirstClaimProvider = Provider<SaveFirstClaim>((ref) {
  final repository = ref.watch(claimGuideRepositoryProvider);
  return (firstClaim) {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.saveFirstClaim(uid: uid, firstClaim: firstClaim);
  };
});

bool? firstClaimAnswer(Map<String, dynamic>? data) {
  final value = data?['firstVaDisabilityClaim'];
  if (value is bool) return value;
  return null;
}
