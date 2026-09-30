import 'auth_session.dart';
import 'mfa_challenge.dart';

abstract class AuthGateway {
  Stream<AuthSession?> watchSession();

  Future<AuthSession?> currentSession();

  Future<void> createAccount({
    required String email,
    required String password,
  });

  Future<void> signIn({
    required String email,
    required String password,
  });

  /// Sends an enrollment text. [phoneNumber] is E.164.
  Future<void> sendEnrollmentCode(String phoneNumber);

  Future<void> confirmEnrollmentCode(String smsCode);

  /// Sends a sign-in text for one enrolled factor. Call after [signIn] throws
  /// [MfaChallengeRequired].
  Future<void> sendChallengeCode(String factorUid);

  Future<void> confirmChallengeCode(String smsCode);

  /// Asks the server to record verified email plus an enrolled factor.
  /// The client cannot write that marker itself.
  Future<void> confirmServerAuthState();

  /// Asks the server to clear the enrollment marker after the last factor is gone.
  Future<void> clearServerAuthState();

  Future<void> reauthenticate(String password);

  Future<void> unenrollFactor(String factorUid);

  Future<void> sendEmailVerification();

  /// Fetches the account from Firebase so a verification link is visible.
  Future<void> reloadCurrentUser();

  Future<void> sendPasswordReset(String email);

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  });

  Future<void> signOut();
}
