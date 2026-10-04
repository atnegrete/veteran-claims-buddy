import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'symptom_entry.dart';

class SymptomRepository {
  SymptomRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _entries(String uid) {
    return _firestore.collection('users').doc(uid).collection('symptomEntries');
  }

  Stream<List<SymptomEntry>> watch(String uid) {
    return _entries(uid).snapshots().map((snapshot) {
      final entries = [
        for (final doc in snapshot.docs)
          SymptomEntry.fromData(doc.id, doc.data()),
      ];
      entries.sort((a, b) {
        final byDate = b.occurredDate.compareTo(a.occurredDate);
        if (byDate != 0) return byDate;
        return b.occurredTime.compareTo(a.occurredTime);
      });
      return entries;
    });
  }

  Future<String> add(String uid, SymptomDraft draft) async {
    final error = symptomDraftError(draft);
    if (error != null) throw StateError(error);
    await _auth.currentUser?.getIdToken(true);
    final ref = _entries(uid).doc();
    await ref.set({
      ..._fields(draft),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> remove(String uid, String entryId) async {
    await _auth.currentUser?.getIdToken(true);
    await _entries(uid).doc(entryId).delete();
  }

  Map<String, Object> _fields(SymptomDraft draft) {
    return {
      'entryType': draft.entryType,
      'occurredDate': draft.occurredDate,
      'occurredTime': draft.occurredTime,
      'severity': draft.severity,
      'duration': draft.duration,
      'affectedWork': draft.affectedWork,
      'limitedActivity': draft.limitedActivity,
      'rested': draft.rested,
      'tookTreatment': draft.tookTreatment,
      'conditionId': draft.conditionId,
      'conditionName': draft.conditionName,
      'schemaVersion': 1,
    };
  }
}

final symptomRepositoryProvider = Provider<SymptomRepository>((ref) {
  return SymptomRepository(FirebaseFirestore.instance);
});

final symptomEntriesProvider = StreamProvider<List<SymptomEntry>>((ref) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(symptomRepositoryProvider).watch(uid);
});

final saveSymptomEntryProvider = Provider<Future<void> Function(SymptomDraft)>((
  ref,
) {
  return (draft) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    await ref.read(symptomRepositoryProvider).add(uid, draft);
  };
});

final removeSymptomEntryProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (entryId) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    await ref.read(symptomRepositoryProvider).remove(uid, entryId);
  };
});
