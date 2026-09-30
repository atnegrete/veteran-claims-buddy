enum AuthFailureCode {
  invalidEmail,
  emailAlreadyInUse,
  weakPassword,
  invalidCredential,
  invalidPhone,
  invalidSmsCode,
  sessionExpired,
  appNotAuthorized,
  smsRegionBlocked,
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
      case AuthFailureCode.invalidPhone:
        return 'Enter a valid mobile number.';
      case AuthFailureCode.invalidSmsCode:
        return 'That code is incorrect. Try again.';
      case AuthFailureCode.sessionExpired:
        return 'That code expired. Send a new one.';
      case AuthFailureCode.appNotAuthorized:
        return 'This app is not authorized to send text messages yet.';
      case AuthFailureCode.smsRegionBlocked:
        return 'Text messages to that number\'s country are not allowed. Use the fictional U.S. test number.';
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
