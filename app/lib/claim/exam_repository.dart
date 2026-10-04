import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'claim_exam.dart';
import 'claim_guide.dart';

class ExamRepository {
  ExamRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<ClaimExam>> watch(String uid, String caseId) {
    return _exams(uid)
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map((snapshot) {
          final exams = [
            for (final doc in snapshot.docs)
              if (doc.data()['status'] != 'archived')
                ClaimExam.fromData(doc.id, doc.data()),
          ];
          exams.sort((a, b) {
            final byDate = a.examDate.compareTo(b.examDate);
            if (byDate != 0) return byDate;
            return a.examTime.compareTo(b.examTime);
          });
          return exams;
        });
  }

  Future<String> add({
    required String uid,
    required String caseId,
    required String examDate,
    required String examTime,
    required String timezone,
    required String examType,
    required String providerType,
    required String providerName,
    required String location,
    required String phone,
    required bool telehealth,
    required String notes,
  }) async {
    _check(
      examDate: examDate,
      examTime: examTime,
      timezone: timezone,
      examType: examType,
      providerType: providerType,
      providerName: providerName,
      location: location,
      phone: phone,
      notes: notes,
    );
    await _refreshToken();
    final ref = _exams(uid).doc();
    await ref.set(
      _fields(
        caseId: caseId,
        examDate: examDate,
        examTime: examTime,
        timezone: timezone,
        examType: examType,
        providerType: providerType,
        providerName: providerName,
        location: location,
        phone: phone,
        telehealth: telehealth,
        notes: notes,
        createdAt: FieldValue.serverTimestamp(),
      ),
    );
    return ref.id;
  }

  Future<void> update({
    required String uid,
    required String examId,
    required String caseId,
    required String examDate,
    required String examTime,
    required String timezone,
    required String examType,
    required String providerType,
    required String providerName,
    required String location,
    required String phone,
    required bool telehealth,
    required String notes,
  }) async {
    _check(
      examDate: examDate,
      examTime: examTime,
      timezone: timezone,
      examType: examType,
      providerType: providerType,
      providerName: providerName,
      location: location,
      phone: phone,
      notes: notes,
    );
    await _refreshToken();
    await _exams(uid)
        .doc(examId)
        .update(
          _fields(
            caseId: caseId,
            examDate: examDate,
            examTime: examTime,
            timezone: timezone,
            examType: examType,
            providerType: providerType,
            providerName: providerName,
            location: location,
            phone: phone,
            telehealth: telehealth,
            notes: notes,
          ),
        );
  }

  Future<void> archive({required String uid, required String examId}) async {
    await _refreshToken();
    await _exams(uid).doc(examId).update({
      'status': 'archived',
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _check({
    required String examDate,
    required String examTime,
    required String timezone,
    required String examType,
    required String providerType,
    required String providerName,
    required String location,
    required String phone,
    required String notes,
  }) {
    final error = examDraftError(
      examDate: examDate,
      examTime: examTime,
      timezone: timezone,
      examType: examType,
      providerType: providerType,
      providerName: providerName,
      location: location,
      phone: phone,
      notes: notes,
    );
    if (error != null) throw ClaimGuideFailure(error);
  }

  Map<String, Object?> _fields({
    required String caseId,
    required String examDate,
    required String examTime,
    required String timezone,
    required String examType,
    required String providerType,
    required String providerName,
    required String location,
    required String phone,
    required bool telehealth,
    required String notes,
    Object? createdAt,
  }) {
    return {
      'caseId': caseId,
      'examDate': examDate,
      'examTime': examTime,
      'timezone': timezone,
      'examType': examType.trim(),
      'providerType': providerType,
      'providerName': providerName.trim(),
      'location': location.trim(),
      'phone': examPhoneStored(phone),
      'telehealth': telehealth,
      'notes': notes.trim(),
      'status': 'active',
      'sourceType': 'veteranReported',
      'schemaVersion': 1,
      'createdAt': ?createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _refreshToken() async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
  }

  CollectionReference<Map<String, dynamic>> _exams(String uid) {
    return _firestore.collection('users').doc(uid).collection('exams');
  }
}

final examRepositoryProvider = Provider<ExamRepository>((ref) {
  return ExamRepository(FirebaseFirestore.instance);
});

final claimExamsProvider = StreamProvider.family<List<ClaimExam>, String>((
  ref,
  caseId,
) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(examRepositoryProvider).watch(uid, caseId);
});
