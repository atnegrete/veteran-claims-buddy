class PhoneFactorHint {
  const PhoneFactorHint({
    required this.uid,
    required this.label,
  });

  final String uid;
  final String label;
}

/// Email and password were accepted, and a second factor is still required.
class MfaChallengeRequired implements Exception {
  const MfaChallengeRequired(this.hints);

  final List<PhoneFactorHint> hints;
}
