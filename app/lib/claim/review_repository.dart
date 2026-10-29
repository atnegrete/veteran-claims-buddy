import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'claim_guide.dart';
import 'claim_review.dart';

class ReviewRepository {
  ReviewRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<ClaimReview>> watch(String uid, String caseId) {
    return _submissions(uid)
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map((snapshot) {
          final reviews = <ClaimReview>[];
          for (final doc in snapshot.docs) {
            final review = ClaimReview.fromData(doc.id, doc.data());
            if (review != null) reviews.add(review);
          }
          reviews.sort((a, b) => a.displayName.compareTo(b.displayName));
          return reviews;
        });
  }

  Stream<List<ReviewCandidate>> watchCandidates(String uid, String caseId) {
    return _decisions(
      uid,
    ).where('caseId', isEqualTo: caseId).snapshots().asyncMap((snapshot) async {
      final candidates = <ReviewCandidate>[];
      for (final decision in snapshot.docs) {
        if (decision.data()['status'] != 'confirmed') continue;
        final issues = await _decisionIssues(uid)
            .where('decisionId', isEqualTo: decision.id)
            .get();
        for (final issue in issues.docs) {
          final outcome = issue.data()['outcome'] as String? ?? '';
          if (!reviewOutcomeEligible(outcome)) continue;
          final conditionId = issue.data()['conditionId'];
          candidates.add(
            ReviewCandidate(
              decisionId: decision.id,
              decisionIssueId: issue.id,
              conditionId: conditionId is String && conditionId.isNotEmpty
                  ? conditionId
                  : null,
              displayName: issue.data()['displayName'] as String? ?? '',
              outcome: outcome,
              decisionDate: decision.data()['decisionDate'] as String? ?? '',
            ),
          );
        }
      }
      candidates.sort((a, b) => a.displayName.compareTo(b.displayName));
      return candidates;
    });
  }

  Future<void> start({
    required String uid,
    required String caseId,
    required ReviewPath path,
    required ReviewCandidate issue,
    required String? boardDocket,
    required bool? informalConference,
  }) async {
    final error = reviewDraftError(
      path: path,
      issue: issue,
      boardDocket: boardDocket,
      informalConference: informalConference,
    );
    if (error != null) throw ClaimGuideFailure(error);
    await _refresh();
    final submission = _submissions(uid).doc();
    await submission.set({
      'caseId': caseId,
      'type': reviewType(path),
      'status': 'draft',
      'formIds': [reviewFormId(path)],
      'submissionMethod': null,
      'preparedAt': null,
      'submittedAt': null,
      'vaClaimId': null,
      'confirmationNumber': null,
      'payloadSnapshotDocumentId': null,
      'ruleVersionIds': <String>[],
      'decisionId': issue.decisionId,
      'decisionIssueId': issue.decisionIssueId,
      'conditionId': issue.conditionId,
      'displayName': issue.displayName,
      'boardDocket': boardDocket,
      'informalConference': informalConference,
      'sourceType': 'veteranReported',
      'schemaVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await _submissionIssues(uid).doc().set({
        'submissionId': submission.id,
        'conditionId': issue.conditionId,
        'conditionDisplayName': issue.displayName,
        'requestedAction': 'review',
        'status': 'included',
        'decisionIssueId': issue.decisionIssueId,
        'schemaVersion': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await submission.delete();
      rethrow;
    }
  }

  Future<void> discard({required String uid, required String reviewId}) async {
    await _refresh();
    final issues = await _submissionIssues(uid)
        .where('submissionId', isEqualTo: reviewId)
        .get();
    final batch = _firestore.batch();
    for (final issue in issues.docs) {
      batch.delete(issue.reference);
    }
    batch.delete(_submissions(uid).doc(reviewId));
    await batch.commit();
  }

  Future<void> _refresh() async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
  }

  CollectionReference<Map<String, dynamic>> _submissions(String uid) {
    return _firestore.collection('users').doc(uid).collection('submissions');
  }

  CollectionReference<Map<String, dynamic>> _submissionIssues(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('submissionIssues');
  }

  CollectionReference<Map<String, dynamic>> _decisions(String uid) {
    return _firestore.collection('users').doc(uid).collection('decisions');
  }

  CollectionReference<Map<String, dynamic>> _decisionIssues(String uid) {
    return _firestore.collection('users').doc(uid).collection('decisionIssues');
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(FirebaseFirestore.instance);
});

final claimReviewsProvider = StreamProvider.family<List<ClaimReview>, String>((
  ref,
  caseId,
) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(reviewRepositoryProvider).watch(uid, caseId);
});

final reviewCandidatesProvider =
    StreamProvider.family<List<ReviewCandidate>, String>((ref, caseId) {
      final uid = ref.watch(authControllerProvider).session?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(reviewRepositoryProvider).watchCandidates(uid, caseId);
    });
