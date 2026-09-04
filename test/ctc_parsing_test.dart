import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/ctc_parsing.dart';

void main() {
  group('parsing the real production CTC strings', () {
    void expectRange(String raw, double min, double max) {
      final range = parseCtc(raw);
      expect(range, isNotNull, reason: raw);
      expect(range!.minLpa, closeTo(min, 0.001), reason: raw);
      expect(range.maxLpa, closeTo(max, 0.001), reason: raw);
    }

    test('a plain LPA figure', () {
      expectRange('20 LPA', 20, 20);
      expectRange('8.5 LPA', 8.5, 8.5);
      expectRange('11.58 LPA', 11.58, 11.58);
    });

    test('an LPA figure with a trailing qualifier', () {
      expectRange('10.00 LPA (If converted)', 10, 10);
      expectRange('7.5 LPA if converted', 7.5, 7.5);
    });

    test('a raw rupee figure becomes lakhs per annum', () {
      expectRange('800000', 8, 8);
      expectRange('1365000 (If Converted)', 13.65, 13.65);
      expectRange('8,00,000', 8, 8);
    });

    test('a range keeps both ends', () {
      expectRange('7.5 LPA - 16 Lakhs', 7.5, 16);
      expectRange('INR 12 LPA - INR 18 LPA', 12, 18);
    });

    test('crore is read as hundreds of lakhs', () {
      expectRange('1.2 crore', 120, 120);
    });

    test('text with no figure yields nothing', () {
      expect(parseCtc('Refer Attachment'), isNull);
      expect(parseCtc('To be announced later'), isNull);
      expect(parseCtc(''), isNull);
      expect(parseCtc(null), isNull);
    });

    test('the best of a range is its upper end', () {
      expect(parseCtc('7.5 LPA - 16 Lakhs')!.bestLpa, 16);
    });
  });

  group('best offer', () {
    test('takes the highest across several offers', () {
      expect(bestOfferLpa(['8 LPA', '20 LPA', '11.58 LPA']), 20);
    });

    test('ignores unparseable entries', () {
      expect(bestOfferLpa(['Refer Attachment', '12 LPA']), 12);
    });

    test('is null when nothing parses', () {
      expect(bestOfferLpa(['Refer Attachment', null]), isNull);
      expect(bestOfferLpa(const []), isNull);
    });
  });

  group('thresholds', () {
    test('an unset config is not configured', () {
      expect(OfferThresholds.fromMap(null).isConfigured, isFalse);
      expect(
        OfferThresholds.fromMap(<String, dynamic>{
          'dream': null,
          'superDream': null,
        }).isConfigured,
        isFalse,
      );
    });

    test('a set config reads both numbers', () {
      final thresholds = OfferThresholds.fromMap(<String, dynamic>{
        'dream': 1.5,
        'superDream': 2,
      });
      expect(thresholds.isConfigured, isTrue);
      expect(thresholds.dream, 1.5);
      expect(thresholds.superDream, 2.0);
    });

    test('nothing is surfaced while the config is unset', () {
      expect(
        stillEligibleAbove(
          bestOfferLpa: 10,
          driveCtc: '40 LPA',
          thresholds: const OfferThresholds(),
        ),
        isFalse,
      );
    });

    test('a drive clearing the multiplier is surfaced', () {
      const thresholds = OfferThresholds(dream: 1.5, superDream: 2);
      expect(
        stillEligibleAbove(
          bestOfferLpa: 10,
          driveCtc: '25 LPA',
          thresholds: thresholds,
        ),
        isTrue,
      );
      expect(
        stillEligibleAbove(
          bestOfferLpa: 10,
          driveCtc: '15 LPA',
          thresholds: thresholds,
        ),
        isFalse,
      );
    });

    test('a student with no parseable offer is never surfaced anything', () {
      expect(
        stillEligibleAbove(
          bestOfferLpa: null,
          driveCtc: '40 LPA',
          thresholds: const OfferThresholds(dream: 1.5),
        ),
        isFalse,
      );
    });
  });
}
