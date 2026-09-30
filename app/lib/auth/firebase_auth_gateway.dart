import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'auth_failure.dart';
import 'auth_gateway.dart';
import 'auth_session.dart';
import 'mfa_challenge.dart';
import 'phone_number.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  String? _verificationId;
  PhoneAuthCredential? _autoCredential;
  MultiFactorResolver? _resolver;

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
  Future<void> sendEnrollmentCode(String phoneNumber) {
    return _guard(() async {
      final user = _requireUser();
      final session = await user.multiFactor.getSession();
      _clearPhoneChallenge();
      _verificationId = await _awaitPhoneCode(
        phoneNumber: phoneNumber,
        multiFactorSession: session,
      );
    });
  }

  @override
  Future<void> confirmEnrollmentCode(String smsCode) {
    return _guard(() async {
      final user = _requireUser();
      final credential = _credentialFromCode(smsCode);
      await user.multiFactor.enroll(
        PhoneMultiFactorGenerator.getAssertion(credential),
        displayName: 'Text message',
      );
      _clearPhoneChallenge();
      await user.reload();
    });
  }

  @override
  Future<void> sendChallengeCode(String factorUid) {
    return _guard(() async {
      final resolver = _resolver;
      if (resolver == null) {
        throw const AuthFailure(AuthFailureCode.sessionExpired);
      }
      final matches = resolver.hints.whereType<PhoneMultiFactorInfo>().where(
        (factor) => factor.uid == factorUid,
      );
      if (matches.isEmpty) {
        throw const AuthFailure(AuthFailureCode.sessionExpired);
      }
      _verificationId = null;
      _autoCredential = null;
      _verificationId = await _awaitPhoneCode(
        multiFactorInfo: matches.first,
        multiFactorSession: resolver.session,
      );
    });
  }

  @override
  Future<void> confirmChallengeCode(String smsCode) {
    return _guard(() async {
      final resolver = _resolver;
      if (resolver == null) {
        throw const AuthFailure(AuthFailureCode.sessionExpired);
      }
      final credential = _credentialFromCode(smsCode);
      await resolver.resolveSignIn(
        PhoneMultiFactorGenerator.getAssertion(credential),
      );
      _clearPhoneChallenge();
    });
  }

  @override
  Future<void> sendEmailVerification() {
    return _guard(() async {
      final user = _requireUser();
      await user.sendEmailVerification();
    });
  }

  @override
  Future<void> reloadCurrentUser() {
    return _guard(() async {
      final user = _requireUser();
      await user.reload();
      await _auth.currentUser?.getIdToken(true);
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
  Future<void> signOut() async {
    _clearPhoneChallenge();
    await _auth.signOut();
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure(AuthFailureCode.unknown);
    return user;
  }

  PhoneAuthCredential _credentialFromCode(String smsCode) {
    final auto = _autoCredential;
    final verificationId = _verificationId;
    if (verificationId != null && verificationId.isNotEmpty) {
      return PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
    }
    if (auto != null) return auto;
    throw const AuthFailure(AuthFailureCode.sessionExpired);
  }

  Future<String> _awaitPhoneCode({
    String? phoneNumber,
    PhoneMultiFactorInfo? multiFactorInfo,
    MultiFactorSession? multiFactorSession,
  }) {
    final completer = Completer<String>();
    _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      multiFactorInfo: multiFactorInfo,
      multiFactorSession: multiFactorSession,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) {
        _autoCredential = credential;
        final id = credential.verificationId;
        if (id != null && id.isNotEmpty) _verificationId = id;
        if (!completer.isCompleted) completer.complete(id ?? '');
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId ??= verificationId;
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 70),
      onTimeout: () => throw const AuthFailure(AuthFailureCode.unknown),
    );
  }

  void _clearPhoneChallenge() {
    _verificationId = null;
    _autoCredential = null;
    _resolver = null;
  }

  Future<AuthSession?> _sessionFor(User? user) async {
    if (user == null) return null;
    var mfaEnrolled = false;
    String? maskedPhone;
    try {
      final factors = await user.multiFactor.getEnrolledFactors();
      mfaEnrolled = factors.isNotEmpty;
      for (final factor in factors) {
        if (factor is PhoneMultiFactorInfo) {
          maskedPhone = maskPhoneNumber(factor.phoneNumber);
          break;
        }
      }
    } on FirebaseAuthException {
      mfaEnrolled = false;
    }
    return AuthSession(
      uid: user.uid,
      email: user.email,
      emailVerified: user.emailVerified,
      mfaEnrolled: mfaEnrolled,
      maskedPhone: maskedPhone,
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on MfaChallengeRequired {
      rethrow;
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthMultiFactorException catch (error) {
      _resolver = error.resolver;
      throw MfaChallengeRequired(_hintsFor(error.resolver.hints));
    } on FirebaseAuthException catch (error) {
      throw _map(error);
    }
  }

  List<PhoneFactorHint> _hintsFor(List<MultiFactorInfo> hints) {
    return [
      for (final hint in hints)
        if (hint is PhoneMultiFactorInfo)
          PhoneFactorHint(
            uid: hint.uid,
            label: maskPhoneNumber(hint.phoneNumber),
          ),
    ];
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
      case 'invalid-phone-number':
        return const AuthFailure(AuthFailureCode.invalidPhone);
      case 'invalid-verification-code':
        return const AuthFailure(AuthFailureCode.invalidSmsCode);
      case 'invalid-verification-id':
      case 'session-expired':
        return const AuthFailure(AuthFailureCode.sessionExpired);
      case 'missing-client-identifier':
      case 'app-not-authorized':
      case 'captcha-check-failed':
        return const AuthFailure(AuthFailureCode.appNotAuthorized);
      case 'operation-not-allowed':
        final message = (error.message ?? '').toLowerCase();
        if (message.contains('region')) {
          return const AuthFailure(AuthFailureCode.smsRegionBlocked);
        }
        return const AuthFailure(AuthFailureCode.unknown);
      case 'too-many-requests':
      case 'quota-exceeded':
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
