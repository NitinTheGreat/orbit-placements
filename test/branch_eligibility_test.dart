import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/branch_eligibility.dart';

void main() {
  group('branch code from regNo', () {
    test('reads the three letters after the two year digits', () {
      expect(branchCodeFromRegNo('23BCT0098'), 'BCT');
      expect(branchCodeFromRegNo('22BCE1234'), 'BCE');
      expect(branchCodeFromRegNo('21BME0001'), 'BME');
    });

    test('tolerates spacing and lower case', () {
      expect(branchCodeFromRegNo(' 23bct0098 '), 'BCT');
      expect(branchCodeFromRegNo('23 BCT 0098'), 'BCT');
    });

    test('returns null for anything that is not the VIT shape', () {
      expect(branchCodeFromRegNo(null), isNull);
      expect(branchCodeFromRegNo(''), isNull);
      expect(branchCodeFromRegNo('BCT0098'), isNull);
      expect(branchCodeFromRegNo('23BC0098'), isNull);
      expect(branchCodeFromRegNo('23BCT098'), isNull);
      expect(branchCodeFromRegNo('2023BCT0098'), isNull);
    });

    test('an unmapped but well-formed code resolves to no branch', () {
      expect(branchCodeFromRegNo('23XYZ0001'), 'XYZ');
      expect(branchForRegNo('23XYZ0001'), isNull);
    });
  });

  group('family detection', () {
    test('reads the real eligibility strings from production', () {
      expect(
        familiesMentionedIn('B.Tech Mech,EEE,ECE related branches'),
        {
          BranchFamily.mechanical,
          BranchFamily.electricalElectronics,
          BranchFamily.electronicsCommunication,
        },
      );
      expect(familiesMentionedIn('B.Tech CSE/IT related branches'), {
        BranchFamily.computerScience,
        BranchFamily.informationTechnology,
      });
      expect(
        familiesMentionedIn('All B.Tech, M.Tech & Integrated ( CSE, IT)'),
        {BranchFamily.computerScience, BranchFamily.informationTechnology},
      );
      expect(
        familiesMentionedIn('B. Tech ( ECE / EEE ) related branches only'),
        {
          BranchFamily.electronicsCommunication,
          BranchFamily.electricalElectronics,
        },
      );
    });

    test('does not match a code hiding inside an ordinary word', () {
      expect(familiesMentionedIn('necessary prerequisites'), isEmpty);
      expect(familiesMentionedIn('All branches are welcome'), isEmpty);
    });
  });

  group('branch relevance', () {
    const cse = BranchInfo(
      'BCT',
      'Computer Science and Engineering',
      BranchFamily.computerScience,
    );
    const mech = BranchInfo(
      'BME',
      'Mechanical Engineering',
      BranchFamily.mechanical,
    );

    test('an empty eligibility list is never a mismatch', () {
      expect(
        branchRelevance(branch: cse, eligibleBranches: const []),
        BranchRelevance.unknown,
      );
      expect(
        branchRelevance(branch: cse, eligibleBranches: const ['', '  ']),
        BranchRelevance.unknown,
      );
    });

    test('an unknown branch code is never a mismatch', () {
      expect(
        branchRelevance(
          branch: null,
          eligibleBranches: const ['B.Tech CSE/IT related branches'],
        ),
        BranchRelevance.unknown,
      );
    });

    test('text naming no branch at all is never a mismatch', () {
      expect(
        branchRelevance(
          branch: cse,
          eligibleBranches: const ['All B.Techs', 'No standing arrears'],
        ),
        BranchRelevance.unknown,
      );
    });

    test('Keyence is a confident mismatch for CSE and a match for Mech', () {
      const keyence = [
        'B.Tech Mech,EEE,ECE related branches',
        'M.Tech Mech,EEE,ECE related branches',
      ];
      expect(
        branchRelevance(branch: cse, eligibleBranches: keyence),
        BranchRelevance.notOpen,
      );
      expect(
        branchRelevance(branch: mech, eligibleBranches: keyence),
        BranchRelevance.eligible,
      );
    });

    test('any single entry admitting the student wins over the rest', () {
      const kinaxis = [
        'All B.Tech (CSE/IT) related branches',
        'All B.Tech ECE related branches (only applicable for Technical '
            'Support Associate Role)',
        'All B.Tech Mechanical related branches (only applicable for '
            'Associate Consultant - Solutions Role)',
      ];
      expect(
        branchRelevance(branch: cse, eligibleBranches: kinaxis),
        BranchRelevance.eligible,
      );
      expect(
        branchRelevance(branch: mech, eligibleBranches: kinaxis),
        BranchRelevance.eligible,
      );
    });

    test('an explicit exclusion flags the excluded family', () {
      const urban = ['All B.Techs (except CS/IT Related)'];
      expect(
        branchRelevance(branch: cse, eligibleBranches: urban),
        BranchRelevance.notOpen,
      );
      expect(
        branchRelevance(branch: mech, eligibleBranches: urban),
        BranchRelevance.eligible,
      );
    });

    test('an exclusion naming nothing recognisable stays unknown', () {
      expect(
        branchRelevance(
          branch: cse,
          eligibleBranches: const ['All B.Techs except backlog holders'],
        ),
        BranchRelevance.unknown,
      );
    });

    test('an exclusion without an "all" base stays unknown', () {
      expect(
        branchRelevance(
          branch: mech,
          eligibleBranches: const ['Select branches except CSE'],
        ),
        BranchRelevance.unknown,
      );
    });

    test('WinWire style lists of specialisations read as CSE', () {
      const winwire = [
        'B. Tech. CS/IT Related Branches',
        'CSE',
        'IT',
        'AIML',
        'DS',
      ];
      expect(
        branchRelevance(branch: cse, eligibleBranches: winwire),
        BranchRelevance.eligible,
      );
      expect(
        branchRelevance(branch: mech, eligibleBranches: winwire),
        BranchRelevance.notOpen,
      );
    });
  });
}
