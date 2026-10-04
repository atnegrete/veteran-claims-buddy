import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'claim_guide.dart';
import 'discovery_questions.dart';
import 'questionnaire_catalog.dart';

class QuestionnaireRepository {
  QuestionnaireRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  List<CatalogQuestion>? _catalog;
  Future<void> _queue = Future<void>.value();
  Map<String, List<String>>? _committed;
  Map<String, _StoredCondition>? _knownConditions;
  var _parentReady = false;

  Stream<QuestionnaireSession> watch(String uid) {
    return _questionnaire(uid).snapshots().asyncExpand((doc) {
      final definitionId = doc.data()?['definitionId'];
      final current = !doc.exists || definitionId == catalogDefinitionId;
      return _responses(uid).snapshots().asyncMap((snapshot) async {
        final questions = await loadCatalog();
        if (!current) {
          return QuestionnaireSession(answers: const {}, questions: questions);
        }
        final raw = <String, List<String>>{};
        for (final response in snapshot.docs) {
          final values = catalogValues(response.data()['value']);
          if (values.isNotEmpty) raw[response.id] = values;
        }
        return QuestionnaireSession(
          answers: activeCatalogAnswers(questions, raw),
          questions: questions,
        );
      });
    });
  }

  Future<List<CatalogQuestion>> loadCatalog() async {
    final cached = _catalog;
    if (cached != null) return cached;
    final snapshot = await _firestore
        .collection('questionnaireDefinitions')
        .doc(catalogDefinitionId)
        .collection('questionDefinitions')
        .get();
    final questions = [
      for (final doc in snapshot.docs)
        catalogQuestionFromMap(doc.data(), doc.id),
    ]..sort((a, b) => a.order.compareTo(b.order));
    _catalog = questions;
    return questions;
  }

  Future<void> save({
    required String uid,
    required String? caseId,
    required List<CatalogQuestion> questions,
    required Map<String, List<String>> answers,
  }) {
    final done = _queue.then(
      (_) => _save(
        uid: uid,
        caseId: caseId,
        questions: questions,
        answers: answers,
      ),
    );
    _queue = done.then((_) {}, onError: (Object _) {});
    return done;
  }

  Future<void> _save({
    required String uid,
    required String? caseId,
    required List<CatalogQuestion> questions,
    required Map<String, List<String>> answers,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
    final active = activeCatalogAnswers(questions, answers);
    final questionnaire = _questionnaire(uid);
    if (!_parentReady) {
      final existing = await questionnaire.get();
      _parentReady = existing.exists;
    }
    final committed = await _committedAnswers(uid);
    final diff = diffAnswers(committed, active);
    final desired = {
      for (final condition in catalogConditions(questions, active))
        condition.id: condition,
    };
    final known = await _conditionState(uid, questions);
    final now = FieldValue.serverTimestamp();
    final visible = visibleCatalogQuestions(questions, active);
    final answered = visible
        .where((question) => active.containsKey(question.id))
        .length;
    final complete = visible.isNotEmpty && answered == visible.length;
    final ops = <void Function(WriteBatch batch)>[];
    final payload = <String, dynamic>{
      'definitionId': catalogDefinitionId,
      'definitionVersion': 2,
      'status': complete ? 'complete' : 'inProgress',
      'currentQuestionId': resumeCatalogQuestionId(questions, active),
      'progressPercent': visible.isEmpty
          ? 0
          : ((answered / visible.length) * 100).round(),
      'caseId': caseId,
      'completedAt': complete ? now : null,
      'updatedAt': now,
      'schemaVersion': 1,
    };
    if (!_parentReady) {
      payload['createdAt'] = now;
      payload['startedAt'] = now;
      ops.add((batch) => batch.set(questionnaire, payload));
    } else {
      ops.add((batch) => batch.update(questionnaire, payload));
    }
    for (final id in diff.removed) {
      ops.add((batch) => batch.delete(_responses(uid).doc(id)));
    }
    for (final entry in diff.changed.entries) {
      final question = catalogQuestionById(questions, entry.key);
      if (question == null) continue;
      final fields = <String, dynamic>{
        'questionId': entry.key,
        'value': question.isMulti ? entry.value : entry.value.first,
        'displayValue': catalogDisplayValue(question, entry.value),
        'sourceType': 'veteranReported',
        'answeredVia': 'ui',
        'updatedAt': now,
        'schemaVersion': 1,
      };
      final ref = _responses(uid).doc(entry.key);
      if (committed.containsKey(entry.key)) {
        ops.add((batch) => batch.update(ref, fields));
      } else {
        fields['answeredAt'] = now;
        ops.add((batch) => batch.set(ref, fields));
      }
    }
    final possible = catalogConditionIds(questions);
    final nextConditions = Map<String, _StoredCondition>.from(known);
    for (final id in known.keys) {
      if (!possible.contains(id) || desired.containsKey(id)) continue;
      final stored = known[id]!;
      if (stored.status == 'dismissed') continue;
      ops.add(
        (batch) => batch.update(_conditions(uid).doc(id), {
          'status': 'dismissed',
          'updatedAt': now,
        }),
      );
      nextConditions[id] = _StoredCondition(stored.name, 'dismissed');
    }
    for (final condition in desired.values) {
      final stored = known[condition.id];
      if (stored != null &&
          stored.status == 'potential' &&
          stored.name == condition.name) {
        continue;
      }
      if (stored == null) {
        final questionId = condition.id.contains('__')
            ? condition.id.split('__').first
            : condition.id;
        final question = catalogQuestionById(questions, questionId);
        ops.add(
          (batch) => batch.set(_conditions(uid).doc(condition.id), {
            'displayName': condition.name,
            'bodySystem': bodySystemForSection(question?.section ?? ''),
            'status': 'potential',
            'current': true,
            'diagnosed': false,
            'discoverySource': 'questionnaire',
            'sourceQuestionnaireId': discoveryQuestionnaireId,
            'sourceQuestionId': questionId,
            'sourceType': 'veteranReported',
            'schemaVersion': 1,
            'createdAt': now,
            'updatedAt': now,
          }),
        );
      } else {
        ops.add(
          (batch) => batch.update(_conditions(uid).doc(condition.id), {
            'displayName': condition.name,
            'status': 'potential',
            'current': true,
            'updatedAt': now,
          }),
        );
      }
      nextConditions[condition.id] = _StoredCondition(
        condition.name,
        'potential',
      );
    }
    await _commit(ops);
    _knownConditions = nextConditions;
    _parentReady = true;
    _committed = {
      for (final entry in active.entries)
        entry.key: List<String>.from(entry.value),
    };
  }

  Future<Map<String, List<String>>> _committedAnswers(String uid) async {
    final cached = _committed;
    if (cached != null) return cached;
    final snapshot = await _responses(uid).get();
    final raw = <String, List<String>>{};
    for (final doc in snapshot.docs) {
      final values = catalogValues(doc.data()['value']);
      if (values.isNotEmpty) raw[doc.id] = values;
    }
    _committed = raw;
    return raw;
  }

  Future<Map<String, _StoredCondition>> _conditionState(
    String uid,
    List<CatalogQuestion> questions,
  ) async {
    final cached = _knownConditions;
    if (cached != null) return cached;
    final possible = catalogConditionIds(questions);
    final snapshot = await _conditions(uid).get();
    final known = <String, _StoredCondition>{};
    for (final doc in snapshot.docs) {
      if (!possible.contains(doc.id)) continue;
      final data = doc.data();
      final name = data['displayName'];
      final status = data['status'];
      known[doc.id] = _StoredCondition(
        name is String ? name : '',
        status is String ? status : '',
      );
    }
    _knownConditions = known;
    return known;
  }

  Future<void> _commit(List<void Function(WriteBatch batch)> ops) async {
    if (ops.isEmpty) return;
    var batch = _firestore.batch();
    var count = 0;
    for (final op in ops) {
      op(batch);
      count += 1;
      if (count == 400) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
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

final questionnaireRepositoryProvider = Provider<QuestionnaireRepository>((
  ref,
) {
  return QuestionnaireRepository(FirebaseFirestore.instance);
});

final questionnaireSessionProvider = StreamProvider<QuestionnaireSession>((
  ref,
) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return Stream.value(QuestionnaireSession.empty);
  return ref.watch(questionnaireRepositoryProvider).watch(uid);
});

class _StoredCondition {
  const _StoredCondition(this.name, this.status);

  final String name;
  final String status;
}

typedef SaveQuestionnaire = Future<void> Function({
  required String? caseId,
  required List<CatalogQuestion> questions,
  required Map<String, List<String>> answers,
});

final saveQuestionnaireProvider = Provider<SaveQuestionnaire>((ref) {
  final repository = ref.watch(questionnaireRepositoryProvider);
  return ({
    required String? caseId,
    required List<CatalogQuestion> questions,
    required Map<String, List<String>> answers,
  }) {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.save(
      uid: uid,
      caseId: caseId,
      questions: questions,
      answers: answers,
    );
  };
});
