import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/drive_filter.dart';
import 'package:orbit/models/application_status.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

import 'live_snapshot.dart';

final DateTime now = DateTime(2026, 9, 2, 12);

Company drive(
  String name, {
  CompanyStatus status = CompanyStatus.registrationOpen,
  DateTime? deadline,
  bool noDeadline = false,
}) {
  return Company(
    id: name,
    name: name,
    category: '',
    status: status,
    registrationDeadline: noDeadline
        ? null
        : (deadline ?? now.add(const Duration(days: 3))),
  );
}

StudentCompanyStatus status(
  String companyId, {
  bool? optedIn,
  OverallStatus overall = OverallStatus.active,
  List<RoundHistoryEntry> rounds = const [],
}) {
  return StudentCompanyStatus(
    studentId: 's',
    companyId: companyId,
    optedIn: optedIn,
    overallStatus: overall,
    roundHistory: rounds,
  );
}

bool lock(DriveLock which, Company company, StudentCompanyStatus? s) =>
    matchesLock(lock: which, company: company, status: s, now: now);

void main() {
  group('Open now', () {
    test('keeps an open drive with a future deadline', () {
      expect(lock(DriveLock.openNow, drive('a'), null), isTrue);
    });

    test('keeps an open drive with no deadline at all', () {
      expect(lock(DriveLock.openNow, drive('a', noDeadline: true), null), isTrue);
    });

    test('drops an open drive whose deadline has passed', () {
      final stale = drive('WinWire', deadline: now.subtract(const Duration(days: 1)));
      expect(lock(DriveLock.openNow, stale, null), isFalse);
    });

    test('drops a drive that is no longer registration_open', () {
      for (final state in [
        CompanyStatus.inProgress,
        CompanyStatus.closed,
        CompanyStatus.resultsDeclared,
      ]) {
        expect(lock(DriveLock.openNow, drive('a', status: state), null), isFalse);
      }
    });
  });

  group('Shortlisted', () {
    const cleared = [
      RoundHistoryEntry(roundId: 'oa', result: RoundResult.cleared),
    ];
    const invited = [
      RoundHistoryEntry(roundId: 'oa', result: RoundResult.invited),
    ];

    test('includes a drive the student was invited to', () {
      expect(
        lock(DriveLock.shortlisted, drive('a'), status('a', rounds: invited)),
        isTrue,
      );
    });

    test('includes a concluded drive the student was shortlisted in', () {
      final concluded = drive('a', status: CompanyStatus.resultsDeclared);
      expect(
        lock(DriveLock.shortlisted, concluded, status('a', rounds: cleared)),
        isTrue,
      );
    });

    test('includes a drive the student was rejected from after clearing', () {
      expect(
        lock(
          DriveLock.shortlisted,
          drive('a', status: CompanyStatus.resultsDeclared),
          status('a', overall: OverallStatus.rejected, rounds: cleared),
        ),
        isTrue,
      );
    });

    test('includes an offer even with no round history', () {
      expect(
        lock(
          DriveLock.shortlisted,
          drive('a'),
          status('a', overall: OverallStatus.selected),
        ),
        isTrue,
      );
    });

    test('excludes a drive the student was never shortlisted in', () {
      expect(lock(DriveLock.shortlisted, drive('a'), null), isFalse);
      expect(
        lock(
          DriveLock.shortlisted,
          drive('a'),
          status('a', rounds: const [
            RoundHistoryEntry(roundId: 'oa', result: RoundResult.notListed),
          ]),
        ),
        isFalse,
      );
    });

    test('excludes a drive the student opted out of', () {
      expect(
        lock(
          DriveLock.shortlisted,
          drive('a'),
          status('a', optedIn: false, rounds: cleared),
        ),
        isFalse,
      );
    });
  });

  group('Selected', () {
    test('requires an actual offer, not merely a cleared round', () {
      final withCleared = status(
        'a',
        rounds: const [
          RoundHistoryEntry(roundId: 'oa', result: RoundResult.cleared),
        ],
      );
      expect(
        matchesFilter(
          filter: DriveFilter.selected,
          company: drive('a'),
          status: withCleared,
          now: now,
        ),
        isFalse,
      );
      expect(
        matchesFilter(
          filter: DriveFilter.selected,
          company: drive('a'),
          status: status('a', overall: OverallStatus.selected),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('against the live snapshot', () {
    final snapshot = loadLiveSnapshot();

    List<Company> locked(DriveLock which) => applyLock(
      lock: which,
      companies: snapshot.companies,
      statusesByCompanyId: snapshot.statuses,
      now: now,
    );

    test('Open now drops the drive whose deadline has passed', () {
      final names = locked(DriveLock.openNow).map((c) => c.name).toList();
      final stale = snapshot.companies.where(
        (company) =>
            company.status == CompanyStatus.registrationOpen &&
            company.registrationDeadline != null &&
            company.registrationDeadline!.isBefore(now),
      );
      expect(stale, isNotEmpty, reason: 'production has a stale open drive');
      for (final company in stale) {
        expect(names, isNot(contains(company.name)));
      }
    });

    test('Shortlisted still finds the drive the student is live in', () {
      expect(locked(DriveLock.shortlisted).map((c) => c.name), contains('Accenture'));
    });
  });
}
