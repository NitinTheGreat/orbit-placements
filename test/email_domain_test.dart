import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/constants/app_constants.dart';

void main() {
  group('VIT email restriction', () {
    test('accepts a vitstudent.ac.in address', () {
      expect(AppConstants.isAllowedEmail('nitin@vitstudent.ac.in'), isTrue);
    });

    test('accepts regardless of casing and padding', () {
      expect(AppConstants.isAllowedEmail('  Nitin@VITStudent.AC.IN '), isTrue);
    });

    test('rejects other domains', () {
      expect(AppConstants.isAllowedEmail('someone@gmail.com'), isFalse);
      expect(AppConstants.isAllowedEmail('someone@vit.ac.in'), isFalse);
    });

    test('rejects a lookalike domain suffix', () {
      expect(AppConstants.isAllowedEmail('a@notvitstudent.ac.in'), isFalse);
      expect(
        AppConstants.isAllowedEmail('a@vitstudent.ac.in.evil.com'),
        isFalse,
      );
    });

    test('rejects null and empty values', () {
      expect(AppConstants.isAllowedEmail(null), isFalse);
      expect(AppConstants.isAllowedEmail(''), isFalse);
    });
  });
}
