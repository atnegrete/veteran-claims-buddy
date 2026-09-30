import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'onboarding_step.dart';

class ServicePeriod {
  const ServicePeriod({
    required this.id,
    required this.branch,
    required this.component,
    required this.startDate,
    this.endDate,
    this.occupation,
  });

  final String id;
  final String branch;
  final String component;
  final String startDate;
  final String? endDate;
  final String? occupation;

  static ServicePeriod fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ServicePeriod(
      id: doc.id,
      branch: data['branch'] as String? ?? '',
      component: data['component'] as String? ?? '',
      startDate: data['startDate'] as String? ?? '',
      endDate: data['endDate'] as String?,
      occupation: data['primaryOccupationText'] as String?,
    );
  }
}

class DeploymentEntry {
  const DeploymentEntry({
    required this.id,
    required this.servicePeriodId,
    required this.startDate,
    this.endDate,
    this.notes = '',
    this.country = '',
    this.combatRelated = false,
  });

  final String id;
  final String servicePeriodId;
  final String startDate;
  final String? endDate;
  final String notes;
  final String country;
  final bool combatRelated;

  String get summary {
    final text = notes.trim().isNotEmpty ? notes.trim() : country.trim();
    final when =
        '${displayYearMonth(startDate)} – ${endDate == null ? '' : displayYearMonth(endDate!)}';
    if (text.isEmpty) return when;
    return '$text, $when';
  }

  static DeploymentEntry fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DeploymentEntry(
      id: doc.id,
      servicePeriodId: data['servicePeriodId'] as String? ?? '',
      startDate: data['startDate'] as String? ?? '',
      endDate: data['endDate'] as String?,
      notes: data['notes'] as String? ?? data['locationText'] as String? ?? '',
      country: data['country'] as String? ?? '',
      combatRelated: data['combatRelated'] == true,
    );
  }
}

class ExposureEntry {
  const ExposureEntry({
    required this.id,
    required this.type,
    required this.description,
  });

  final String id;
  final String type;
  final String description;

  static ExposureEntry fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ExposureEntry(
      id: doc.id,
      type: data['type'] as String? ?? '',
      description: data['description'] as String? ?? '',
    );
  }
}

const serviceBranches = <String, String>{
  'army': 'Army',
  'navy': 'Navy',
  'airForce': 'Air Force',
  'marineCorps': 'Marine Corps',
  'coastGuard': 'Coast Guard',
  'spaceForce': 'Space Force',
};

const serviceComponents = <String, String>{
  'active': 'Active',
  'reserve': 'Reserve',
  'guard': 'National Guard',
};

const exposureTypes = <String, String>{
  'burnPit': 'Burn pit',
  'herbicide': 'Herbicide',
  'noise': 'Noise',
  'radiation': 'Radiation',
  'solvent': 'Solvent',
  'asbestos': 'Asbestos',
  'other': 'Other',
};

class OnboardingRepository {
  OnboardingRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _user(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Stream<Map<String, dynamic>?> watchUser(String uid) {
    return _user(uid).snapshots().map((snapshot) => snapshot.data());
  }

  Future<List<ServicePeriod>> servicePeriods(String uid) async {
    final snapshot = await _user(uid).collection('servicePeriods').get();
    return snapshot.docs.map(ServicePeriod.fromDoc).toList();
  }

  Future<List<DeploymentEntry>> deployments(String uid) async {
    final snapshot = await _user(uid).collection('deployments').get();
    return snapshot.docs.map(DeploymentEntry.fromDoc).toList();
  }

  Future<List<ExposureEntry>> exposures(String uid) async {
    final snapshot = await _user(uid).collection('exposures').get();
    return snapshot.docs.map(ExposureEntry.fromDoc).toList();
  }

  Future<void> saveStep({
    required String uid,
    required String email,
    required OnboardingStep step,
    required bool complete,
  }) async {
    await _refreshToken();
    final ref = _user(uid);
    final existing = await ref.get();
    final data = <String, dynamic>{
      'email': email,
      'emailVerified': true,
      'onboardingStatus': complete ? 'complete' : 'inProgress',
      'onboardingStep': step.name,
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> saveServicePeriod({
    required String uid,
    String? id,
    required String branch,
    required String component,
    required String startDate,
    String? endDate,
    String? occupation,
  }) async {
    await _refreshToken();
    final collection = _user(uid).collection('servicePeriods');
    final ref = id == null ? collection.doc() : collection.doc(id);
    final existing = await ref.get();
    final data = <String, dynamic>{
      'id': ref.id,
      'branch': branch,
      'component': component,
      'startDate': startDate,
      'endDate': endDate,
      'characterOfService': 'unknown',
      'primaryOccupationText': occupation,
      'sourceType': 'veteranReported',
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> deleteServicePeriod({
    required String uid,
    required String id,
  }) {
    return _user(uid).collection('servicePeriods').doc(id).delete();
  }

  Future<void> saveDeployment({
    required String uid,
    String? id,
    required String servicePeriodId,
    required String notes,
    required String startDate,
    String? endDate,
    required bool combatRelated,
  }) async {
    await _refreshToken();
    final collection = _user(uid).collection('deployments');
    final ref = id == null ? collection.doc() : collection.doc(id);
    final existing = await ref.get();
    final data = <String, dynamic>{
      'id': ref.id,
      'servicePeriodId': servicePeriodId,
      'notes': notes,
      'startDate': startDate,
      'endDate': endDate,
      'combatRelated': combatRelated,
      'sourceType': 'veteranReported',
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> deleteDeployment({required String uid, required String id}) {
    return _user(uid).collection('deployments').doc(id).delete();
  }

  Future<void> saveExposure({
    required String uid,
    String? id,
    required String type,
    required String description,
  }) async {
    await _refreshToken();
    final collection = _user(uid).collection('exposures');
    final ref = id == null ? collection.doc() : collection.doc(id);
    final existing = await ref.get();
    final data = <String, dynamic>{
      'id': ref.id,
      'type': type,
      'description': description,
      'status': 'reported',
      'sourceType': 'veteranReported',
      'needsUserConfirmation': false,
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> deleteExposure({required String uid, required String id}) {
    return _user(uid).collection('exposures').doc(id).delete();
  }

  Future<void> _refreshToken() {
    final user = _auth.currentUser;
    if (user == null) return Future.value();
    return user.getIdToken(true);
  }
}
