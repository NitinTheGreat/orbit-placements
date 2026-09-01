import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/session/session_status.dart';
import 'package:orbit/models/gmail_sync.dart';

void main() {
  group('resolveSessionStatus', () {
    test('signed out wins over everything else', () {
      expect(
        resolveSessionStatus(
          signedIn: false,
          hasProfile: true,
          gmailStatus: GmailConnectionStatus.connected,
        ),
        SessionStatus.signedOut,
      );
    });

    test('a signed-in student without a profile onboards first', () {
      expect(
        resolveSessionStatus(
          signedIn: true,
          hasProfile: false,
          gmailStatus: GmailConnectionStatus.none,
        ),
        SessionStatus.needsOnboarding,
      );
    });

    test('profile without a Gmail connection goes to the connect step', () {
      expect(
        resolveSessionStatus(
          signedIn: true,
          hasProfile: true,
          gmailStatus: GmailConnectionStatus.none,
        ),
        SessionStatus.needsGmailConnection,
      );
    });

    test('a connected student is ready', () {
      expect(
        resolveSessionStatus(
          signedIn: true,
          hasProfile: true,
          gmailStatus: GmailConnectionStatus.connected,
        ),
        SessionStatus.ready,
      );
    });

    test('the connect step does not reappear once it has been completed', () {
      for (final status in [
        GmailConnectionStatus.connected,
        GmailConnectionStatus.expired,
        GmailConnectionStatus.error,
      ]) {
        expect(
          resolveSessionStatus(
            signedIn: true,
            hasProfile: true,
            gmailStatus: status,
          ),
          SessionStatus.ready,
          reason: 'status $status should not force the connect step again',
        );
      }
    });
  });
}
