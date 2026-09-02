import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/services/auth_service.dart';

void main() {
  group('web sign-in failure messages', () {
    test('a redirect uri mismatch names the JavaScript origin to add', () {
      final message = describeWebSignInFailure(
        'auth/invalid-credential',
        'Error 400: redirect_uri_mismatch',
      );
      expect(message, contains('orbit-507316.web.app'));
      expect(message, contains('Authorized JavaScript'));
      expect(message, contains('alongside any entries already there'));
    });

    test('an unauthorized domain says the same thing', () {
      final message = describeWebSignInFailure('unauthorized-domain', null);
      expect(message, contains('orbit-507316.web.app'));
    });

    test('a disabled provider points at the right console page', () {
      final message = describeWebSignInFailure('operation-not-allowed', null);
      expect(message, contains('Firebase Authentication'));
    });

    test('a blocked popup tells the student what to do', () {
      final message = describeWebSignInFailure('popup-blocked', null);
      expect(message, contains('Allow popups'));
    });

    test('anything else passes the original message through', () {
      expect(
        describeWebSignInFailure('network-request-failed', 'A network error'),
        'A network error',
      );
    });

    test('an unknown failure with no message still reads sensibly', () {
      expect(
        describeWebSignInFailure('something-new', null),
        'Google sign-in failed. Please try again.',
      );
    });
  });
}
