import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'claim_guide.dart';
import 'claim_issue.dart';

class IssueRecordRepository {
  IssueRecordRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<ClaimTheory>> watchTheories(String uid, String issueId) {
    return _theories(uid, issueId).snapshots().map((snapshot) {
      return [
        for (final doc in snapshot.docs)
          ClaimTheory.fromData(doc.id, doc.data()),
      ];
    });
  }

  Stream<IssueStatement?> watchStatement(
    String uid,
    String issueId,
    String kind,
  ) {
    return _statements(uid, issueId).doc(kind).snapshots().map((doc) {
      if (!doc.exists) return null;
      return IssueStatement.fromData(doc.id, doc.data() ?? const {});
    });
  }

  Stream<List<EvidenceLink>> watchLinks(String uid, String issueId) {
    return _links(uid)
        .where('claimIssueId', isEqualTo: issueId)
        .snapshots()
        .map((snapshot) {
          return [
            for (final doc in snapshot.docs)
              EvidenceLink.fromData(doc.id, doc.data()),
          ];
        });
  }

  Stream<List<RecordedDecision>> watchDecisions(String uid, String issueId) {
    return _decisionIssues(uid)
        .where('claimIssueId', isEqualTo: issueId)
        .snapshots()
        .asyncMap((snapshot) async {
          final decisions = <RecordedDecision>[];
          for (final doc in snapshot.docs) {
            final decisionId = doc.data()['decisionId'];
            if (decisionId is! String || decisionId.isEmpty) continue;
            final parent = await _decisions(uid).doc(decisionId).get();
            if (parent.data()?['status'] != 'confirmed') continue;
            final date = parent.data()?['decisionDate'];
            decisions.add(
              RecordedDecision.fromIssue(
                doc.id,
                doc.data(),
                decisionDate: date is String ? date : '',
              ),
            );
          }
          return decisions;
        });
  }

  Future<void> addTheory({
    required String uid,
    required String issueId,
    required String type,
    required String summary,
    String? relatedClaimIssueId,
  }) async {
    await _refresh();
    await _theories(uid, issueId).add({
      'type': type,
      'status': 'active',
      'summary': summary,
      'sourceType': 'veteranReported',
      'needsUserConfirmation': false,
      'relatedClaimIssueId': type == 'secondary' ? relatedClaimIssueId : null,
      'presumptionRuleId': null,
      'schemaVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeTheory({
    required String uid,
    required String issueId,
    required String theoryId,
  }) async {
    await _refresh();
    await _theories(uid, issueId).doc(theoryId).delete();
  }

  Future<void> saveStatement({
    required String uid,
    required String issueId,
    required String kind,
    required String body,
  }) async {
    await _refresh();
    final ref = _statements(uid, issueId).doc(kind);
    final existing = await ref.get();
    if (existing.exists) {
      await ref.update({
        'kind': kind,
        'body': body,
        'sourceType': 'veteranReported',
        'schemaVersion': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await ref.set({
      'kind': kind,
      'body': body,
      'sourceType': 'veteranReported',
      'schemaVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeStatement({
    required String uid,
    required String issueId,
    required String kind,
  }) async {
    await _refresh();
    await _statements(uid, issueId).doc(kind).delete();
  }

  Future<void> addLink({
    required String uid,
    required String issueId,
    required String evidenceType,
    required String relationship,
    required String summary,
  }) async {
    await _refresh();
    await _links(uid).add({
      'claimIssueId': issueId,
      'documentId': null,
      'factId': null,
      'questionnaireId': null,
      'responseId': null,
      'evidenceType': evidenceType,
      'relationship': relationship,
      'summary': summary,
      'sourceType': 'veteranReported',
      'userConfirmed': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeLink({required String uid, required String linkId}) async {
    await _refresh();
    await _links(uid).doc(linkId).delete();
  }

  Future<void> addDecision({
    required String uid,
    required String caseId,
    required String issueId,
    required String displayName,
    required String decisionDate,
    required String outcome,
    required int? ratingPercent,
    required String? effectiveDate,
  }) async {
    await _refresh();
    final decision = _decisions(uid).doc();
    final issue = _decisionIssues(uid).doc(decision.id);
    await decision.set({
      'caseId': caseId,
      'decisionDate': decisionDate,
      'sourceDocumentId': null,
      'sourceType': 'manual',
      'status': 'confirmed',
      'schemaVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await issue.set({
        'decisionId': decision.id,
        'claimIssueId': issueId,
        'displayName': displayName,
        'outcome': outcome,
        'ratingPercent': ratingPercent,
        'effectiveDate': effectiveDate,
        'schemaVersion': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      await decision.delete();
      rethrow;
    }
  }

  Future<void> removeDecision({
    required String uid,
    required String decisionId,
  }) async {
    await _refresh();
    final batch = _firestore.batch();
    batch.delete(_decisionIssues(uid).doc(decisionId));
    batch.delete(_decisions(uid).doc(decisionId));
    await batch.commit();
  }

  Future<void> _refresh() async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
  }

  CollectionReference<Map<String, dynamic>> _theories(String uid, String id) {
    return _issues(uid).doc(id).collection('theories');
  }

  CollectionReference<Map<String, dynamic>> _statements(String uid, String id) {
    return _issues(uid).doc(id).collection('statements');
  }

  CollectionReference<Map<String, dynamic>> _issues(String uid) {
    return _firestore.collection('users').doc(uid).collection('claimIssues');
  }

  CollectionReference<Map<String, dynamic>> _links(String uid) {
    return _firestore.collection('users').doc(uid).collection('evidenceLinks');
  }

  CollectionReference<Map<String, dynamic>> _decisions(String uid) {
    return _firestore.collection('users').doc(uid).collection('decisions');
  }

  CollectionReference<Map<String, dynamic>> _decisionIssues(String uid) {
    return _firestore.collection('users').doc(uid).collection('decisionIssues');
  }
}

final issueRecordRepositoryProvider = Provider<IssueRecordRepository>((ref) {
  return IssueRecordRepository(FirebaseFirestore.instance);
});

final issueTheoriesProvider = StreamProvider.family<List<ClaimTheory>, String>((
  ref,
  issueId,
) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(issueRecordRepositoryProvider).watchTheories(uid, issueId);
});

final issueLinksProvider = StreamProvider.family<List<EvidenceLink>, String>((
  ref,
  issueId,
) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(issueRecordRepositoryProvider).watchLinks(uid, issueId);
});

final issueDecisionsProvider =
    StreamProvider.family<List<RecordedDecision>, String>((ref, issueId) {
      final uid = ref.watch(authControllerProvider).session?.uid;
      if (uid == null) return Stream.value(const []);
      return ref
          .watch(issueRecordRepositoryProvider)
          .watchDecisions(uid, issueId);
    });

final issueStatementProvider =
    StreamProvider.family<IssueStatement?, (String, String)>((ref, key) {
      final uid = ref.watch(authControllerProvider).session?.uid;
      if (uid == null) return Stream.value(null);
      return ref
          .watch(issueRecordRepositoryProvider)
          .watchStatement(uid, key.$1, key.$2);
    });

String? _uid(Ref ref) {
  return ref.read(authControllerProvider).session?.uid;
}

final saveTheoryProvider = Provider<SaveTheory>((ref) {
  final repository = ref.watch(issueRecordRepositoryProvider);
  return ({
    required String issueId,
    required String type,
    required String summary,
    String? relatedClaimIssueId,
  }) {
    final uid = _uid(ref);
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.addTheory(
      uid: uid,
      issueId: issueId,
      type: type,
      summary: summary,
      relatedClaimIssueId: relatedClaimIssueId,
    );
  };
});

final removeTheoryProvider = Provider<RemoveTheory>((ref) {
  final repository = ref.watch(issueRecordRepositoryProvider);
  return ({required String issueId, required String theoryId}) {
    final uid = _uid(ref);
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.removeTheory(
      uid: uid,
      issueId: issueId,
      theoryId: theoryId,
    );
  };
});

final saveStatementProvider = Provider<SaveStatement>((ref) {
  final repository = ref.watch(issueRecordRepositoryProvider);
  return ({
    required String issueId,
    required String kind,
    required String body,
  }) {
    final uid = _uid(ref);
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.saveStatement(
      uid: uid,
      issueId: issueId,
      kind: kind,
      body: body,
    );
  };
});

final removeStatementProvider = Provider<RemoveStatement>((ref) {
  final repository = ref.watch(issueRecordRepositoryProvider);
  return ({required String issueId, required String kind}) {
    final uid = _uid(ref);
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.removeStatement(uid: uid, issueId: issueId, kind: kind);
  };
});

final saveEvidenceLinkProvider = Provider<SaveEvidenceLink>((ref) {
  final repository = ref.watch(issueRecordRepositoryProvider);
  return ({
    required String issueId,
    required String evidenceType,
    required String relationship,
    required String summary,
  }) {
    final uid = _uid(ref);
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.addLink(
      uid: uid,
      issueId: issueId,
      evidenceType: evidenceType,
      relationship: relationship,
      summary: summary,
    );
  };
});

final removeEvidenceLinkProvider = Provider<RemoveEvidenceLink>((ref) {
  final repository = ref.watch(issueRecordRepositoryProvider);
  return ({required String linkId}) {
    final uid = _uid(ref);
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.removeLink(uid: uid, linkId: linkId);
  };
});

final saveDecisionProvider = Provider<SaveDecision>((ref) {
  final repository = ref.watch(issueRecordRepositoryProvider);
  return ({
    required String caseId,
    required String issueId,
    required String displayName,
    required String decisionDate,
    required String outcome,
    required int? ratingPercent,
    required String? effectiveDate,
  }) {
    final uid = _uid(ref);
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.addDecision(
      uid: uid,
      caseId: caseId,
      issueId: issueId,
      displayName: displayName,
      decisionDate: decisionDate,
      outcome: outcome,
      ratingPercent: ratingPercent,
      effectiveDate: effectiveDate,
    );
  };
});

final removeDecisionProvider = Provider<RemoveDecision>((ref) {
  final repository = ref.watch(issueRecordRepositoryProvider);
  return ({required String decisionId}) {
    final uid = _uid(ref);
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.removeDecision(uid: uid, decisionId: decisionId);
  };
});

typedef SaveTheory = Future<void> Function({
  required String issueId,
  required String type,
  required String summary,
  String? relatedClaimIssueId,
});

typedef RemoveTheory = Future<void> Function({
  required String issueId,
  required String theoryId,
});

typedef SaveStatement = Future<void> Function({
  required String issueId,
  required String kind,
  required String body,
});

typedef RemoveStatement = Future<void> Function({
  required String issueId,
  required String kind,
});

typedef SaveEvidenceLink = Future<void> Function({
  required String issueId,
  required String evidenceType,
  required String relationship,
  required String summary,
});

typedef RemoveEvidenceLink = Future<void> Function({required String linkId});

typedef SaveDecision = Future<void> Function({
  required String caseId,
  required String issueId,
  required String displayName,
  required String decisionDate,
  required String outcome,
  required int? ratingPercent,
  required String? effectiveDate,
});

typedef RemoveDecision = Future<void> Function({required String decisionId});
