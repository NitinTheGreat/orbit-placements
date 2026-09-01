import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/company_format.dart';
import 'package:orbit/models/gmail_sync.dart';

void main() {
  final now = DateTime(2026, 9, 2, 12, 0);

  group('GmailConnectionStatus', () {
    test('maps needs_reconnect from the wire', () {
      expect(
        GmailConnectionStatus.fromWire('needs_reconnect'),
        GmailConnectionStatus.needsReconnect,
      );
    });

    test('round-trips every status', () {
      for (final status in GmailConnectionStatus.values) {
        expect(GmailConnectionStatus.fromWire(status.wireName), status);
      }
    });
  });

  group('needsReconnect', () {
    test('covers both the revoked and expired states', () {
      const revoked = GmailSync(status: GmailConnectionStatus.needsReconnect);
      const expired = GmailSync(status: GmailConnectionStatus.expired);
      const connected = GmailSync(status: GmailConnectionStatus.connected);

      expect(revoked.needsReconnect, isTrue);
      expect(expired.needsReconnect, isTrue);
      expect(connected.needsReconnect, isFalse);
    });
  });

  group('isStale', () {
    test('a recent check is not stale', () {
      final sync = GmailSync(
        status: GmailConnectionStatus.connected,
        lastSyncedAt: now.subtract(const Duration(hours: 2)),
      );
      expect(sync.isStale(now), isFalse);
    });

    test('older than six hours while connected is stale', () {
      final sync = GmailSync(
        status: GmailConnectionStatus.connected,
        lastSyncedAt: now.subtract(const Duration(hours: 7)),
      );
      expect(sync.isStale(now), isTrue);
    });

    test('a disconnected account is never reported as stale', () {
      final sync = GmailSync(
        status: GmailConnectionStatus.needsReconnect,
        lastSyncedAt: now.subtract(const Duration(days: 3)),
      );
      expect(sync.isStale(now), isFalse);
    });

    test('never synced is not stale, it is simply unknown', () {
      const sync = GmailSync(status: GmailConnectionStatus.connected);
      expect(sync.isStale(now), isFalse);
    });
  });

  group('relativeSince', () {
    test('describes a missing timestamp', () {
      expect(relativeSince(null, now: now), 'never');
    });

    test('collapses the last minute to just now', () {
      expect(
        relativeSince(now.subtract(const Duration(seconds: 20)), now: now),
        'just now',
      );
    });

    test('uses minutes, hours and days with correct plurals', () {
      expect(
        relativeSince(now.subtract(const Duration(minutes: 1)), now: now),
        '1 minute ago',
      );
      expect(
        relativeSince(now.subtract(const Duration(minutes: 40)), now: now),
        '40 minutes ago',
      );
      expect(
        relativeSince(now.subtract(const Duration(hours: 1)), now: now),
        '1 hour ago',
      );
      expect(
        relativeSince(now.subtract(const Duration(days: 2)), now: now),
        '2 days ago',
      );
    });

    test('a clock skew into the future reads as just now', () {
      expect(
        relativeSince(now.add(const Duration(minutes: 5)), now: now),
        'just now',
      );
    });
  });
}
