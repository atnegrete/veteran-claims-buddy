enum AuthFailureCode {
  invalidEmail,
  emailAlreadyInUse,
  weakPassword,
  invalidCredential,
  tooManyRequests,
  network,
  invalidActionCode,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthFailureCode code;

  String get message {
    switch (code) {
      case AuthFailureCode.invalidEmail:
        return 'Enter a valid email address.';
      case AuthFailureCode.emailAlreadyInUse:
        return 'An account with that email already exists. Sign in instead.';
      case AuthFailureCode.weakPassword:
        return 'Use at least 6 characters.';
      case AuthFailureCode.invalidCredential:
        return 'That email and password do not match.';
      case AuthFailureCode.tooManyRequests:
        return 'Too many attempts. Wait a moment and try again.';
      case AuthFailureCode.network:
        return 'Network error. Check your connection and try again.';
      case AuthFailureCode.invalidActionCode:
        return 'This reset link is invalid or expired. Request a new one.';
      case AuthFailureCode.unknown:
        return 'Something went wrong. Try again.';
    }
  }
}
