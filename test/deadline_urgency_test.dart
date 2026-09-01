import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/company_format.dart';

void main() {
  final now = DateTime(2026, 9, 1, 10);

  group('deadlineUrgency', () {
    test('a missing deadline is unknown', () {
      expect(deadlineUrgency(null, now: now), DeadlineUrgency.unknown);
    });

    test('a past deadline has passed', () {
      expect(
        deadlineUrgency(DateTime(2026, 8, 30), now: now),
        DeadlineUrgency.passed,
      );
    });

    test('today reads as today regardless of the hour', () {
      expect(
        deadlineUrgency(DateTime(2026, 9, 1, 23, 59), now: now),
        DeadlineUrgency.today,
      );
    });

    test('within two days is imminent', () {
      expect(
        deadlineUrgency(DateTime(2026, 9, 3), now: now),
        DeadlineUrgency.imminent,
      );
    });

    test('within a week is this week', () {
      expect(
        deadlineUrgency(DateTime(2026, 9, 7), now: now),
        DeadlineUrgency.thisWeek,
      );
    });

    test('beyond a week is distant', () {
      expect(
        deadlineUrgency(DateTime(2026, 10, 1), now: now),
        DeadlineUrgency.distant,
      );
    });
  });

  group('isPressing', () {
    test('only today and imminent are pressing', () {
      expect(DeadlineUrgency.today.isPressing, isTrue);
      expect(DeadlineUrgency.imminent.isPressing, isTrue);
      expect(DeadlineUrgency.thisWeek.isPressing, isFalse);
      expect(DeadlineUrgency.distant.isPressing, isFalse);
      expect(DeadlineUrgency.passed.isPressing, isFalse);
      expect(DeadlineUrgency.unknown.isPressing, isFalse);
    });
  });
}
