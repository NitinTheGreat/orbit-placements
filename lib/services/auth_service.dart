import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants/app_config.dart';
import '../core/constants/app_constants.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SignInCancelled implements Exception {
  const SignInCancelled();
}

String describeWebSignInFailure(String code, String? message) {
  final detail = (message ?? '').toLowerCase();

  if (code == 'unauthorized-domain' ||
      detail.contains('redirect_uri_mismatch') ||
      detail.contains('origin')) {
    return
        'Google sign-in is misconfigured for the web app. The OAuth client '
        'needs https://orbit-507316.web.app under Authorized JavaScript '
        'origins, added alongside any entries already there.';
  }

  if (code == 'operation-not-allowed') {
    return
        'Google sign-in is switched off for this Firebase project. Enable the '
        'Google provider in Firebase Authentication.';
  }

  if (code == 'popup-blocked') {
    return 'Your browser blocked the sign-in popup. Allow popups and retry.';
  }

  return message ?? 'Google sign-in failed. Please try again.';
}

class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  static bool _initialized = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _webSubscription;

  User? get currentUser => _auth.currentUser;

  Stream<User?> idTokenChanges() => _auth.idTokenChanges();

  Future<void> ensureInitialized({String? serverClientId}) async {
    if (_initialized) {
      return;
    }
    final resolvedServerClientId =
        serverClientId ??
        (AppConfig.hasGoogleServerClientId
            ? AppConfig.googleServerClientId
            : null);
    await _googleSignIn.initialize(
      clientId: kIsWeb ? resolvedServerClientId : null,
      serverClientId: kIsWeb ? null : resolvedServerClientId,
      hostedDomain: AppConstants.allowedEmailDomain,
    );
    _initialized = true;
  }

  Future<User> _signInFromWebAccount(GoogleSignInAccount account) async {
    if (!AppConstants.isAllowedEmail(account.email)) {
      await _googleSignIn.signOut();
      throw AuthException(
        'Please use your VIT email (@${AppConstants.allowedEmailDomain}). '
        '${account.email} is not a VIT student account.',
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      await _googleSignIn.signOut();
      throw const AuthException(
        'Google did not return an identity token. Please try again.',
      );
    }

    final userCredential = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    final user = userCredential.user;
    if (user == null || !AppConstants.isAllowedEmail(user.email)) {
      await signOut();
      throw AuthException(
        'Please use your VIT email (@${AppConstants.allowedEmailDomain}).',
      );
    }
    return user;
  }

  Future<void> startWebSignInListener({
    void Function(Object error)? onError,
  }) async {
    if (!kIsWeb || _webSubscription != null) {
      return;
    }
    await ensureInitialized();
    _webSubscription = _googleSignIn.authenticationEvents.listen((
      event,
    ) async {
      if (event is! GoogleSignInAuthenticationEventSignIn) {
        return;
      }
      try {
        await _signInFromWebAccount(event.user);
      } on Object catch (error) {
        onError?.call(error);
      }
    }, onError: (Object error) => onError?.call(error));
  }

  Future<void> stopWebSignInListener() async {
    await _webSubscription?.cancel();
    _webSubscription = null;
  }

  Future<User> signInWithGoogle() async {
    if (kIsWeb) {
      throw const AuthException(
        'Use the Google button to sign in on the web.',
      );
    }

    await ensureInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw const AuthException(
        'Google sign-in is not supported on this platform.',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelled();
      }
      throw AuthException(
        error.description ?? 'Google sign-in failed. Please try again.',
      );
    }

    if (!AppConstants.isAllowedEmail(account.email)) {
      await _googleSignIn.signOut();
      throw AuthException(
        'Please use your VIT email (@${AppConstants.allowedEmailDomain}). '
        '${account.email} is not a VIT student account.',
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      await _googleSignIn.signOut();
      throw const AuthException(
        'Google did not return an identity token. Please try again.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user == null || !AppConstants.isAllowedEmail(user.email)) {
      await signOut();
      throw AuthException(
        'Please use your VIT email (@${AppConstants.allowedEmailDomain}).',
      );
    }

    return user;
  }

  Future<bool> hasAdminClaim({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    final token = await user.getIdTokenResult(forceRefresh);
    return token.claims?['admin'] == true;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}
