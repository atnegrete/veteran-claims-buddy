class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.mfaEnrolled,
  });

  final String uid;
  final String? email;
  final bool emailVerified;

  /// True only when Firebase reported at least one enrolled second factor.
  final bool mfaEnrolled;
}
