import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

class GmailScopes {
  static const String readonly =
      'https://www.googleapis.com/auth/gmail.readonly';

  static const List<String> required = <String>[readonly];
}

class GmailConnectException implements Exception {
  const GmailConnectException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GmailConnectDeclined implements Exception {
  const GmailConnectDeclined();
}

class GmailConnectService {
  GmailConnectService({
    GoogleSignIn? googleSignIn,
    FirebaseFunctions? functions,
    AuthService? authService,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _authService = authService ?? AuthService();

  final GoogleSignIn _googleSignIn;
  final FirebaseFunctions _functions;
  final AuthService _authService;

  Future<void> connect() async {
    await _authService.ensureInitialized();

    final String serverAuthCode;

    try {
      final authorization = await _googleSignIn.authorizationClient
          .authorizeServer(GmailScopes.required);

      if (authorization == null) {
        throw const GmailConnectDeclined();
      }
      serverAuthCode = authorization.serverAuthCode;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GmailConnectDeclined();
      }
      throw GmailConnectException(
        error.description ?? 'Google did not grant access to Gmail.',
      );
    }

    try {
      await _functions.httpsCallable('connectGmail').call<Map<String, dynamic>>(
        <String, dynamic>{'code': serverAuthCode},
      );
    } on FirebaseFunctionsException catch (error) {
      throw GmailConnectException(
        error.message ?? 'Could not finish connecting Gmail.',
      );
    }
  }
}
