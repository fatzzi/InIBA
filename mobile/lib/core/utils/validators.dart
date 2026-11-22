const String kIbaDomain = '@khi.iba.edu.pk';

class Validators {
  /// SCRUM-68: only @khi.iba.edu.pk emails are allowed.
  static String? email(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v.isEmpty) {
      return 'Email is required.';
    }
    if (!v.endsWith(kIbaDomain) || v.length == kIbaDomain.length) {
      return 'Only $kIbaDomain emails can join InIba.';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) {
      return 'Password is required.';
    }
    if (v.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  /// SCRUM-68: passwords must match.
  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != original) {
      return 'Passwords do not match.';
    }
    return null;
  }
}
