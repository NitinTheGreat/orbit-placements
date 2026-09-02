import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const String _gisScript = 'https://accounts.google.com/gsi/client';

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

extension type _CodeClient._(JSObject _) implements JSObject {
  external void requestCode();
}

extension type _CodeResponse._(JSObject _) implements JSObject {
  external String? get code;
  external String? get error;
  @JS('error_description')
  external String? get errorDescription;
}

@JS('google.accounts.oauth2.initCodeClient')
external _CodeClient _initCodeClient(JSObject config);

@JS('google')
external JSObject? get _google;

bool _gisReady() {
  final google = _google;
  if (google == null) {
    return false;
  }
  final accounts = google.getProperty<JSObject?>('accounts'.toJS);
  if (accounts == null) {
    return false;
  }
  return accounts.getProperty<JSObject?>('oauth2'.toJS) != null;
}

Future<void> _ensureGisLoaded() async {
  if (_gisReady()) {
    return;
  }

  final existing = web.document.querySelector('script[src="$_gisScript"]');
  final completer = Completer<void>();

  void settle() {
    if (completer.isCompleted) {
      return;
    }
    if (_gisReady()) {
      completer.complete();
    } else {
      completer.completeError(
        const GmailWebAuthFailed(
          'Google sign-in could not load. Check your connection and retry.',
        ),
      );
    }
  }

  if (existing != null) {
    existing.addEventListener('load', ((JSAny _) => settle()).toJS);
    existing.addEventListener(
      'error',
      ((JSAny _) => settle()).toJS,
    );
  } else {
    final script = web.document.createElement('script') as web.HTMLScriptElement
      ..src = _gisScript
      ..async = true
      ..defer = true;
    script.addEventListener('load', ((JSAny _) => settle()).toJS);
    script.addEventListener('error', ((JSAny _) => settle()).toJS);
    web.document.head!.append(script);
  }

  await completer.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () => throw const GmailWebAuthFailed(
      'Google sign-in took too long to load. Please retry.',
    ),
  );
}

String currentOrigin() => web.window.location.origin;

Future<String> requestServerAuthCode({
  required String clientId,
  required List<String> scopes,
  String? loginHint,
  String? hostedDomain,
}) async {
  if (clientId.isEmpty) {
    throw const GmailWebAuthFailed(
      'This build has no Google client id, so Gmail cannot be connected.',
    );
  }

  await _ensureGisLoaded();

  final completer = Completer<String>();

  void fail(Object error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  final config = JSObject()
    ..setProperty('client_id'.toJS, clientId.toJS)
    ..setProperty('scope'.toJS, scopes.join(' ').toJS)
    ..setProperty('ux_mode'.toJS, 'popup'.toJS)
    ..setProperty('include_granted_scopes'.toJS, true.toJS)
    ..setProperty(
      'callback'.toJS,
      ((_CodeResponse response) {
        final code = response.code;
        if (code != null && code.isNotEmpty) {
          if (!completer.isCompleted) {
            completer.complete(code);
          }
          return;
        }
        final error = response.error;
        if (error == 'access_denied' || error == 'user_cancel') {
          fail(const GmailWebAuthDeclined());
          return;
        }
        fail(
          GmailWebAuthFailed(
            response.errorDescription ??
                'Google did not return an authorization code.',
          ),
        );
      }).toJS,
    )
    ..setProperty(
      'error_callback'.toJS,
      ((JSObject error) {
        final type = error.getProperty<JSString?>('type'.toJS)?.toDart;
        if (type == 'popup_closed' || type == 'popup_failed_to_open') {
          fail(const GmailWebAuthDeclined());
          return;
        }
        fail(
          GmailWebAuthFailed(
            error.getProperty<JSString?>('message'.toJS)?.toDart ??
                'Google could not complete the authorization.',
          ),
        );
      }).toJS,
    );

  if (hostedDomain != null && hostedDomain.isNotEmpty) {
    config.setProperty('hd'.toJS, hostedDomain.toJS);
  }
  if (loginHint != null && loginHint.isNotEmpty) {
    config.setProperty('login_hint'.toJS, loginHint.toJS);
  }

  _initCodeClient(config).requestCode();

  return completer.future;
}
