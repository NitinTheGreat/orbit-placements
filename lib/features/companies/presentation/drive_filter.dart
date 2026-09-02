import '../../../models/application_status.dart';
import '../../../models/company.dart';
import '../../../models/student_company_status.dart';

enum DriveFilter {
  all('All'),
  actionNeeded('Action needed'),
  inProgress('In progress'),
  selected('Selected'),
  rejected('Rejected'),
  closed('Closed');

  const DriveFilter(this.label);

  final String label;
}

bool matchesFilter({
  required DriveFilter filter,
  required Company company,
  required StudentCompanyStatus? status,
  DateTime? now,
}) {
  final application = DriveApplication(
    company: company,
    status: status,
    now: now,
  );

  return switch (filter) {
    DriveFilter.all => true,
    DriveFilter.actionNeeded => application.needsAction,
    DriveFilter.inProgress => application.isInProgress,
    DriveFilter.selected => application.overallStatus == OverallStatus.selected,
    DriveFilter.rejected => application.overallStatus == OverallStatus.rejected,
    DriveFilter.closed => company.status == CompanyStatus.closed,
  };
}

List<Company> applyFilter({
  required DriveFilter filter,
  required List<Company> companies,
  required Map<String, StudentCompanyStatus> statusesByCompanyId,
  DateTime? now,
}) {
  if (filter == DriveFilter.all) {
    return companies;
  }
  return companies
      .where(
        (company) => matchesFilter(
          filter: filter,
          company: company,
          status: statusesByCompanyId[company.id],
          now: now,
        ),
      )
      .toList(growable: false);
}

String emptyStateHeadline(DriveFilter filter) {
  return switch (filter) {
    DriveFilter.actionNeeded => "You're caught up.",
    DriveFilter.selected => 'Nothing yet — keep at it.',
    DriveFilter.inProgress => 'No drives in progress.',
    DriveFilter.rejected => 'Nothing here.',
    DriveFilter.closed => 'No closed drives yet.',
    DriveFilter.all => 'No drives yet',
  };
}

enum DriveLock { openNow, shortlisted }

bool matchesLock({
  required DriveLock lock,
  required Company company,
  required StudentCompanyStatus? status,
  DateTime? now,
}) {
  final application = DriveApplication(
    company: company,
    status: status,
    now: now,
  );

  return switch (lock) {
    DriveLock.openNow => company.status == CompanyStatus.registrationOpen,
    DriveLock.shortlisted =>
      application.isInProgress ||
          application.overallStatus == OverallStatus.selected,
  };
}

List<Company> applyLock({
  required DriveLock lock,
  required List<Company> companies,
  required Map<String, StudentCompanyStatus> statusesByCompanyId,
  DateTime? now,
}) {
  return companies
      .where(
        (company) => matchesLock(
          lock: lock,
          company: company,
          status: statusesByCompanyId[company.id],
          now: now,
        ),
      )
      .toList(growable: false);
}

String lockEmptyHeadline(DriveLock lock) {
  return switch (lock) {
    DriveLock.openNow => 'Nothing open right now.',
    DriveLock.shortlisted => 'Nothing yet — keep at it.',
  };
}
