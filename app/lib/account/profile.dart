import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// US time zones, including territories. The value stored is the IANA id.
const profileTimezones = <String, String>{
  'America/New_York': 'Eastern',
  'America/Chicago': 'Central',
  'America/Denver': 'Mountain',
  'America/Phoenix': 'Arizona',
  'America/Los_Angeles': 'Pacific',
  'America/Anchorage': 'Alaska',
  'Pacific/Honolulu': 'Hawaii',
  'America/Puerto_Rico': 'Atlantic',
  'Pacific/Guam': 'Chamorro',
  'Pacific/Pago_Pago': 'Samoa',
};

const defaultProfileTimezone = 'America/Chicago';

const profileLanguage = 'en';

String normalizeProfileName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

bool profileNameOk(String value) {
  return normalizeProfileName(value).length <= 80;
}

String profileTimezoneOrDefault(String? value) {
  if (value != null && profileTimezones.containsKey(value)) return value;
  return defaultProfileTimezone;
}

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);

  final String message;
}

class ProfileRepository {
  ProfileRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> save({
    required String uid,
    required String displayName,
    required String timezone,
  }) async {
    final name = normalizeProfileName(displayName);
    if (!profileNameOk(name) || !profileTimezones.containsKey(timezone)) {
      throw const ProfileFailure(
        'Check the name and time zone, then try again.',
      );
    }
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
    await _firestore.collection('users').doc(uid).set({
      'displayName': name,
      'timezone': timezone,
      'preferredLanguage': profileLanguage,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(FirebaseFirestore.instance);
});

typedef SaveProfile = Future<void> Function({
  required String displayName,
  required String timezone,
});

final saveProfileProvider = Provider<SaveProfile>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ({required String displayName, required String timezone}) {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) {
      throw const ProfileFailure('Sign in again, then try again.');
    }
    return repository.save(
      uid: uid,
      displayName: displayName,
      timezone: timezone,
    );
  };
});
