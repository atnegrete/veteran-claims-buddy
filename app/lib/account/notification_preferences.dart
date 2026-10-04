import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.examReminders = true,
    this.taskReminders = true,
  });

  final bool examReminders;
  final bool taskReminders;

  static const defaults = NotificationPreferences();

  static NotificationPreferences fromData(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return NotificationPreferences(
      examReminders: data['examReminders'] != false,
      taskReminders: data['taskReminders'] != false,
    );
  }
}

class NotificationPreferencesRepository {
  NotificationPreferencesRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('notifications');
  }

  Stream<NotificationPreferences> watch(String uid) {
    return _doc(uid)
        .snapshots()
        .map((snapshot) => NotificationPreferences.fromData(snapshot.data()));
  }

  Future<void> save({
    required String uid,
    required NotificationPreferences preferences,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
    final ref = _doc(uid);
    final existing = await ref.get();
    final data = <String, dynamic>{
      'examReminders': preferences.examReminders,
      'taskReminders': preferences.taskReminders,
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
  }
}

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) {
      return NotificationPreferencesRepository(FirebaseFirestore.instance);
    });

final notificationPreferencesProvider = StreamProvider<NotificationPreferences>(
  (ref) {
    final session = ref.watch(authControllerProvider).session;
    if (session == null) return Stream.value(NotificationPreferences.defaults);
    return ref
        .watch(notificationPreferencesRepositoryProvider)
        .watch(session.uid);
  },
);

typedef SaveNotificationPreferences = Future<void> Function(
  NotificationPreferences preferences,
);

final saveNotificationPreferencesProvider =
    Provider<SaveNotificationPreferences>((ref) {
      final repository = ref.watch(notificationPreferencesRepositoryProvider);
      return (preferences) {
        final uid = ref.read(authControllerProvider).session?.uid;
        if (uid == null) {
          throw StateError('Sign in again, then try again.');
        }
        return repository.save(uid: uid, preferences: preferences);
      };
    });
