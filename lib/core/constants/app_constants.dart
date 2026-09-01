class AppConstants {
  static const String appName = 'Orbit';
  static const String appTagline = 'Never miss a placement drive';
  static const String allowedEmailDomain = 'vitstudent.ac.in';

  static bool isAllowedEmail(String? email) {
    final value = email?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return false;
    }
    return value.endsWith('@$allowedEmailDomain');
  }
}

class FirestoreCollections {
  static const String students = 'students';
  static const String companies = 'companies';
  static const String studentCompanyStatus = 'studentCompanyStatus';
}
