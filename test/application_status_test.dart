import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/company_format.dart';
import 'package:orbit/features/companies/presentation/drive_filter.dart';
import 'package:orbit/models/application_status.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

final now = DateTime(2026, 9, 2, 12);
final future = now.add(const Duration(days: 5));
final past = now.subtract(const Duration(days: 1));

CompanyRequirement requirement(
  String id, {
  bool required = true,
  RequirementType type = RequirementType.googleForm,
}) {
  return CompanyRequirement(
    id: id,
    type: type,
    label: id,
    isRequired: required,
  );
}

Company company({
  List<CompanyRequirement> requirements = const [],
  CompanyStatus status = CompanyStatus.registrationOpen,
  DateTime? deadline,
}) {
  return Company(
    id: 'c1',
    name: 'Rubrik',
    category: 'Super Dream',
    requirements: requirements,
    status: status,
    registrationDeadline: deadline,
  );
}

StudentCompanyStatus status({
  bool? optedIn,
  List<String> completed = const [],
}) {
  return StudentCompanyStatus(
    studentId: 'u1',
    companyId: 'c1',
    optedIn: optedIn,
    completedRequirementIds: completed,
  );
}

void main() {
  group('applicationComplete', () {
    test('an empty required set counts as complete', () {
      expect(applicationComplete(const [], const []), isTrue);
      expect(
        applicationComplete([requirement('a', required: false)], const []),
        isTrue,
      );
    });

    test('every required id must be present', () {
      final reqs = [requirement('a'), requirement('b')];
      expect(applicationComplete(reqs, ['a']), isFalse);
      expect(applicationComplete(reqs, ['a', 'b']), isTrue);
    });

    test('optional items never block completion', () {
      final reqs = [requirement('a'), requirement('b', required: false)];
      expect(applicationComplete(reqs, ['a']), isTrue);
    });
  });

  group('applicationSummary', () {
    test('reads Applied when nothing is outstanding', () {
      expect(
        applicationSummary(requirements: const [], completedIds: const []),
        'Applied',
      );
      expect(
        applicationSummary(
          requirements: [requirement('a')],
          completedIds: ['a'],
        ),
        'Applied',
      );
    });

    test('counts partial progress', () {
      expect(
        applicationSummary(
          requirements: [requirement('a'), requirement('b')],
          completedIds: ['a'],
        ),
        '1 of 2 steps done',
      );
    });

    test('reads Not started with nothing checked', () {
      expect(
        applicationSummary(
          requirements: [requirement('a'), requirement('b')],
          completedIds: const [],
        ),
        'Not started',
      );
    });
  });

  group('actionNeeded', () {
    test('true for an open incomplete drive before the deadline', () {
      final application = DriveApplication(
        company: company(requirements: [requirement('a')], deadline: future),
        status: status(),
        now: now,
      );
      expect(application.needsAction, isTrue);
    });

    test('false when the student opted out', () {
      final application = DriveApplication(
        company: company(requirements: [requirement('a')], deadline: future),
        status: status(optedIn: false),
        now: now,
      );
      expect(application.needsAction, isFalse);
    });

    test('false once every required step is done', () {
      final application = DriveApplication(
        company: company(requirements: [requirement('a')], deadline: future),
        status: status(completed: ['a']),
        now: now,
      );
      expect(application.needsAction, isFalse);
    });

    test('false after the deadline and when closed', () {
      expect(
        DriveApplication(
          company: company(requirements: [requirement('a')], deadline: past),
          status: status(),
          now: now,
        ).needsAction,
        isFalse,
      );
      expect(
        DriveApplication(
          company: company(
            requirements: [requirement('a')],
            deadline: future,
            status: CompanyStatus.closed,
          ),
          status: status(),
          now: now,
        ).needsAction,
        isFalse,
      );
    });

    test('a required item added after completion reopens the application', () {
      final completed = ['a'];
      final before = DriveApplication(
        company: company(requirements: [requirement('a')], deadline: future),
        status: status(completed: completed),
        now: now,
      );
      expect(before.isComplete, isTrue);
      expect(before.needsAction, isFalse);

      final after = DriveApplication(
        company: company(
          requirements: [requirement('a'), requirement('b')],
          deadline: future,
        ),
        status: status(completed: completed),
        now: now,
      );
      expect(after.isComplete, isFalse);
      expect(after.needsAction, isTrue);
    });
  });

  group('priority bump', () {
    test('raises one step only when action is needed', () {
      expect(
        raisedUrgency(DeadlineUrgency.distant, false),
        DeadlineUrgency.distant,
      );
      expect(
        raisedUrgency(DeadlineUrgency.distant, true),
        DeadlineUrgency.thisWeek,
      );
      expect(
        raisedUrgency(DeadlineUrgency.thisWeek, true),
        DeadlineUrgency.imminent,
      );
    });

    test('never bumps past the top or lifts a passed deadline', () {
      expect(
        raisedUrgency(DeadlineUrgency.imminent, true),
        DeadlineUrgency.imminent,
      );
      expect(raisedUrgency(DeadlineUrgency.today, true), DeadlineUrgency.today);
      expect(
        raisedUrgency(DeadlineUrgency.passed, true),
        DeadlineUrgency.passed,
      );
    });

    test(
      'an outstanding step lifts a five day deadline into the coral band',
      () {
        final application = DriveApplication(
          company: company(requirements: [requirement('a')], deadline: future),
          status: status(),
          now: now,
        );
        expect(deadlineUrgency(future, now: now), DeadlineUrgency.thisWeek);
        expect(application.urgency, DeadlineUrgency.imminent);
      },
    );

    test('a completed drive keeps the deadline its own urgency', () {
      final application = DriveApplication(
        company: company(requirements: [requirement('a')], deadline: future),
        status: status(completed: ['a']),
        now: now,
      );
      expect(application.urgency, DeadlineUrgency.thisWeek);
    });
  });

  group('checklist editability', () {
    test('stays editable while open', () {
      expect(
        checklistEditable(CompanyStatus.registrationOpen, future, now: now),
        isTrue,
      );
    });

    test('locks once closed or past the deadline', () {
      expect(
        checklistEditable(CompanyStatus.closed, future, now: now),
        isFalse,
      );
      expect(
        checklistEditable(CompanyStatus.inProgress, past, now: now),
        isFalse,
      );
    });

    test('an opted-out student can still edit the checklist', () {
      final application = DriveApplication(
        company: company(requirements: [requirement('a')], deadline: future),
        status: status(optedIn: false),
        now: now,
      );
      expect(application.isEditable, isTrue);
      expect(application.needsAction, isFalse);
    });
  });

  group('filters', () {
    final open = company(requirements: [requirement('a')], deadline: future);
    final closed = company(
      requirements: [requirement('a')],
      deadline: past,
      status: CompanyStatus.closed,
    );

    test('All keeps everything', () {
      expect(
        matchesFilter(
          filter: DriveFilter.all,
          company: closed,
          status: status(optedIn: false),
          now: now,
        ),
        isTrue,
      );
    });

    test('Tracking drops only explicit opt-outs', () {
      expect(
        matchesFilter(
          filter: DriveFilter.tracking,
          company: open,
          status: status(optedIn: false),
          now: now,
        ),
        isFalse,
      );
      expect(
        matchesFilter(
          filter: DriveFilter.tracking,
          company: open,
          status: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('Action needed matches the derived flag', () {
      expect(
        matchesFilter(
          filter: DriveFilter.actionNeeded,
          company: open,
          status: status(),
          now: now,
        ),
        isTrue,
      );
      expect(
        matchesFilter(
          filter: DriveFilter.actionNeeded,
          company: open,
          status: status(completed: ['a']),
          now: now,
        ),
        isFalse,
      );
    });

    test('Closed covers both an explicit status and a passed deadline', () {
      expect(
        matchesFilter(
          filter: DriveFilter.closed,
          company: closed,
          status: null,
          now: now,
        ),
        isTrue,
      );
      expect(
        matchesFilter(
          filter: DriveFilter.closed,
          company: open,
          status: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('applyFilter narrows the list by company id', () {
      final result = applyFilter(
        filter: DriveFilter.actionNeeded,
        companies: [open],
        statusesByCompanyId: {
          'c1': status(completed: ['a']),
        },
        now: now,
      );
      expect(result, isEmpty);
    });
  });
}
