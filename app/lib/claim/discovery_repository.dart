import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'claim_guide.dart';
import 'discovery_questions.dart';

class DiscoveryProgress {
  const DiscoveryProgress(this.answers);

  final Map<String, String> answers;

  static const empty = DiscoveryProgress({});
}

class DiscoveryRepository {
  DiscoveryRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<DiscoveryProgress> watch(String uid) {
    return _responses(uid).snapshots().map((snapshot) {
      final raw = <String, String>{};
      for (final doc in snapshot.docs) {
        final value = doc.data()['value'];
        if (value is String && value.isNotEmpty) raw[doc.id] = value;
      }
      return DiscoveryProgress(activeDiscoveryAnswers(raw));
    });
  }

  Future<void> save({
    required String uid,
    required String? caseId,
    required Map<String, String> answers,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
    final active = activeDiscoveryAnswers(answers);
    final questionnaire = _questionnaire(uid);
    final existingQuestionnaire = await questionnaire.get();
    final now = FieldValue.serverTimestamp();
    final visible = visibleDiscoveryQuestions(active);
    final answered = visible
        .where((question) => active.containsKey(question.id))
        .length;
    final complete = visible.isNotEmpty && answered == visible.length;
    final current = resumeDiscoveryQuestionId(active);
    final payload = <String, dynamic>{
      'definitionId': discoveryDefinitionId,
      'definitionVersion': 1,
      'status': complete ? 'complete' : 'inProgress',
      'currentQuestionId': current,
      'progressPercent': discoveryProgressPercent(active),
      'caseId': caseId,
      'completedAt': complete ? now : null,
      'updatedAt': now,
      'schemaVersion': 1,
    };
    if (!existingQuestionnaire.exists) {
      payload['createdAt'] = now;
      payload['startedAt'] = now;
      await questionnaire.set(payload);
    } else {
      await questionnaire.update(payload);
    }

    final responseSnap = await _responses(uid).get();
    final prior = {for (final doc in responseSnap.docs) doc.id};
    final kept = active.keys.toSet();
    for (final doc in responseSnap.docs) {
      if (!kept.contains(doc.id)) await doc.reference.delete();
    }
    for (final entry in active.entries) {
      final question = discoveryQuestionById(entry.key);
      if (question == null) continue;
      var label = entry.value;
      for (final choice in question.choices) {
        if (choice.value == entry.value) label = choice.label;
      }
      final fields = <String, dynamic>{
        'questionId': entry.key,
        'value': entry.value,
        'displayValue': label,
        'sourceType': 'veteranReported',
        'answeredVia': 'ui',
        'updatedAt': now,
        'schemaVersion': 1,
      };
      final ref = _responses(uid).doc(entry.key);
      if (prior.contains(entry.key)) {
        await ref.update(fields);
      } else {
        fields['answeredAt'] = now;
        await ref.set(fields);
      }
    }

    for (final question in discoveryQuestions) {
      if (question.updatesConditionFrom != null ||
          question.conditionName == null) {
        continue;
      }
      final name = discoveryConditionName(question.id, active);
      final ref = _conditions(uid).doc(question.id);
      final snap = await ref.get();
      if (name == null) {
        if (snap.exists) {
          await ref.update({'status': 'dismissed', 'updatedAt': now});
        }
        continue;
      }
      if (!snap.exists) {
        await ref.set({
          'displayName': name,
          'bodySystem': question.bodySystem,
          'status': 'potential',
          'current': true,
          'diagnosed': false,
          'discoverySource': 'questionnaire',
          'sourceQuestionnaireId': discoveryQuestionnaireId,
          'sourceQuestionId': question.id,
          'sourceType': 'veteranReported',
          'schemaVersion': 1,
          'createdAt': now,
          'updatedAt': now,
        });
      } else {
        await ref.update({
          'displayName': name,
          'status': 'potential',
          'current': true,
          'updatedAt': now,
        });
      }
    }
  }

  DocumentReference<Map<String, dynamic>> _questionnaire(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('questionnaires')
        .doc(discoveryQuestionnaireId);
  }

  CollectionReference<Map<String, dynamic>> _responses(String uid) {
    return _questionnaire(uid).collection('responses');
  }

  CollectionReference<Map<String, dynamic>> _conditions(String uid) {
    return _firestore.collection('users').doc(uid).collection('conditions');
  }
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository(FirebaseFirestore.instance);
});

final discoveryProgressProvider = StreamProvider<DiscoveryProgress>((ref) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return Stream.value(DiscoveryProgress.empty);
  return ref.watch(discoveryRepositoryProvider).watch(uid);
});

typedef SaveDiscovery = Future<void> Function({
  required String? caseId,
  required Map<String, String> answers,
});

final saveDiscoveryProvider = Provider<SaveDiscovery>((ref) {
  final repository = ref.watch(discoveryRepositoryProvider);
  return ({required String? caseId, required Map<String, String> answers}) {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.save(uid: uid, caseId: caseId, answers: answers);
  };
});
