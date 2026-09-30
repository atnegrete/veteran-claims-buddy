import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const deletionWarning =
    'Your account is scheduled for deletion. Unless you reactivate it within 30 days, your Veteran Claims Buddy case data, uploaded files, generated documents, symptom history, and other account content will be permanently removed, subject to records we must retain for completed financial/fulfillment transactions.';

abstract class AccountDeletionClient {
  const AccountDeletionClient();

  Future<void> schedule();

  Future<void> cancel();
}

class IdleAccountDeletion implements AccountDeletionClient {
  const IdleAccountDeletion();

  @override
  Future<void> schedule() async {}

  @override
  Future<void> cancel() async {}
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;
}

class FirebaseAccountDeletion implements AccountDeletionClient {
  FirebaseAccountDeletion(this._functions, this._auth);

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  @override
  Future<void> schedule() => _call('scheduleAccountDeletion');

  @override
  Future<void> cancel() => _call('cancelAccountDeletion');

  Future<void> _call(String name) async {
    await _auth.currentUser?.getIdToken(true);
    try {
      await _functions.httpsCallable(name).call();
    } on FirebaseFunctionsException catch (error) {
      throw AccountDeletionException(_message(error));
    }
  }

  String _message(FirebaseFunctionsException error) {
    if (error.code == 'failed-precondition' &&
        error.message != null &&
        error.message!.isNotEmpty) {
      return error.message!;
    }
    return 'That account change did not finish. Try again.';
  }
}

final accountDeletionClientProvider = Provider<AccountDeletionClient>((ref) {
  return FirebaseAccountDeletion(
    FirebaseFunctions.instanceFor(region: 'us-central1'),
    FirebaseAuth.instance,
  );
});
