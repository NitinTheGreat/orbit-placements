import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/drive_filter.dart';
import 'package:orbit/features/companies/presentation/drive_ordering.dart';
import 'package:orbit/models/application_status.dart';
import 'package:orbit/models/company.dart';

import 'live_snapshot.dart';

void main() {
  final snapshot = loadLiveSnapshot();
  final now = DateTime(2026, 9, 2, 12);

  List<Company> tab(DriveFilter filter) => applyFilter(
    filter: filter,
    companies: snapshot.companies,
    statusesByCompanyId: snapshot.statuses,
    branch: snapshot.branch,
    now: now,
  );

  List<Company> band(DriveBand target) => snapshot.companies
      .where(
        (company) =>
            driveBand(
              DriveApplication(
                company: company,
                status: snapshot.statusFor(company),
                now: now,
              ),
              branch: snapshot.branch,
            ) ==
            target,
      )
      .toList();

  Set<String> ids(List<Company> companies) =>
      companies.map((company) => company.id).toSet();

  test('the snapshot is the real production data', () {
    expect(snapshot.companies.length, greaterThanOrEqualTo(25));
    expect(snapshot.regNo, '23BCT0098');
  });

  test('Action needed contains exactly the actionNeeded band', () {
    expect(ids(tab(DriveFilter.actionNeeded)), ids(band(DriveBand.actionNeeded)));
  });

  test('Closed contains exactly the concluded band', () {
    expect(ids(tab(DriveFilter.closed)), ids(band(DriveBand.concluded)));
  });

  test('a results-declared drive reaches the Closed tab', () {
    final declared = snapshot.companies.where(
      (company) => company.status == CompanyStatus.resultsDeclared,
    );
    expect(declared, isNotEmpty, reason: 'production has results_declared');
    for (final company in declared) {
      expect(
        ids(tab(DriveFilter.closed)),
        contains(company.id),
        reason: '${company.name} has wrapped up and belongs under Closed',
      );
    }
  });

  test('an off-branch drive never leaks into Action needed', () {
    final offBranch = ids(band(DriveBand.branchMismatch));
    expect(offBranch, isNotEmpty);
    expect(
      ids(tab(DriveFilter.actionNeeded)).intersection(offBranch),
      isEmpty,
    );
  });

  test('All still shows every drive', () {
    expect(tab(DriveFilter.all).length, snapshot.companies.length);
  });

  test('every drive in a tab is also in the ordered list for that tab', () {
    for (final filter in DriveFilter.values) {
      final selected = tab(filter);
      final ordered = orderDrives(
        companies: selected,
        statusesByCompanyId: snapshot.statuses,
        branch: snapshot.branch,
        now: now,
      );
      expect(ids(ordered), ids(selected), reason: filter.label);
    }
  });
}
