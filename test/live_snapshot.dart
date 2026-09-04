import 'dart:convert';
import 'dart:io';

import 'package:orbit/models/branch_eligibility.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

class LiveSnapshot {
  const LiveSnapshot({
    required this.companies,
    required this.statuses,
    required this.branch,
    required this.regNo,
  });

  final List<Company> companies;
  final Map<String, StudentCompanyStatus> statuses;
  final BranchInfo? branch;
  final String regNo;

  StudentCompanyStatus? statusFor(Company company) => statuses[company.id];
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
    ctc: row['ctc'] as String?,
    eligibleBranches: (row['eligibleBranches'] as List<dynamic>)
        .map((value) => value.toString())
        .toList(),
    requirements: (row['requirements'] as List<dynamic>).map((value) {
      final entry = value as Map<String, dynamic>;
      return CompanyRequirement(
        id: entry['id'] as String? ?? '',
        type: RequirementType.fromWire(entry['type']),
        label: '',
        isRequired: entry['required'] as bool? ?? false,
      );
    }).toList(),
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
    roundHistory: (row['roundHistory'] as List<dynamic>).map((value) {
      final entry = value as Map<String, dynamic>;
      return RoundHistoryEntry(
        roundId: entry['roundId'] as String? ?? '',
        result: RoundResult.fromWire(entry['result']),
      );
    }).toList(),
  );
}

LiveSnapshot loadLiveSnapshot() {
  final file = File('test_fixtures/live_snapshot.json');
  if (!file.existsSync()) {
    throw StateError('the live snapshot is missing at ${file.path}');
  }
  final snapshot = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final regNo = snapshot['regNo'] as String;

  return LiveSnapshot(
    companies: (snapshot['companies'] as List<dynamic>)
        .map((row) => _company(row as Map<String, dynamic>))
        .toList(),
    statuses: <String, StudentCompanyStatus>{
      for (final row in snapshot['statuses'] as List<dynamic>)
        (row as Map<String, dynamic>)['companyId'] as String: _status(row),
    },
    branch: branchForRegNo(regNo),
    regNo: regNo,
  );
}
