import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants/app_config.dart';
import '../core/constants/app_constants.dart';
import 'auth_service.dart';
import 'gmail_web_auth_stub.dart'
    if (dart.library.js_interop) 'gmail_web_auth_web.dart'
    as web_auth;

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
    if (kIsWeb) {
      await _connectOnWeb();
      return;
    }

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

    await _exchange(code: serverAuthCode);
  }

  Future<void> _connectOnWeb() async {
    final String code;
    try {
      code = await web_auth.requestServerAuthCode(
        clientId: AppConfig.googleServerClientId,
        scopes: GmailScopes.required,
        loginHint: FirebaseAuth.instance.currentUser?.email,
        hostedDomain: AppConstants.allowedEmailDomain,
      );
    } on web_auth.GmailWebAuthDeclined {
      throw const GmailConnectDeclined();
    } on web_auth.GmailWebAuthFailed catch (error) {
      throw GmailConnectException(error.message);
    }

    await _exchange(code: code, redirectUri: web_auth.currentOrigin());
  }

  Future<void> _exchange({required String code, String? redirectUri}) async {
    try {
      await _functions.httpsCallable('connectGmail').call<Map<String, dynamic>>(
        <String, dynamic>{
          'code': code,
          if (redirectUri != null && redirectUri.isNotEmpty)
            'redirectUri': redirectUri,
        },
      );
    } on FirebaseFunctionsException catch (error) {
      throw GmailConnectException(
        error.message ?? 'Could not finish connecting Gmail.',
      );
    }
  }
}
