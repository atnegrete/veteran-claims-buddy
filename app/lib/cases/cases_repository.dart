import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'veteran_case.dart';

class CaseFailure implements Exception {
  const CaseFailure(this.message);

  final String message;
}

class CasesRepository {
  CasesRepository(this._firestore, this._functions, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Stream<List<VeteranCase>> watchCases(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('cases')
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              VeteranCase.fromDoc(doc.id, doc.data()),
          ]..sort((a, b) => a.displayName.compareTo(b.displayName)),
        );
  }

  Future<String> ensureWorkingCase() async {
    final data = await _call('ensureWorkingCase', const {});
    final caseId = data['caseId'];
    if (caseId is! String || caseId.isEmpty) {
      throw const CaseFailure('That case could not be opened. Try again.');
    }
    return caseId;
  }

  Future<void> setWorkingCase(String caseId) async {
    await _call('setWorkingCase', {'caseId': caseId});
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    await _auth.currentUser?.getIdToken(true);
    try {
      final result = await _functions.httpsCallable(name).call(payload);
      final data = result.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return const {};
    } on FirebaseFunctionsException catch (error) {
      throw CaseFailure(_message(error));
    }
  }

  String _message(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'invalid-argument':
        return 'That case could not be opened. Try again.';
      case 'not-found':
        return 'That case is not on this account.';
      case 'failed-precondition':
        return 'Finish sign-in security before opening a case.';
      default:
        return 'That case could not be opened. Try again.';
    }
  }
}
