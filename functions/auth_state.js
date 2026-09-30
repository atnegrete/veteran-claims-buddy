/**
 * Decides whether the Admin SDK user record may receive the app security marker.
 * Firebase Auth stays the source of truth. This does not read or store the phone number.
 */
function assertEnrollmentConfirmed(user) {
  const emailVerified = user?.emailVerified === true;
  const factors = user?.multiFactor?.enrolledFactors;
  const factorCount = Array.isArray(factors) ? factors.length : 0;
  if (!emailVerified) {
    return { ok: false };
  }
  if (factorCount < 1) {
    return { ok: false };
  }
  return { ok: true };
}

module.exports = { assertEnrollmentConfirmed };
