import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/gmail_sync.dart';
import 'package:orbit/services/gmail_connect_service.dart';

void main() {
  group('Gmail scope', () {
    test('requests read-only Gmail access and nothing else', () {
      expect(GmailScopes.required, [
        'https://www.googleapis.com/auth/gmail.readonly',
      ]);
    });
  });

  group('GmailConnectionStatus', () {
    test('maps every wire name back to its enum value', () {
      for (final status in GmailConnectionStatus.values) {
        expect(GmailConnectionStatus.fromWire(status.wireName), status);
      }
    });

    test('treats missing or unknown values as not connected', () {
      expect(GmailConnectionStatus.fromWire(null), GmailConnectionStatus.none);
      expect(
        GmailConnectionStatus.fromWire('nonsense'),
        GmailConnectionStatus.none,
      );
    });
  });

  group('GmailSync', () {
    test('a missing map means never connected', () {
      const sync = GmailSync();
      expect(GmailSync.fromMap(null).status, GmailConnectionStatus.none);
      expect(sync.isConnected, isFalse);
      expect(sync.hasEverConnected, isFalse);
    });

    test('reads the fields the function writes', () {
      final sync = GmailSync.fromMap(<String, dynamic>{
        'status': 'connected',
        'historyId': 987654,
        'lastError': null,
      });

      expect(sync.status, GmailConnectionStatus.connected);
      expect(sync.historyId, '987654');
      expect(sync.isConnected, isTrue);
    });

    test('an expired connection still counts as having connected once', () {
      final sync = GmailSync.fromMap(<String, dynamic>{'status': 'expired'});
      expect(sync.isConnected, isFalse);
      expect(sync.hasEverConnected, isTrue);
    });
  });
}
