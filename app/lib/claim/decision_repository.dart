import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'claim_decision.dart';
import 'claim_guide.dart';

class DecisionRepository {
  DecisionRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<ClaimDecision>> watch(String uid, String caseId) {
    return _decisions(uid)
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map((snapshot) {
          final decisions = [
            for (final doc in snapshot.docs)
              ClaimDecision.fromData(doc.id, doc.data()),
          ];
          decisions.sort((a, b) => b.decisionDate.compareTo(a.decisionDate));
          return decisions;
        });
  }

  Stream<List<ClaimDecisionIssue>> watchIssues(String uid, String decisionId) {
    return _issues(uid)
        .where('decisionId', isEqualTo: decisionId)
        .snapshots()
        .map((snapshot) {
          final issues = [
            for (final doc in snapshot.docs)
              ClaimDecisionIssue.fromData(doc.id, doc.data()),
          ];
          issues.sort((a, b) => a.displayName.compareTo(b.displayName));
          return issues;
        });
  }

  Future<void> confirm({
    required String uid,
    required String decisionId,
    required String decisionDate,
    required String? receivedDate,
    required String summary,
    required List<ConfirmDecisionIssue> issues,
  }) async {
    final error = decisionConfirmError(
      decisionDate: decisionDate,
      receivedDate: receivedDate ?? '',
      summary: summary,
      issues: [
        for (final issue in issues)
          (
            name: issue.displayName,
            outcome: issue.outcome,
            rating: issue.ratingPercent,
            effectiveDate: issue.effectiveDate ?? '',
            findings: [for (final finding in issue.findings) finding.text],
            reasons: [
              for (final reason in issue.reasons)
                (text: reason.text, category: reason.category),
            ],
          ),
      ],
    );
    if (error != null) throw ClaimGuideFailure(error);
    await _refresh();
    final batch = _firestore.batch();
    batch.update(_decisions(uid).doc(decisionId), {
      'decisionDate': decisionDate,
      'receivedDate': receivedDate,
      'overallSummary': summary.trim(),
      'status': 'confirmed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final issue in issues) {
      batch.update(_issues(uid).doc(issue.id), {
        'conditionId': issue.conditionId,
        'displayName': issue.displayName.trim(),
        'outcome': issue.outcome,
        'ratingPercent': issue.ratingPercent,
        'effectiveDate': issue.effectiveDate,
        'favorableFindings': [
          for (final finding in issue.findings)
            if (finding.text.trim().isNotEmpty)
              {
                'text': finding.text.trim(),
                'page': finding.page,
                'sourceDocumentId': issue.sourceDocumentId,
              },
        ],
        'reasons': [
          for (final reason in issue.reasons)
            if (reason.text.trim().isNotEmpty)
              {
                'text': reason.text.trim(),
                'category': reason.category,
                'page': reason.page,
                'sourceDocumentId': issue.sourceDocumentId,
              },
        ],
        'userConfirmed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> discard({
    required String uid,
    required String decisionId,
    required List<String> issueIds,
  }) async {
    await _refresh();
    final batch = _firestore.batch();
    for (final issueId in issueIds) {
      batch.delete(_issues(uid).doc(issueId));
    }
    batch.delete(_decisions(uid).doc(decisionId));
    await batch.commit();
  }

  Future<void> _refresh() async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
  }

  CollectionReference<Map<String, dynamic>> _decisions(String uid) {
    return _firestore.collection('users').doc(uid).collection('decisions');
  }

  CollectionReference<Map<String, dynamic>> _issues(String uid) {
    return _firestore.collection('users').doc(uid).collection('decisionIssues');
  }
}

class ConfirmDecisionIssue {
  const ConfirmDecisionIssue({
    required this.id,
    required this.conditionId,
    required this.displayName,
    required this.outcome,
    required this.ratingPercent,
    required this.effectiveDate,
    required this.findings,
    required this.reasons,
    required this.sourceDocumentId,
  });

  final String id;
  final String? conditionId;
  final String displayName;
  final String outcome;
  final int? ratingPercent;
  final String? effectiveDate;
  final List<DecisionFinding> findings;
  final List<DecisionReason> reasons;
  final String? sourceDocumentId;
}

final decisionRepositoryProvider = Provider<DecisionRepository>((ref) {
  return DecisionRepository(FirebaseFirestore.instance);
});

final claimDecisionsProvider =
    StreamProvider.family<List<ClaimDecision>, String>((ref, caseId) {
      final uid = ref.watch(authControllerProvider).session?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(decisionRepositoryProvider).watch(uid, caseId);
    });

final decisionIssuesProvider =
    StreamProvider.family<List<ClaimDecisionIssue>, String>((ref, decisionId) {
      final uid = ref.watch(authControllerProvider).session?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(decisionRepositoryProvider).watchIssues(uid, decisionId);
    });
