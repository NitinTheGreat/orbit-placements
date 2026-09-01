import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/drive_list_empty_state.dart';

void main() {
  group('resolveEmptyState', () {
    test('a disconnected inbox outranks everything else', () {
      expect(
        resolveEmptyState(
          gmailConnected: false,
          companyCount: 12,
          optedOutOfAll: false,
        ),
        DriveListEmptyState.gmailDisconnected,
      );
    });

    test('connected with nothing found says no drives yet', () {
      expect(
        resolveEmptyState(
          gmailConnected: true,
          companyCount: 0,
          optedOutOfAll: false,
        ),
        DriveListEmptyState.noDrives,
      );
    });

    test('drives that exist but are all opted out get their own state', () {
      expect(
        resolveEmptyState(
          gmailConnected: true,
          companyCount: 5,
          optedOutOfAll: true,
        ),
        DriveListEmptyState.allOptedOut,
      );
    });

    test('a normal list produces no empty state', () {
      expect(
        resolveEmptyState(
          gmailConnected: true,
          companyCount: 5,
          optedOutOfAll: false,
        ),
        isNull,
      );
    });

    test('no drives beats opted out when both could apply', () {
      expect(
        resolveEmptyState(
          gmailConnected: true,
          companyCount: 0,
          optedOutOfAll: true,
        ),
        DriveListEmptyState.noDrives,
      );
    });
  });

  group('everyDriveOptedOut', () {
    test('is false when nothing is loaded yet', () {
      expect(everyDriveOptedOut(companyCount: 0, optedOutCount: 0), isFalse);
    });

    test('is false while at least one drive is still tracked', () {
      expect(everyDriveOptedOut(companyCount: 3, optedOutCount: 2), isFalse);
    });

    test('is true once every loaded drive is opted out', () {
      expect(everyDriveOptedOut(companyCount: 3, optedOutCount: 3), isTrue);
    });

    test('tolerates more opt-out records than loaded drives', () {
      expect(everyDriveOptedOut(companyCount: 3, optedOutCount: 9), isTrue);
    });
  });
}
