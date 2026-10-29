import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../forms/form_catalog.dart';
import '../forms/form_questions.dart';
import '../forms/package_form.dart';
import 'claim_guide.dart';

/// Reads and writes `users/{uid}/packageForms`. Enforces the multiplicity rule:
/// a `single` form rejects a second active entry on the same claim; a
/// `multiple` form allows many, each keyed by [PackageForm.multiplicityKey].
class PackageFormRepository {
  PackageFormRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<PackageForm>> watch(String uid, String caseId) {
    return _packageForms(uid)
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map((snapshot) {
          final forms = [
            for (final doc in snapshot.docs)
              PackageForm.fromData(doc.id, doc.data()),
          ];
          forms.sort((a, b) {
            final byForm = a.formNumber.compareTo(b.formNumber);
            if (byForm != 0) return byForm;
            return a.displayLabel.compareTo(b.displayLabel);
          });
          return forms;
        });
  }

  /// Adds a form to the package. Throws [ClaimGuideFailure] when a `single`
  /// form is already on this claim.
  Future<String> add({
    required String uid,
    required String caseId,
    required String formNumber,
    String multiplicityKey = '',
    String displayLabel = '',
    Map<String, String> answers = const {},
    String packet = '',
    String conditionId = '',
    String nexusKind = '',
  }) async {
    final def = formDefFor(formNumber);
    if (def == null) {
      throw const ClaimGuideFailure('That form is not supported yet.');
    }
    await _refresh();
    final existing = await _packageForms(uid)
        .where('caseId', isEqualTo: caseId)
        .where('formNumber', isEqualTo: formNumber)
        .get();
    if (!def.isMultiple && existing.docs.isNotEmpty) {
      throw const ClaimGuideFailure('This form is already in your package.');
    }
    if (def.isMultiple && multiplicityKey.isNotEmpty) {
      final clash = existing.docs.any(
        (doc) => (doc.data()['multiplicityKey'] as String? ?? '') ==
            multiplicityKey,
      );
      if (clash) {
        throw const ClaimGuideFailure('That entry is already in your package.');
      }
    }
    final ref = _packageForms(uid).doc();
    await ref.set({
      'caseId': caseId,
      'formNumber': formNumber,
      'status': packageFormStatusName(
        def.needsStatement
            ? PackageFormStatus.needsInput
            : PackageFormStatus.draft,
      ),
      'multiplicityKey': multiplicityKey,
      'displayLabel': displayLabel,
      'answers': answers,
      'sectionDrafts': <String, String>{},
      'statementStatus': statementStatusName(
        def.needsStatement ? StatementStatus.pending : StatementStatus.none,
      ),
      'statementBody': null,
      'revisionId': null,
      'generatedFormId': null,
      'packet': packet,
      'conditionId': conditionId,
      'nexusKind': nexusKind,
      'sourceType': 'veteranReported',
      'schemaVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateAnswers({
    required String uid,
    required String packageFormId,
    required Map<String, String> answers,
    String? displayLabel,
    PackageFormStatus? status,
  }) async {
    await _refresh();
    await _packageForms(uid).doc(packageFormId).set({
      'answers': answers,
      'displayLabel': ?displayLabel,
      if (status != null) 'status': packageFormStatusName(status),
      'fieldValues': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Persists reviewed section prose, keyed by claim-issue id. A blank value is
  /// dropped so the assembled note from the issue is used again. Each value is
  /// capped at the statement-draft length already confirmed for AI prose.
  Future<void> setSectionDraft({
    required String uid,
    required String packageFormId,
    required Map<String, String> sectionDrafts,
  }) async {
    await _refresh();
    final cleaned = <String, String>{};
    for (final entry in sectionDrafts.entries) {
      final trimmed = entry.value.trim();
      if (trimmed.isEmpty) continue;
      cleaned[entry.key] = trimmed.length > statementBodyMaxLength
          ? trimmed.substring(0, statementBodyMaxLength)
          : trimmed;
    }
    await _packageForms(uid).doc(packageFormId).set({
      'sectionDrafts': cleaned,
      'fieldValues': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setStatement({
    required String uid,
    required String packageFormId,
    required String body,
  }) async {
    await _refresh();
    await _packageForms(uid).doc(packageFormId).set({
      'statementBody': body,
      'statementStatus': statementStatusName(StatementStatus.drafted),
      'status': packageFormStatusName(PackageFormStatus.ready),
      'fieldValues': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> remove({
    required String uid,
    required String packageFormId,
  }) async {
    await _refresh();
    await _packageForms(uid).doc(packageFormId).delete();
  }

  Future<void> _refresh() async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
  }

  CollectionReference<Map<String, dynamic>> _packageForms(String uid) {
    return _firestore.collection('users').doc(uid).collection('packageForms');
  }
}

final packageFormRepositoryProvider = Provider<PackageFormRepository>((ref) {
  return PackageFormRepository(FirebaseFirestore.instance);
});

final packageFormsProvider =
    StreamProvider.family<List<PackageForm>, String>((ref, caseId) {
      final uid = ref.watch(authControllerProvider).session?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(packageFormRepositoryProvider).watch(uid, caseId);
    });
