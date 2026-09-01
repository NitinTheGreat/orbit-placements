class AppRoutes {
  static const String splash = 'splash';
  static const String login = 'login';
  static const String onboarding = 'onboarding';
  static const String companies = 'companies';
  static const String companyDetail = 'company-detail';
  static const String admin = 'admin';
}

class AppPaths {
  static const String splash = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String companies = '/companies';
  static const String companyDetail = ':companyId';
  static const String admin = '/admin';

  static String companyDetailOf(String companyId) => '$companies/$companyId';
}
