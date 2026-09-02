class GmailWebAuthUnavailable implements Exception {
  const GmailWebAuthUnavailable();

  @override
  String toString() => 'The web authorization flow is not available here.';
}

class GmailWebAuthDeclined implements Exception {
  const GmailWebAuthDeclined();
}

class GmailWebAuthFailed implements Exception {
  const GmailWebAuthFailed(this.message);

  final String message;

  @override
  String toString() => message;
}

String currentOrigin() => '';

Future<String> requestServerAuthCode({
  required String clientId,
  required List<String> scopes,
  String? loginHint,
  String? hostedDomain,
}) async {
  throw const GmailWebAuthFailed(
    'The web authorization flow is not available on this platform.',
  );
}
