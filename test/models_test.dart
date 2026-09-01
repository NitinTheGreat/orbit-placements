import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

void main() {
  group('CompanyStatus', () {
    test('maps every wire name back to its enum value', () {
      for (final status in CompanyStatus.values) {
        expect(CompanyStatus.fromWire(status.wireName), status);
      }
    });

    test('falls back to open for unknown values', () {
      expect(CompanyStatus.fromWire('nonsense'), CompanyStatus.open);
      expect(CompanyStatus.fromWire(null), CompanyStatus.open);
    });
  });

  group('StudentStage', () {
    test('maps every wire name back to its enum value', () {
      for (final stage in StudentStage.values) {
        expect(StudentStage.fromWire(stage.wireName), stage);
      }
    });

    test('falls back to unknown for unrecognised values', () {
      expect(StudentStage.fromWire('nonsense'), StudentStage.unknown);
      expect(StudentStage.fromWire(null), StudentStage.unknown);
    });
  });

  group('CompanyRequirement', () {
    test('round-trips through a map using the required wire key', () {
      const requirement = CompanyRequirement(
        type: 'form',
        label: 'Fill the registration form',
        url: 'https://example.com/form',
        isRequired: true,
      );

      final map = requirement.toMap();
      expect(map['required'], isTrue);

      final restored = CompanyRequirement.fromMap(map);
      expect(restored.type, requirement.type);
      expect(restored.label, requirement.label);
      expect(restored.url, requirement.url);
      expect(restored.isRequired, requirement.isRequired);
    });

    test('defaults missing fields safely', () {
      final restored = CompanyRequirement.fromMap(<String, dynamic>{});
      expect(restored.type, 'other');
      expect(restored.label, isEmpty);
      expect(restored.url, isNull);
      expect(restored.isRequired, isFalse);
    });
  });

  group('StudentCompanyStatus', () {
    test('builds the composite document id', () {
      expect(
        StudentCompanyStatus.docIdFor(studentId: 'uid1', companyId: 'c1'),
        'uid1_c1',
      );
      const status = StudentCompanyStatus(studentId: 'u', companyId: 'c');
      expect(status.id, 'u_c');
    });
  });
}
