import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'package_guidance.dart';

class PackageCheckRepository {
  PackageCheckRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String caseId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('packageChecks')
        .doc(caseId);
  }

  Stream<PackageCheck> watch(String uid, String caseId) {
    return _doc(
      uid,
      caseId,
    ).snapshots().map((snapshot) => PackageCheck.fromData(snapshot.data()));
  }

  Future<void> save({
    required String uid,
    required String caseId,
    required PackageCheck check,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
    final ref = _doc(uid, caseId);
    final existing = await ref.get();
    final data = <String, dynamic>{
      'caseId': caseId,
      'openedVaPage': check.openedVaPage,
      'savedConfirmation': check.savedConfirmation,
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
  }
}

final packageCheckRepositoryProvider = Provider<PackageCheckRepository>((ref) {
  return PackageCheckRepository(FirebaseFirestore.instance);
});

final packageCheckProvider = StreamProvider.family<PackageCheck, String>((
  ref,
  caseId,
) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return Stream.value(PackageCheck.empty);
  return ref.watch(packageCheckRepositoryProvider).watch(uid, caseId);
});
