import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/company_format.dart';

void main() {
  group('CompanyFormat.deadlineLabel', () {
    test('handles a missing deadline', () {
      expect(CompanyFormat.deadlineLabel(null), 'No deadline');
    });

    test('describes today and tomorrow', () {
      final now = DateTime.now();
      expect(CompanyFormat.deadlineLabel(now), 'Closes today');
      expect(
        CompanyFormat.deadlineLabel(now.add(const Duration(days: 1))),
        'Closes tomorrow',
      );
    });

    test('counts down within a week', () {
      final soon = DateTime.now().add(const Duration(days: 3));
      expect(CompanyFormat.deadlineLabel(soon), 'Closes in 3 days');
    });

    test('marks past deadlines as closed', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      expect(CompanyFormat.deadlineLabel(past), startsWith('Closed '));
    });
  });

  group('CompanyFormat.date', () {
    test('formats a known date', () {
      expect(CompanyFormat.date(DateTime(2026, 3, 9)), '9 Mar 2026');
    });

    test('handles null', () {
      expect(CompanyFormat.date(null), 'Not set');
    });
  });
}
