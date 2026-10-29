import 'package:app/auth/auth_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed out stays signed out', () {
    expect(
      resolveAuthAccess(
        signedIn: false,
        emailVerified: false,
        mfaEnrolled: false,
      ),
      AuthAccess.signedOut,
    );
  });

  test('unverified email cannot reach enrollment', () {
    expect(
      resolveAuthAccess(
        signedIn: true,
        emailVerified: false,
        mfaEnrolled: false,
      ),
      AuthAccess.emailVerificationRequired,
    );
  });

  test('verified email without a factor requires enrollment', () {
    expect(
      resolveAuthAccess(
        signedIn: true,
        emailVerified: true,
        mfaEnrolled: false,
      ),
      AuthAccess.mfaEnrollmentRequired,
    );
  });

  test('verified email with a factor waits for the server marker', () {
    expect(
      resolveAuthAccess(signedIn: true, emailVerified: true, mfaEnrolled: true),
      AuthAccess.mfaEnrollmentRequired,
    );
  });

  test('verified email with a factor and server marker is ready', () {
    expect(
      resolveAuthAccess(
        signedIn: true,
        emailVerified: true,
        mfaEnrolled: true,
        serverAuthConfirmed: true,
      ),
      AuthAccess.authenticatedReady,
    );
  });

  test('an open text-message challenge blocks a signed-out session', () {
    expect(
      resolveAuthAccess(
        signedIn: false,
        emailVerified: false,
        mfaEnrolled: false,
        mfaChallengeInProgress: true,
      ),
      AuthAccess.mfaChallengeInProgress,
    );
  });

  test('scheduled deletion limits a signed-in account', () {
    expect(
      resolveAuthAccess(
        signedIn: true,
        emailVerified: true,
        mfaEnrolled: true,
        deletionScheduled: true,
      ),
      AuthAccess.deletionScheduled,
    );
  });

  test('recovery required limits a signed-out session', () {
    expect(
      resolveAuthAccess(
        signedIn: false,
        emailVerified: false,
        mfaEnrolled: false,
        recoveryRequired: true,
      ),
      AuthAccess.accountRecoveryRequired,
    );
  });
}
