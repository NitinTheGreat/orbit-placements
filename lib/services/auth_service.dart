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

  if (code == 'unauthorized-domain' || detail.contains('redirect_uri_mismatch')) {
    return
        'Google sign-in is misconfigured for the web app. The OAuth client is '
        'missing its authorized redirect URI '
        'https://orbit-507316.firebaseapp.com/__/auth/handler. Add it back in '
        'Google Cloud console credentials, alongside any others already there.';
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
      serverClientId: resolvedServerClientId,
      hostedDomain: AppConstants.allowedEmailDomain,
    );
    _initialized = true;
  }

  Future<User> signInWithGoogle() async {
    if (kIsWeb) {
      return _signInWithPopup();
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

  Future<User> _signInWithPopup() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters(<String, String>{
        'hd': AppConstants.allowedEmailDomain,
        'prompt': 'select_account',
      });

    final UserCredential userCredential;
    try {
      userCredential = await _auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        throw const SignInCancelled();
      }
      throw AuthException(describeWebSignInFailure(error.code, error.message));
    }

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
