import 'package:app/auth/auth_access.dart';
import 'package:app/auth/auth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed-out deep links return to sign in', () {
    expect(
      authRedirect(access: AuthAccess.signedOut, location: '/home'),
      AuthRoutes.signIn,
    );
    expect(
      authRedirect(access: AuthAccess.signedOut, location: AuthRoutes.register),
      isNull,
    );
    expect(
      authRedirect(access: AuthAccess.signedOut, location: AuthRoutes.recovery),
      isNull,
    );
  });

  test('unverified email cannot open enrollment or onboarding', () {
    expect(
      authRedirect(
        access: AuthAccess.emailVerificationRequired,
        location: AuthRoutes.mfaEnroll,
      ),
      AuthRoutes.verifyEmail,
    );
    expect(
      authRedirect(
        access: AuthAccess.emailVerificationRequired,
        location: AuthRoutes.onboarding,
      ),
      AuthRoutes.verifyEmail,
    );
    expect(
      authRedirect(
        access: AuthAccess.emailVerificationRequired,
        location: AuthRoutes.verifyEmail,
      ),
      isNull,
    );
  });

  test('verified email without a factor stays on enrollment', () {
    expect(
      authRedirect(
        access: AuthAccess.mfaEnrollmentRequired,
        location: AuthRoutes.onboarding,
      ),
      AuthRoutes.mfaEnroll,
    );
    expect(
      authRedirect(
        access: AuthAccess.mfaEnrollmentRequired,
        location: AuthRoutes.mfaEnroll,
      ),
      isNull,
    );
  });

  test('a text-message challenge cannot open the shell', () {
    expect(
      authRedirect(
        access: AuthAccess.mfaChallengeInProgress,
        location: '/home',
      ),
      AuthRoutes.mfaChallenge,
    );
  });

  test('scheduled deletion can open only reactivation', () {
    expect(
      authRedirect(
        access: AuthAccess.deletionScheduled,
        location: AuthRoutes.signIn,
      ),
      AuthRoutes.reactivate,
    );
    expect(
      authRedirect(
        access: AuthAccess.deletionScheduled,
        location: AuthRoutes.reactivate,
      ),
      isNull,
    );
  });

  test('a ready account opens onboarding', () {
    expect(
      authRedirect(
        access: AuthAccess.authenticatedReady,
        location: AuthRoutes.signIn,
      ),
      AuthRoutes.onboarding,
    );
  });
}
