class AppConfig {
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static bool get hasGoogleServerClientId => googleServerClientId.isNotEmpty;
}
