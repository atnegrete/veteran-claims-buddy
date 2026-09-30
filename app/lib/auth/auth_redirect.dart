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
  static const home = '/home';
  static const cases = '/cases';
  static const buddy = '/buddy';
  static const you = '/you';
  static const security = '/you/settings/security';
  static const deleteAccount = '/you/settings/delete';
  static const support = '/you/support';
  static const billingPremium = '/you/billing/premium';
  static const billingCases = '/you/billing/cases';
  static const legal = '/you/legal';
  static const plans = '/plans';
  static const calculator = '/calculator';

  static String caseOverview(String caseId) => '/cases/$caseId/overview';
}

const signedOutRoutes = <String>{
  AuthRoutes.signIn,
  AuthRoutes.register,
  AuthRoutes.forgotPassword,
  AuthRoutes.resetPassword,
  AuthRoutes.recovery,
};

/// Returns the path to open, or null when [location] is already allowed.
///
/// [onboardingComplete] is false until the Veteran finishes onboarding.
/// The shell stays closed until then.
String? authRedirect({
  required AuthAccess access,
  required String location,
  bool onboardingComplete = false,
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
      if (!onboardingComplete) {
        return isOnboardingLocation(location) ? null : AuthRoutes.onboarding;
      }
      if (isShellLocation(location)) return null;
      return AuthRoutes.home;
  }
}

bool isOnboardingLocation(String location) {
  return location == AuthRoutes.onboarding ||
      location.startsWith('${AuthRoutes.onboarding}/');
}

bool isShellLocation(String location) {
  const roots = <String>[
    AuthRoutes.home,
    AuthRoutes.cases,
    AuthRoutes.buddy,
    AuthRoutes.you,
    AuthRoutes.plans,
    AuthRoutes.calculator,
  ];
  for (final root in roots) {
    if (location == root || location.startsWith('$root/')) return true;
  }
  return false;
}
