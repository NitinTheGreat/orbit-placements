import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/company_format.dart';
import 'package:orbit/features/companies/presentation/drive_ordering.dart';
import 'package:orbit/models/branch_eligibility.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

final DateTime now = DateTime(2026, 9, 2, 9);

Company drive(
  String name, {
  CompanyStatus status = CompanyStatus.registrationOpen,
  DateTime? deadline,
  bool requiresAction = true,
  List<String> eligibleBranches = const [],
}) {
  return Company(
    id: name,
    name: name,
    category: 'Core',
    status: status,
    eligibleBranches: eligibleBranches,
    registrationDeadline: deadline,
    requirements: requiresAction
        ? const [
            CompanyRequirement(
              id: 'neopat',
              type: RequirementType.neopat,
              label: 'Register on NeoPAT',
              isRequired: true,
            ),
          ]
        : const [],
  );
}

StudentCompanyStatus done(String companyId) {
  return StudentCompanyStatus(
    studentId: 's',
    companyId: companyId,
    completedRequirementIds: const ['neopat'],
  );
}

List<String> namesOf(
  List<Company> companies, {
  Map<String, StudentCompanyStatus> statuses = const {},
  BranchInfo? branch,
}) {
  return orderDrives(
    companies: companies,
    statusesByCompanyId: statuses,
    branch: branch,
    now: now,
  ).map((company) => company.name).toList();
}

final cse = branchForRegNo('23BCT0098');

StudentCompanyStatus tracking(String companyId, bool optedIn) {
  return StudentCompanyStatus(
    studentId: 's',
    companyId: companyId,
    optedIn: optedIn,
  );
}

const mechOnly = ['B.Tech Mech,EEE,ECE related branches'];

void main() {
  group('bands', () {
    test('the four bands come out in the documented order', () {
      final companies = [
        drive(
          'concluded',
          status: CompanyStatus.closed,
          deadline: now.add(const Duration(days: 1)),
        ),
        drive(
          'ongoing',
          status: CompanyStatus.inProgress,
          deadline: now.add(const Duration(days: 2)),
          requiresAction: false,
        ),
        drive(
          'open no action',
          deadline: now.add(const Duration(days: 3)),
          requiresAction: false,
        ),
        drive('action', deadline: now.add(const Duration(days: 4))),
      ];

      expect(namesOf(companies), [
        'action',
        'open no action',
        'ongoing',
        'concluded',
      ]);
    });

    test('a concluded drive sinks even with the soonest deadline', () {
      final companies = [
        drive(
          'results',
          status: CompanyStatus.resultsDeclared,
          deadline: now.add(const Duration(hours: 1)),
        ),
        drive('later', deadline: now.add(const Duration(days: 20))),
      ];

      expect(namesOf(companies), ['later', 'results']);
    });

    test('an in-progress drive with an outstanding step still leads', () {
      final companies = [
        drive(
          'ongoing but incomplete',
          status: CompanyStatus.inProgress,
          deadline: now.add(const Duration(days: 2)),
        ),
        drive(
          'open no action',
          deadline: now.add(const Duration(hours: 1)),
          requiresAction: false,
        ),
      ];

      expect(namesOf(companies), ['ongoing but incomplete', 'open no action']);
    });

    test('completing the checklist moves a drive out of the top band', () {
      final companies = [
        drive('done', deadline: now.add(const Duration(hours: 2))),
        drive('todo', deadline: now.add(const Duration(days: 6))),
      ];

      expect(namesOf(companies), ['done', 'todo']);
      expect(
        namesOf(companies, statuses: {'done': done('done')}),
        ['todo', 'done'],
      );
    });
  });

  group('within a band', () {
    test('action needed is soonest deadline first', () {
      final companies = [
        drive('third', deadline: now.add(const Duration(days: 9))),
        drive('first', deadline: now.add(const Duration(hours: 3))),
        drive('second', deadline: now.add(const Duration(days: 2))),
      ];

      expect(namesOf(companies), ['first', 'second', 'third']);
    });

    test('a missing deadline sorts last inside its band', () {
      final companies = [
        drive('undated', deadline: null),
        drive('dated', deadline: now.add(const Duration(days: 4))),
      ];

      expect(namesOf(companies), ['dated', 'undated']);
    });

    test('concluded drives read most recent first', () {
      final companies = [
        drive(
          'older',
          status: CompanyStatus.closed,
          deadline: now.subtract(const Duration(days: 30)),
        ),
        drive(
          'newer',
          status: CompanyStatus.closed,
          deadline: now.subtract(const Duration(days: 2)),
        ),
      ];

      expect(namesOf(companies), ['newer', 'older']);
    });

    test('an equal deadline falls back to the name', () {
      final deadline = now.add(const Duration(days: 5));
      final companies = [
        drive('Zeta', deadline: deadline),
        drive('alpha', deadline: deadline),
      ];

      expect(namesOf(companies), ['alpha', 'Zeta']);
    });
  });

  test('ordering leaves the input list untouched', () {
    final companies = [
      drive('b', deadline: now.add(const Duration(days: 4))),
      drive('a', deadline: now.add(const Duration(days: 1))),
    ];
    orderDrives(companies: companies, statusesByCompanyId: const {}, now: now);
    expect(companies.map((c) => c.name).toList(), ['b', 'a']);
  });

  group('the branch mismatch band', () {
    test('sinks below concluded when the student is not tracking it', () {
      final companies = [
        drive(
          'off branch',
          deadline: now.add(const Duration(hours: 1)),
          eligibleBranches: mechOnly,
        ),
        drive(
          'concluded',
          status: CompanyStatus.closed,
          deadline: now.subtract(const Duration(days: 2)),
        ),
        drive('open', deadline: now.add(const Duration(days: 5))),
      ];

      expect(namesOf(companies, branch: cse), [
        'open',
        'concluded',
        'off branch',
      ]);
    });

    test('an explicit opt-in keeps the drive in its normal band', () {
      final companies = [
        drive(
          'off branch',
          deadline: now.add(const Duration(hours: 1)),
          eligibleBranches: mechOnly,
        ),
        drive('open', deadline: now.add(const Duration(days: 5))),
      ];

      expect(
        namesOf(
          companies,
          branch: cse,
          statuses: {'off branch': tracking('off branch', true)},
        ),
        ['off branch', 'open'],
      );
    });

    test('an explicit opt-out still sinks, since it is not tracked', () {
      final companies = [
        drive(
          'off branch',
          deadline: now.add(const Duration(hours: 1)),
          eligibleBranches: mechOnly,
        ),
        drive('open', deadline: now.add(const Duration(days: 5))),
      ];

      expect(
        namesOf(
          companies,
          branch: cse,
          statuses: {'off branch': tracking('off branch', false)},
        ),
        ['open', 'off branch'],
      );
    });

    test('an unknown branch never sinks anything', () {
      final companies = [
        drive(
          'off branch',
          deadline: now.add(const Duration(hours: 1)),
          eligibleBranches: mechOnly,
        ),
        drive('open', deadline: now.add(const Duration(days: 5))),
      ];

      expect(namesOf(companies, branch: null), ['off branch', 'open']);
      expect(
        namesOf(companies, branch: branchForRegNo('23BAI0210')),
        ['off branch', 'open'],
      );
    });

    test('an eligible drive is never sunk', () {
      final companies = [
        drive(
          'on branch',
          deadline: now.add(const Duration(hours: 1)),
          eligibleBranches: const ['B.Tech CSE/IT related branches'],
        ),
        drive('open', deadline: now.add(const Duration(days: 5))),
      ];

      expect(namesOf(companies, branch: cse), ['on branch', 'open']);
    });

    test('several mismatches order by deadline among themselves', () {
      final companies = [
        drive(
          'later',
          deadline: now.add(const Duration(days: 9)),
          eligibleBranches: mechOnly,
        ),
        drive(
          'sooner',
          deadline: now.add(const Duration(days: 2)),
          eligibleBranches: mechOnly,
        ),
      ];

      expect(namesOf(companies, branch: cse), ['sooner', 'later']);
    });
  });

  group('inside action needed', () {
    test('urgency ranks by severity, not by enum declaration order', () {
      expect(urgencyRank(DeadlineUrgency.today), 0);
      expect(
        urgencyRank(DeadlineUrgency.today),
        lessThan(urgencyRank(DeadlineUrgency.imminent)),
      );
      expect(
        urgencyRank(DeadlineUrgency.imminent),
        lessThan(urgencyRank(DeadlineUrgency.thisWeek)),
      );
      expect(
        urgencyRank(DeadlineUrgency.thisWeek),
        lessThan(urgencyRank(DeadlineUrgency.distant)),
      );
      expect(
        urgencyRank(DeadlineUrgency.distant),
        lessThan(urgencyRank(DeadlineUrgency.passed)),
      );
      expect(
        urgencyRank(DeadlineUrgency.passed),
        lessThan(urgencyRank(DeadlineUrgency.unknown)),
      );
    });

    test('a deadline today leads one later this week', () {
      final companies = [
        drive('this week', deadline: now.add(const Duration(days: 5))),
        drive('today', deadline: now.add(const Duration(hours: 6))),
      ];
      expect(namesOf(companies), ['today', 'this week']);
    });

    test('equal deadlines fall back to the most recently announced', () {
      final deadline = now.add(const Duration(days: 2));
      final companies = [
        Company(
          id: 'older',
          name: 'older',
          category: 'Core',
          registrationDeadline: deadline,
          sourceDate: now.subtract(const Duration(days: 9)),
          requirements: const [
            CompanyRequirement(
              id: 'neopat',
              type: RequirementType.neopat,
              label: 'Register',
              isRequired: true,
            ),
          ],
        ),
        Company(
          id: 'newer',
          name: 'newer',
          category: 'Core',
          registrationDeadline: deadline,
          sourceDate: now.subtract(const Duration(days: 1)),
          requirements: const [
            CompanyRequirement(
              id: 'neopat',
              type: RequirementType.neopat,
              label: 'Register',
              isRequired: true,
            ),
          ],
        ),
      ];
      expect(namesOf(companies), ['newer', 'older']);
    });

    test('a later update outranks an older first sighting', () {
      final deadline = now.add(const Duration(days: 2));
      Company make(String name, DateTime source, DateTime? updated) => Company(
        id: name,
        name: name,
        category: 'Core',
        registrationDeadline: deadline,
        sourceDate: source,
        lastUpdatedDate: updated,
        requirements: const [
          CompanyRequirement(
            id: 'neopat',
            type: RequirementType.neopat,
            label: 'Register',
            isRequired: true,
          ),
        ],
      );
      final companies = [
        make('refreshed', now.subtract(const Duration(days: 20)),
            now.subtract(const Duration(hours: 2))),
        make('stale', now.subtract(const Duration(days: 2)), null),
      ];
      expect(namesOf(companies), ['refreshed', 'stale']);
    });

    test('a drive with no dates at all still sorts last, deterministically', () {
      final companies = [
        drive('undated', deadline: null),
        drive('dated', deadline: now.add(const Duration(days: 3))),
      ];
      expect(namesOf(companies), ['dated', 'undated']);
    });
  });
}
