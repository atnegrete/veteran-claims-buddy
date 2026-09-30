enum AuthAccess {
  signedOut,
  emailVerificationRequired,
  mfaEnrollmentRequired,
  mfaChallengeInProgress,
  authenticatedReady,
  accountRecoveryRequired,
  deletionScheduled,
}

/// Client view of the gate. Firebase Auth stays the source of truth for the
/// user and enrolled factors. Deletion and recovery flags are app state.
AuthAccess resolveAuthAccess({
  required bool signedIn,
  required bool emailVerified,
  required bool mfaEnrolled,
  bool mfaChallengeInProgress = false,
  bool deletionScheduled = false,
  bool recoveryRequired = false,
  bool serverAuthConfirmed = false,
}) {
  if (!signedIn) {
    if (mfaChallengeInProgress) return AuthAccess.mfaChallengeInProgress;
    if (recoveryRequired) return AuthAccess.accountRecoveryRequired;
    return AuthAccess.signedOut;
  }
  if (deletionScheduled) return AuthAccess.deletionScheduled;
  if (!emailVerified) return AuthAccess.emailVerificationRequired;
  if (mfaChallengeInProgress) return AuthAccess.mfaChallengeInProgress;
  if (!mfaEnrolled || !serverAuthConfirmed) {
    return AuthAccess.mfaEnrollmentRequired;
  }
  return AuthAccess.authenticatedReady;
}
