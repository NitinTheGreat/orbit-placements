import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/drive_ordering.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

final DateTime now = DateTime(2026, 9, 2, 9);

Company drive(
  String name, {
  CompanyStatus status = CompanyStatus.registrationOpen,
  DateTime? deadline,
  bool requiresAction = true,
}) {
  return Company(
    id: name,
    name: name,
    category: 'Core',
    status: status,
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
}) {
  return orderDrives(
    companies: companies,
    statusesByCompanyId: statuses,
    now: now,
  ).map((company) => company.name).toList();
}

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
}
