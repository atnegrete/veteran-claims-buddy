import 'auth_session.dart';

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

  Future<void> sendEmailVerification();

  Future<void> sendPasswordReset(String email);

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  });

  Future<void> signOut();
}
