import '../../../models/application_status.dart';
import '../../../models/company.dart';
import '../../../models/student_company_status.dart';

enum DriveFilter {
  all('All'),
  tracking('Tracking'),
  actionNeeded('Action needed'),
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
  switch (filter) {
    case DriveFilter.all:
      return true;
    case DriveFilter.tracking:
      return status?.optedIn != false;
    case DriveFilter.actionNeeded:
      return DriveApplication(
        company: company,
        status: status,
        now: now,
      ).needsAction;
    case DriveFilter.closed:
      final deadline = company.registrationDeadline?.toLocal();
      final reference = now ?? DateTime.now();
      return company.status == CompanyStatus.closed ||
          (deadline != null && !deadline.isAfter(reference));
  }
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
