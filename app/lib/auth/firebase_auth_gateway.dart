import 'package:firebase_auth/firebase_auth.dart';

import 'auth_failure.dart';
import 'auth_gateway.dart';
import 'auth_session.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<AuthSession?> watchSession() {
    return _auth.authStateChanges().asyncMap(_sessionFor);
  }

  @override
  Future<AuthSession?> currentSession() => _sessionFor(_auth.currentUser);

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    await _guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.sendEmailVerification();
    });
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) {
    return _guard(
      () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  @override
  Future<void> sendEmailVerification() {
    return _guard(() async {
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthFailure(AuthFailureCode.unknown);
      }
      await user.sendEmailVerification();
    });
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _guard(() async {
      try {
        await _auth.sendPasswordResetEmail(email: email.trim());
      } on FirebaseAuthException catch (error) {
        if (error.code == 'user-not-found') return;
        rethrow;
      }
    });
  }

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) {
    return _guard(
      () => _auth.confirmPasswordReset(code: code, newPassword: newPassword),
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<AuthSession?> _sessionFor(User? user) async {
    if (user == null) return null;
    var mfaEnrolled = false;
    try {
      final factors = await user.multiFactor.getEnrolledFactors();
      mfaEnrolled = factors.isNotEmpty;
    } on FirebaseAuthException {
      mfaEnrolled = false;
    }
    return AuthSession(
      uid: user.uid,
      email: user.email,
      emailVerified: user.emailVerified,
      mfaEnrolled: mfaEnrolled,
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _map(error);
    }
  }

  AuthFailure _map(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return const AuthFailure(AuthFailureCode.invalidEmail);
      case 'email-already-in-use':
        return const AuthFailure(AuthFailureCode.emailAlreadyInUse);
      case 'weak-password':
        return const AuthFailure(AuthFailureCode.weakPassword);
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return const AuthFailure(AuthFailureCode.invalidCredential);
      case 'too-many-requests':
        return const AuthFailure(AuthFailureCode.tooManyRequests);
      case 'network-request-failed':
        return const AuthFailure(AuthFailureCode.network);
      case 'expired-action-code':
      case 'invalid-action-code':
        return const AuthFailure(AuthFailureCode.invalidActionCode);
      default:
        return const AuthFailure(AuthFailureCode.unknown);
    }
  }
}
