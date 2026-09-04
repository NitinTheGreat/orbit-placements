import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/drive_filter.dart';
import 'package:orbit/features/profile/presentation/profile_stats.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

final DateTime now = DateTime(2026, 9, 2, 9);

Company drive(
  String name, {
  CompanyStatus status = CompanyStatus.registrationOpen,
  DateTime? deadline,
  int requiredSteps = 1,
}) {
  return Company(
    id: name,
    name: name,
    category: 'Core',
    status: status,
    registrationDeadline: deadline ?? now.add(const Duration(days: 3)),
    requirements: [
      for (var i = 0; i < requiredSteps; i++)
        CompanyRequirement(
          id: 'step$i',
          type: RequirementType.other,
          label: 'Step $i',
          isRequired: true,
        ),
    ],
  );
}

StudentCompanyStatus status(
  String companyId, {
  bool? optedIn,
  OverallStatus overall = OverallStatus.active,
  List<String> completed = const [],
  List<RoundHistoryEntry> rounds = const [],
}) {
  return StudentCompanyStatus(
    studentId: 's',
    companyId: companyId,
    optedIn: optedIn,
    overallStatus: overall,
    completedRequirementIds: completed,
    roundHistory: rounds,
  );
}

void main() {
  group('counts', () {
    test('a missing status doc still counts as tracked', () {
      final stats = profileStats(
        companies: [drive('a'), drive('b')],
        statusesByCompanyId: const {},
        now: now,
      );
      expect(stats.drivesTracked, 2);
    });

    test('opting out drops the drive from the tracked count', () {
      final stats = profileStats(
        companies: [drive('a'), drive('b')],
        statusesByCompanyId: {'a': status('a', optedIn: false)},
        now: now,
      );
      expect(stats.drivesTracked, 1);
    });

    test('completion rate counts required steps across every drive', () {
      final stats = profileStats(
        companies: [drive('a', requiredSteps: 2), drive('b', requiredSteps: 2)],
        statusesByCompanyId: {
          'a': status('a', completed: const ['step0', 'step1']),
          'b': status('b', completed: const ['step0']),
        },
        now: now,
      );
      expect(stats.requirementsDone, 3);
      expect(stats.requirementsTotal, 4);
      expect(stats.completionRate, 0.75);
      expect(stats.completionLabel, '75%');
    });

    test('optional steps do not count toward the rate', () {
      final company = Company(
        id: 'a',
        name: 'a',
        category: 'Core',
        registrationDeadline: now.add(const Duration(days: 2)),
        requirements: const [
          CompanyRequirement(
            id: 'need',
            type: RequirementType.other,
            label: 'Need',
            isRequired: true,
          ),
          CompanyRequirement(
            id: 'maybe',
            type: RequirementType.other,
            label: 'Maybe',
          ),
        ],
      );
      final stats = profileStats(
        companies: [company],
        statusesByCompanyId: {
          'a': status('a', completed: const ['need']),
        },
        now: now,
      );
      expect(stats.requirementsTotal, 1);
      expect(stats.requirementsDone, 1);
    });

    test('no required steps anywhere reads as nothing to do', () {
      final stats = profileStats(
        companies: [drive('a', requiredSteps: 0)],
        statusesByCompanyId: const {},
        now: now,
      );
      expect(stats.completionRate, isNull);
      expect(stats.completionLabel, 'Nothing to do yet');
    });
  });

  group('breakdown', () {
    test('a personal outcome outranks the drive state', () {
      final stats = profileStats(
        companies: [drive('a'), drive('b')],
        statusesByCompanyId: {
          'a': status('a', overall: OverallStatus.selected),
          'b': status('b', overall: OverallStatus.rejected),
        },
        now: now,
      );
      expect(stats.breakdown[DriveOutcomeSlice.selected], 1);
      expect(stats.breakdown[DriveOutcomeSlice.rejected], 1);
      expect(stats.breakdown[DriveOutcomeSlice.actionNeeded], isNull);
    });

    test('an outstanding step reads as action needed', () {
      final stats = profileStats(
        companies: [drive('a')],
        statusesByCompanyId: const {},
        now: now,
      );
      expect(stats.breakdown[DriveOutcomeSlice.actionNeeded], 1);
    });

    test('a cleared round with nothing outstanding reads as in progress', () {
      final stats = profileStats(
        companies: [drive('a')],
        statusesByCompanyId: {
          'a': status(
            'a',
            completed: const ['step0'],
            rounds: const [
              RoundHistoryEntry(roundId: 'r1', result: RoundResult.cleared),
            ],
          ),
        },
        now: now,
      );
      expect(stats.breakdown[DriveOutcomeSlice.inProgress], 1);
    });

    test('a concluded drive with no personal outcome reads as closed', () {
      final stats = profileStats(
        companies: [drive('a', status: CompanyStatus.closed)],
        statusesByCompanyId: const {},
        now: now,
      );
      expect(stats.breakdown[DriveOutcomeSlice.closed], 1);
    });

    test('a quiet open drive with nothing to do lands in no slice', () {
      final stats = profileStats(
        companies: [drive('a', requiredSteps: 0)],
        statusesByCompanyId: const {},
        now: now,
      );
      expect(stats.breakdownTotal, 0);
    });
  });

  group('locked tabs', () {
    test('Open now reads the drive status only', () {
      expect(
        matchesLock(
          lock: DriveLock.openNow,
          company: drive('a'),
          status: null,
          now: now,
        ),
        isTrue,
      );
      expect(
        matchesLock(
          lock: DriveLock.openNow,
          company: drive('a', status: CompanyStatus.inProgress),
          status: null,
          now: now,
        ),
        isFalse,
      );
      expect(
        matchesLock(
          lock: DriveLock.openNow,
          company: drive('a', status: CompanyStatus.closed),
          status: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('Open now drops a drive whose deadline has passed', () {
      expect(
        matchesLock(
          lock: DriveLock.openNow,
          company: drive('a', deadline: now.subtract(const Duration(days: 1))),
          status: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('Shortlisted takes a cleared round or an offer', () {
      expect(
        matchesLock(
          lock: DriveLock.shortlisted,
          company: drive('a'),
          status: status(
            'a',
            rounds: const [
              RoundHistoryEntry(roundId: 'r1', result: RoundResult.cleared),
            ],
          ),
          now: now,
        ),
        isTrue,
      );
      expect(
        matchesLock(
          lock: DriveLock.shortlisted,
          company: drive('a'),
          status: status('a', overall: OverallStatus.selected),
          now: now,
        ),
        isTrue,
      );
    });

    test('Shortlisted skips a drive with no cleared round', () {
      expect(
        matchesLock(
          lock: DriveLock.shortlisted,
          company: drive('a'),
          status: null,
          now: now,
        ),
        isFalse,
      );
      expect(
        matchesLock(
          lock: DriveLock.shortlisted,
          company: drive('a'),
          status: status(
            'a',
            rounds: const [
              RoundHistoryEntry(roundId: 'r1', result: RoundResult.rejected),
            ],
          ),
          now: now,
        ),
        isFalse,
      );
    });

    test('a selected student stays shortlisted after opting out', () {
      expect(
        matchesLock(
          lock: DriveLock.shortlisted,
          company: drive('a'),
          status: status(
            'a',
            optedIn: false,
            overall: OverallStatus.selected,
          ),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
