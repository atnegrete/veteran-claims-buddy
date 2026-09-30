/// Turns a typed U.S. or international number into E.164, or returns null.
String? toE164(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (trimmed.startsWith('+')) {
    if (digits.length < 8 || digits.length > 15) return null;
    return '+$digits';
  }
  if (digits.length == 10) return '+1$digits';
  if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
  return null;
}

/// A label safe to show after Firebase has the real number.
String maskPhoneNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return 'Text message';
  return 'Text message ending in ${digits.substring(digits.length - 4)}';
}
