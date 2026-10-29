import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'next_action.dart';

class ClaimTask {
  const ClaimTask({
    required this.id,
    required this.title,
    required this.description,
    required this.route,
    required this.kind,
  });

  final String id;
  final String title;
  final String description;
  final String? route;
  final String kind;

  static ClaimTask fromData(String id, Map<String, dynamic> data) {
    final route = data['route'];
    return ClaimTask(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      route: route is String && route.isNotEmpty ? route : null,
      kind: data['kind'] as String? ?? '',
    );
  }
}

class NextActionRepository {
  NextActionRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  String? _lastKey;

  CollectionReference<Map<String, dynamic>> _tasks(String uid) {
    return _firestore.collection('users').doc(uid).collection('tasks');
  }

  Stream<ClaimTask?> watch(String uid, String caseId) {
    return _tasks(uid).doc('next-$caseId').snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      if (data['status'] != 'open') return null;
      return ClaimTask.fromData(snapshot.id, data);
    });
  }

  Future<void> save({required String uid, required NextAction action}) async {
    if (action.caseId.isEmpty || action.syncKey == _lastKey) return;
    final key = action.syncKey;
    _lastKey = key;
    try {
      final user = _auth.currentUser;
      if (user != null) await user.getIdToken(true);
      final ref = _tasks(uid).doc('next-${action.caseId}');
      final existing = await ref.get();
      final data = <String, dynamic>{
        'schemaVersion': 1,
        'sourceType': 'systemCalculated',
        'status': 'open',
        'type': action.type,
        'title': action.title,
        'description': action.description,
        'caseId': action.caseId,
        'route': action.route ?? '',
        'kind': action.kind.name,
        'priority': 'normal',
        'conditionId': action.conditionId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!existing.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await ref.set(data, SetOptions(merge: true));
    } catch (_) {
      _lastKey = null;
    }
  }
}

final nextActionRepositoryProvider = Provider<NextActionRepository>((ref) {
  return NextActionRepository(FirebaseFirestore.instance);
});

typedef SyncNextAction = Future<void> Function(NextAction action);

final syncNextActionProvider = Provider<SyncNextAction>((ref) {
  final repository = ref.watch(nextActionRepositoryProvider);
  return (action) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    await repository.save(uid: uid, action: action);
  };
});

final claimTaskProvider = StreamProvider.family<ClaimTask?, String>((
  ref,
  caseId,
) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null || caseId.isEmpty) return Stream.value(null);
  return ref.watch(nextActionRepositoryProvider).watch(uid, caseId);
});
