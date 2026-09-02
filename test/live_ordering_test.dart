import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/drive_ordering.dart';
import 'package:orbit/models/application_status.dart';
import 'package:orbit/models/branch_eligibility.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

Map<String, dynamic> _snapshot() {
  final file = File('test_fixtures/live_snapshot.json');
  if (!file.existsSync()) {
    throw StateError('the live snapshot is missing at ${file.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

DateTime? _date(Object? value) {
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
}

Company _company(Map<String, dynamic> row) {
  return Company(
    id: row['id'] as String,
    name: row['name'] as String? ?? '',
    category: '',
    status: CompanyStatus.fromWire(row['status']),
    registrationDeadline: _date(row['registrationDeadline']),
    eligibleBranches: (row['eligibleBranches'] as List<dynamic>)
        .map((value) => value.toString())
        .toList(),
    requirements: (row['requirements'] as List<dynamic>)
        .map(
          (value) => CompanyRequirement(
            id: (value as Map<String, dynamic>)['id'] as String? ?? '',
            type: RequirementType.other,
            label: '',
            isRequired: value['required'] as bool? ?? false,
          ),
        )
        .toList(),
  );
}

StudentCompanyStatus _status(Map<String, dynamic> row) {
  return StudentCompanyStatus(
    studentId: 's',
    companyId: row['companyId'] as String,
    optedIn: row['optedIn'] as bool?,
    overallStatus: OverallStatus.fromWire(row['overallStatus']),
    completedRequirementIds: (row['completedRequirementIds'] as List<dynamic>)
        .map((value) => value.toString())
        .toList(),
    roundHistory: (row['roundHistory'] as List<dynamic>)
        .map(
          (value) => RoundHistoryEntry(
            roundId: (value as Map<String, dynamic>)['roundId'] as String? ?? '',
            result: RoundResult.fromWire(value['result']),
          ),
        )
        .toList(),
  );
}

void main() {
  final snapshot = _snapshot();
  final companies = (snapshot['companies'] as List<dynamic>)
      .map((row) => _company(row as Map<String, dynamic>))
      .toList();
  final statuses = <String, StudentCompanyStatus>{
    for (final row in snapshot['statuses'] as List<dynamic>)
      (row as Map<String, dynamic>)['companyId'] as String: _status(row),
  };
  final branch = branchForRegNo(snapshot['regNo'] as String);
  final now = DateTime(2026, 9, 2, 12);

  List<Company> ordered() => orderDrives(
    companies: companies,
    statusesByCompanyId: statuses,
    branch: branch,
    now: now,
  );

  DriveBand bandOf(Company company) => driveBand(
    DriveApplication(
      company: company,
      status: statuses[company.id],
      now: now,
    ),
    branch: branch,
  );

  test('the live snapshot is the real thing, not a fixture', () {
    expect(companies.length, greaterThanOrEqualTo(25));
    expect(branch, isNotNull);
    expect(branch!.family, BranchFamily.computerScience);
  });

  test('bands come out in the documented order across all live drives', () {
    final bands = ordered().map(bandOf).toList();
    final indices = bands.map((band) => band.index).toList();

    for (var i = 1; i < indices.length; i++) {
      expect(
        indices[i],
        greaterThanOrEqualTo(indices[i - 1]),
        reason:
            'band went backwards at position $i: '
            '${bands[i - 1]} then ${bands[i]}',
      );
    }
  });

  test('deadlines rise inside every non-concluded band', () {
    final sorted = ordered();
    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final current = sorted[i];
      if (bandOf(previous) != bandOf(current)) {
        continue;
      }
      if (bandOf(current) == DriveBand.concluded) {
        continue;
      }
      final a = previous.registrationDeadline;
      final b = current.registrationDeadline;
      if (a == null || b == null) {
        continue;
      }
      expect(
        a.isAfter(b),
        isFalse,
        reason:
            'inside ${bandOf(current)}, ${previous.name} ($a) came before '
            '${current.name} ($b)',
      );
    }
  });

  test('every live drive lands in exactly one band', () {
    expect(ordered().length, companies.length);
    expect(ordered().map((c) => c.id).toSet().length, companies.length);
  });

  test('the ordering is stable when run twice', () {
    expect(
      ordered().map((c) => c.id).toList(),
      ordered().map((c) => c.id).toList(),
    );
  });

  test('an off-branch drive the student joined is not sunk', () {
    for (final company in companies) {
      if (statuses[company.id]?.optedIn != true) {
        continue;
      }
      expect(
        bandOf(company),
        isNot(DriveBand.branchMismatch),
        reason: '${company.name} was joined deliberately',
      );
    }
  });

  test('no concluded drive outranks a live one', () {
    final sorted = ordered();
    final lastLive = sorted.lastIndexWhere(
      (company) => bandOf(company).index < DriveBand.concluded.index,
    );
    final firstConcluded = sorted.indexWhere(
      (company) => bandOf(company) == DriveBand.concluded,
    );
    if (lastLive >= 0 && firstConcluded >= 0) {
      expect(firstConcluded, greaterThan(lastLive));
    }
  });
}
