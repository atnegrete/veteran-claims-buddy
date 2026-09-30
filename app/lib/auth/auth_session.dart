class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.mfaEnrolled,
    this.maskedPhone,
  });

  final String uid;
  final String? email;
  final bool emailVerified;

  /// True only when Firebase reported at least one enrolled second factor.
  final bool mfaEnrolled;

  /// A display label such as "Text message ending in 0100". Never the raw number.
  final String? maskedPhone;
}
