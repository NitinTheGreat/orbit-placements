import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/branch_eligibility.dart';

const Map<String, BranchFamily> _familyByWireName = <String, BranchFamily>{
  'computer_science': BranchFamily.computerScience,
  'information_technology': BranchFamily.informationTechnology,
  'electrical': BranchFamily.electrical,
  'mechanical': BranchFamily.mechanical,
  'postgraduate': BranchFamily.postgraduate,
};

const Map<String, BranchRelevance> _relevanceByWireName =
    <String, BranchRelevance>{
      'eligible': BranchRelevance.eligible,
      'not_open': BranchRelevance.notOpen,
      'unknown': BranchRelevance.unknown,
    };

Map<String, dynamic> _loadCases() {
  final file = File('test_fixtures/branch_cases.json');
  if (!file.existsSync()) {
    throw StateError('the shared parity table is missing at ${file.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final cases = _loadCases();

  group('shared parity table, codes', () {
    for (final entry in cases['codes'] as List<dynamic>) {
      final row = entry as Map<String, dynamic>;
      final code = row['code'] as String?;
      final expected = row['family'] as String?;
      test('${code ?? 'null'} maps to ${expected ?? 'no family'}', () {
        expect(
          branchFamilyForCode(code),
          expected == null ? isNull : _familyByWireName[expected],
        );
      });
    }
  });

  group('shared parity table, registration numbers', () {
    for (final entry in cases['regNos'] as List<dynamic>) {
      final row = entry as Map<String, dynamic>;
      final regNo = row['regNo'] as String?;
      final expectedCode = row['code'] as String?;
      final expectedFamily = row['family'] as String?;

      test('${regNo ?? 'null'} reads as ${expectedCode ?? 'nothing'}', () {
        expect(branchCodeFromRegNo(regNo), expectedCode);
        final branch = branchForRegNo(regNo);
        if (expectedFamily == null) {
          expect(branch, isNull);
        } else {
          expect(branch, isNotNull);
          expect(branch!.family, _familyByWireName[expectedFamily]);
          expect(branch.code, expectedCode);
        }
      });
    }
  });

  group('shared parity table, relevance', () {
    for (final entry in cases['relevance'] as List<dynamic>) {
      final row = entry as Map<String, dynamic>;
      final why = row['why'] as String;
      final branches = (row['eligibleBranches'] as List<dynamic>)
          .map((value) => value as String)
          .toList();
      final expectations = row['expect'] as Map<String, dynamic>;

      expectations.forEach((regNo, expected) {
        test('$why: $regNo is $expected', () {
          expect(
            branchRelevanceForRegNo(
              regNo: regNo,
              eligibleBranches: branches,
            ),
            _relevanceByWireName[expected as String],
          );
        });
      });
    }
  });

  group('shared parity table, degree level', () {
    for (final entry in cases['levels'] as List<dynamic>) {
      final row = entry as Map<String, dynamic>;
      final code = row['code'] as String?;
      final expected = row['level'] as String?;
      test('${code ?? 'null'} is ${expected ?? 'no level'}', () {
        expect(
          degreeLevelForCode(code),
          expected == null
              ? isNull
              : (expected == 'undergraduate'
                    ? DegreeLevel.undergraduate
                    : DegreeLevel.postgraduate),
        );
      });
    }
  });

  group('degree level detection in eligibility text', () {
    test('an M.Tech drive reads as postgraduate only', () {
      expect(levelsMentionedIn('M.Tech CSE & IT related branches'), {
        DegreeLevel.postgraduate,
      });
      expect(levelsMentionedIn('M. Tech ( CSE / IT ) related branches only'), {
        DegreeLevel.postgraduate,
      });
    });

    test('a B.Tech drive reads as undergraduate only', () {
      expect(levelsMentionedIn('B.Tech CSE/IT related branches'), {
        DegreeLevel.undergraduate,
      });
      expect(levelsMentionedIn('B.E'), {DegreeLevel.undergraduate});
    });

    test('a drive naming both reads as both', () {
      expect(levelsMentionedIn('B.Tech/M.Tech CSE'), {
        DegreeLevel.undergraduate,
        DegreeLevel.postgraduate,
      });
    });

    test('a drive naming no level reads as nothing', () {
      expect(levelsMentionedIn('Computer Science & Engineering'), isEmpty);
      expect(levelsMentionedIn('CSE'), isEmpty);
    });

    test('a level mismatch beats a branch match', () {
      expect(
        branchRelevanceForRegNo(
          regNo: '23BCT0098',
          eligibleBranches: const ['M.Tech CSE & IT related branches'],
        ),
        BranchRelevance.notOpen,
      );
    });
  });

  group('the prefix rules you confirmed', () {
    test('any BC code is CS family, whatever the third letter', () {
      for (final code in ['BCA', 'BCB', 'BCT', 'BCZ']) {
        expect(branchFamilyForCode(code), BranchFamily.computerScience);
      }
    });

    test('BIT is IT and is not swallowed by the B prefix rules', () {
      expect(branchFamilyForCode('BIT'), BranchFamily.informationTechnology);
    });

    test('any BE code is electrical', () {
      for (final code in ['BEA', 'BEC', 'BEE', 'BEZ']) {
        expect(branchFamilyForCode(code), BranchFamily.electrical);
      }
    });

    test('any BM code is mechanical', () {
      for (final code in ['BMA', 'BME', 'BMY']) {
        expect(branchFamilyForCode(code), BranchFamily.mechanical);
      }
    });

    test('anything starting with M is postgraduate', () {
      for (final code in ['MCA', 'MIC', 'MTX', 'MZZ']) {
        expect(branchFamilyForCode(code), BranchFamily.postgraduate);
      }
    });

    test('everything else is unknown and never flagged', () {
      for (final code in ['BAI', 'BBT', 'BPS', 'XYZ', 'ABC']) {
        expect(branchFamilyForCode(code), isNull);
        expect(
          branchRelevance(
            branch: null,
            eligibleBranches: const ['B.Tech CSE/IT related branches'],
          ),
          BranchRelevance.unknown,
        );
      }
    });

    test('case and padding do not change the answer', () {
      expect(branchFamilyForCode('bct'), BranchFamily.computerScience);
      expect(branchFamilyForCode('  bit  '), BranchFamily.informationTechnology);
    });
  });
}
