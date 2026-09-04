import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/services/notification_route.dart';

void main() {
  setUp(() => pendingCompanyId.value = null);
  tearDown(() => pendingCompanyId.value = null);

  group('reading the company out of a notification', () {
    test('a drive notification carries its company id', () {
      expect(
        companyIdFromMessage(<String, dynamic>{
          'companyId': 'Pl0FJiGtb2Nk94ZOF3Mq',
          'trigger': 'round_result',
        }),
        'Pl0FJiGtb2Nk94ZOF3Mq',
      );
    });

    test('every trigger the server sends is a tap target', () {
      for (final trigger in [
        'action_needed',
        'deadline_hour',
        'round_result',
        'new_round',
        'new_company',
      ]) {
        expect(
          companyIdFromMessage(<String, dynamic>{
            'companyId': 'company-1',
            'trigger': trigger,
          }),
          'company-1',
          reason: trigger,
        );
      }
    });

    test('the silent widget refresh is never a tap target', () {
      expect(
        companyIdFromMessage(<String, dynamic>{
          'orbitAction': refreshWidgetAction,
          'companyId': 'company-1',
        }),
        isNull,
      );
    });

    test('a payload with no company id yields nothing', () {
      expect(companyIdFromMessage(<String, dynamic>{}), isNull);
      expect(companyIdFromMessage(null), isNull);
      expect(
        companyIdFromMessage(<String, dynamic>{'trigger': 'new_round'}),
        isNull,
      );
    });

    test('a blank or non-string company id yields nothing', () {
      expect(companyIdFromMessage(<String, dynamic>{'companyId': ''}), isNull);
      expect(companyIdFromMessage(<String, dynamic>{'companyId': '   '}), isNull);
      expect(companyIdFromMessage(<String, dynamic>{'companyId': 42}), isNull);
      expect(companyIdFromMessage(<String, dynamic>{'companyId': null}), isNull);
    });

    test('surrounding whitespace is trimmed', () {
      expect(
        companyIdFromMessage(<String, dynamic>{'companyId': '  company-1 '}),
        'company-1',
      );
    });
  });

  group('remembering the tap', () {
    test('a real tap sets the pending company', () {
      rememberTappedCompany(<String, dynamic>{'companyId': 'company-1'});
      expect(pendingCompanyId.value, 'company-1');
    });

    test('an unusable payload leaves the pending company alone', () {
      pendingCompanyId.value = 'already-here';
      rememberTappedCompany(<String, dynamic>{'orbitAction': refreshWidgetAction});
      rememberTappedCompany(<String, dynamic>{});
      rememberTappedCompany(null);
      expect(pendingCompanyId.value, 'already-here');
    });

    test('a later tap replaces an earlier one', () {
      rememberTappedCompany(<String, dynamic>{'companyId': 'first'});
      rememberTappedCompany(<String, dynamic>{'companyId': 'second'});
      expect(pendingCompanyId.value, 'second');
    });

    test('listeners are told exactly once per tap', () {
      var fired = 0;
      void listener() => fired += 1;
      pendingCompanyId.addListener(listener);
      addTearDown(() => pendingCompanyId.removeListener(listener));

      rememberTappedCompany(<String, dynamic>{'companyId': 'company-1'});
      expect(fired, 1);
    });
  });
}
