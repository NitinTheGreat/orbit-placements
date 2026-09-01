import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

Company companyWithRounds(List<CompanyRound> rounds) {
  return Company(
    id: 'c1',
    name: 'Rubrik',
    category: 'Super Dream',
    rounds: rounds,
  );
}

void main() {
  group('CompanyStatus', () {
    test('maps every wire name back to its enum value', () {
      for (final status in CompanyStatus.values) {
        expect(CompanyStatus.fromWire(status.wireName), status);
      }
    });

    test('falls back to registration open for unknown values', () {
      expect(
        CompanyStatus.fromWire('nonsense'),
        CompanyStatus.registrationOpen,
      );
      expect(CompanyStatus.fromWire(null), CompanyStatus.registrationOpen);
    });
  });

  group('RoundResult and OverallStatus', () {
    test('map every wire name back', () {
      for (final result in RoundResult.values) {
        expect(RoundResult.fromWire(result.wireName), result);
      }
      for (final status in OverallStatus.values) {
        expect(OverallStatus.fromWire(status.wireName), status);
      }
    });

    test('fall back safely', () {
      expect(RoundResult.fromWire('nonsense'), RoundResult.pending);
      expect(OverallStatus.fromWire(null), OverallStatus.active);
    });
  });

  group('slugify', () {
    test('builds stable ids from labels', () {
      expect(slugify('Technical Round 1'), 'technical-round-1');
      expect(slugify('  Fill the form!  '), 'fill-the-form');
    });
  });

  group('CompanyRequirement', () {
    test('round-trips through a map keeping the id', () {
      const requirement = CompanyRequirement(
        id: 'fill-the-form',
        type: 'form',
        label: 'Fill the form',
        url: 'https://example.com/form',
        isRequired: true,
      );

      final map = requirement.toMap();
      expect(map['required'], isTrue);
      expect(map['id'], 'fill-the-form');

      final restored = CompanyRequirement.fromMap(map);
      expect(restored.id, requirement.id);
      expect(restored.label, requirement.label);
    });

    test('derives an id from the label when one is missing', () {
      final restored = CompanyRequirement.fromMap(<String, dynamic>{
        'label': 'Upload your resume',
      });
      expect(restored.id, 'upload-your-resume');
    });
  });

  group('CompanyRound ordering', () {
    test('orders by explicit order, not array position', () {
      final company = companyWithRounds(const [
        CompanyRound(id: 'interview', name: 'Interview', order: 3),
        CompanyRound(id: 'ppt', name: 'PPT', order: 1),
        CompanyRound(id: 'oa', name: 'OA', order: 2),
      ]);

      expect(company.orderedRounds.map((r) => r.id).toList(), [
        'ppt',
        'oa',
        'interview',
      ]);
      expect(company.finalRound?.id, 'interview');
    });
  });

  group('StudentCompanyStatus derivations', () {
    final company = companyWithRounds(const [
      CompanyRound(id: 'ppt', name: 'PPT', order: 1),
      CompanyRound(id: 'oa', name: 'OA', order: 2),
      CompanyRound(id: 'interview', name: 'Interview', order: 3),
    ]);

    test('builds the composite document id', () {
      expect(
        StudentCompanyStatus.docIdFor(studentId: 'uid1', companyId: 'c1'),
        'uid1_c1',
      );
    });

    test('current round is the highest order non-rejected entry', () {
      const history = [
        RoundHistoryEntry(roundId: 'ppt', result: RoundResult.cleared),
        RoundHistoryEntry(roundId: 'oa', result: RoundResult.invited),
      ];
      expect(
        StudentCompanyStatus.resolveCurrentRoundId(history, company),
        'oa',
      );
    });

    test('a rejected round never becomes the current round', () {
      const history = [
        RoundHistoryEntry(roundId: 'ppt', result: RoundResult.cleared),
        RoundHistoryEntry(roundId: 'oa', result: RoundResult.rejected),
      ];
      expect(
        StudentCompanyStatus.resolveCurrentRoundId(history, company),
        'ppt',
      );
    });

    test('any rejection makes the overall status rejected', () {
      const history = [
        RoundHistoryEntry(roundId: 'ppt', result: RoundResult.cleared),
        RoundHistoryEntry(roundId: 'oa', result: RoundResult.rejected),
      ];
      expect(
        StudentCompanyStatus.resolveOverallStatus(history, company),
        OverallStatus.rejected,
      );
    });

    test('clearing the final round means selected', () {
      const history = [
        RoundHistoryEntry(roundId: 'ppt', result: RoundResult.cleared),
        RoundHistoryEntry(roundId: 'interview', result: RoundResult.cleared),
      ];
      expect(
        StudentCompanyStatus.resolveOverallStatus(history, company),
        OverallStatus.selected,
      );
    });

    test('clearing a middle round is still active', () {
      const history = [
        RoundHistoryEntry(roundId: 'oa', result: RoundResult.cleared),
      ];
      expect(
        StudentCompanyStatus.resolveOverallStatus(history, company),
        OverallStatus.active,
      );
    });

    test('entryFor finds this student result for a round', () {
      const status = StudentCompanyStatus(
        studentId: 'u',
        companyId: 'c',
        roundHistory: [
          RoundHistoryEntry(roundId: 'ppt', result: RoundResult.cleared),
          RoundHistoryEntry(roundId: 'oa', result: RoundResult.rejected),
        ],
      );

      expect(status.entryFor('ppt')?.result, RoundResult.cleared);
      expect(status.entryFor('oa')?.result, RoundResult.rejected);
      expect(status.entryFor('interview'), isNull);
    });

    test('roundById resolves a round the timeline renders', () {
      final company = companyWithRounds(const [
        CompanyRound(id: 'ppt', name: 'PPT', order: 1, type: RoundType.ppt),
      ]);

      expect(company.roundById('ppt')?.name, 'PPT');
      expect(company.roundById('missing'), isNull);
      expect(company.roundById(null), isNull);
    });

    test('optedIn is three-state', () {
      const unset = StudentCompanyStatus(studentId: 'u', companyId: 'c');
      expect(unset.optedIn, isNull);
      expect(unset.isOptedOut, isFalse);

      const out = StudentCompanyStatus(
        studentId: 'u',
        companyId: 'c',
        optedIn: false,
      );
      expect(out.isOptedOut, isTrue);
    });
  });
}
