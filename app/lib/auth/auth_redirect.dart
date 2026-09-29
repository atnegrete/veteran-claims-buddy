import 'auth_access.dart';

abstract final class AuthRoutes {
  static const signIn = '/sign-in';
  static const register = '/register';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const mfaEnroll = '/mfa/enroll';
  static const mfaChallenge = '/mfa/challenge';
  static const reactivate = '/account/reactivate';
  static const recovery = '/account/recovery';
  static const onboarding = '/onboarding';
}

const signedOutRoutes = <String>{
  AuthRoutes.signIn,
  AuthRoutes.register,
  AuthRoutes.forgotPassword,
  AuthRoutes.resetPassword,
  AuthRoutes.recovery,
};

/// Returns the path to open, or null when [location] is already allowed.
String? authRedirect({
  required AuthAccess access,
  required String location,
}) {
  switch (access) {
    case AuthAccess.signedOut:
      return signedOutRoutes.contains(location) ? null : AuthRoutes.signIn;
    case AuthAccess.emailVerificationRequired:
      return location == AuthRoutes.verifyEmail ? null : AuthRoutes.verifyEmail;
    case AuthAccess.mfaEnrollmentRequired:
      if (location == AuthRoutes.mfaEnroll || location == AuthRoutes.recovery) {
        return null;
      }
      return AuthRoutes.mfaEnroll;
    case AuthAccess.mfaChallengeInProgress:
      if (location == AuthRoutes.mfaChallenge || location == AuthRoutes.recovery) {
        return null;
      }
      return AuthRoutes.mfaChallenge;
    case AuthAccess.accountRecoveryRequired:
      return location == AuthRoutes.recovery ? null : AuthRoutes.recovery;
    case AuthAccess.deletionScheduled:
      return location == AuthRoutes.reactivate ? null : AuthRoutes.reactivate;
    case AuthAccess.authenticatedReady:
      return location == AuthRoutes.onboarding ? null : AuthRoutes.onboarding;
  }
}
