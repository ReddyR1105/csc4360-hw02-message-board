import 'package:firebase_core/firebase_core.dart';

const messageLimit = 500;

String? nameError(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter a name.';
  if (text.runes.length > 40) return 'Use 40 characters or fewer.';
  if (RegExp(r'[\r\n\t]').hasMatch(text)) return 'Use a single line.';
  return null;
}

String? emailError(String? value) {
  final text = value?.trim() ?? '';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? passwordError(String? value, {required bool registering}) {
  final text = value ?? '';
  if (text.isEmpty) return 'Enter your password.';
  if (registering && text.length < 8) return 'Use at least 8 characters.';
  return null;
}

String? messageError(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Write a message first.';
  if (text.runes.length > messageLimit) {
    return 'Use $messageLimit characters or fewer.';
  }
  return null;
}

String friendlyError(Object error, String fallback) {
  if (error is! FirebaseException) return fallback;
  return switch (error.code) {
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Choose a stronger password.',
    'email-already-in-use' =>
      'An account already uses this email. Sign in instead.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-login-credentials' =>
      'Check your email and password and try again.',
    'user-disabled' => 'This account is disabled.',
    'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
    'network-request-failed' || 'unavailable' || 'deadline-exceeded' =>
      'The service could not be reached. Check your connection and retry.',
    'permission-denied' =>
      'Your account does not have permission for this action.',
    _ => fallback,
  };
}
