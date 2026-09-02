import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/display_name.dart';

void main() {
  group('the Aurora alias', () {
    test('matches on the registration number', () {
      expect(
        greetingName(name: 'Guneet Kaur 23BCT0210', regNo: '23BCT0210'),
        'Ms Aurora',
      );
      expect(greetingName(name: 'Someone Else', regNo: '23BCT0210'), 'Ms Aurora');
      expect(greetingName(name: 'Someone Else 23BCT0210'), 'Ms Aurora');
    });

    test('matches on the first name, whatever the case', () {
      expect(greetingName(name: 'guneet', regNo: '22BCE9999'), 'Ms Aurora');
      expect(greetingName(name: 'GUNEET Kaur'), 'Ms Aurora');
    });

    test('leaves every other student alone', () {
      expect(
        greetingName(name: 'Nitin Kumar Pandey 23BCT0098', regNo: '23BCT0098'),
        'Nitin',
      );
      expect(greetingName(name: 'Guneeta Sharma'), 'Guneeta');
      expect(greetingName(name: 'Preet Guneetish'), 'Preet');
    });

    test('applies to the profile heading too', () {
      expect(displayName(name: 'Guneet Kaur', regNo: '23BCT0210'), 'Ms Aurora');
      expect(
        displayName(name: 'Nitin Kumar Pandey 23BCT0098'),
        'Nitin Kumar Pandey 23BCT0098',
      );
    });
  });

  group('first name', () {
    test('skips a leading registration number', () {
      expect(firstNameOf('23BCT0098 Nitin Kumar Pandey'), 'Nitin');
    });

    test('handles an absent or blank name', () {
      expect(greetingName(name: null), isNull);
      expect(greetingName(name: '   '), isNull);
      expect(displayName(name: null), 'Your profile');
    });
  });
}
