import '../../../models/application_status.dart';
import '../../../models/company.dart';
import '../../../models/student_company_status.dart';

enum DriveBand { actionNeeded, openNoAction, ongoing, concluded }

DriveBand driveBand(DriveApplication application) {
  final company = application.company;
  if (concludedStatuses.contains(company.status)) {
    return DriveBand.concluded;
  }
  if (application.needsAction) {
    return DriveBand.actionNeeded;
  }
  if (company.status == CompanyStatus.registrationOpen) {
    return DriveBand.openNoAction;
  }
  return DriveBand.ongoing;
}

int _byDeadlineAscending(Company a, Company b) {
  final left = a.registrationDeadline;
  final right = b.registrationDeadline;
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}

int _byDeadlineDescending(Company a, Company b) {
  final left = a.registrationDeadline;
  final right = b.registrationDeadline;
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return right.compareTo(left);
}

List<Company> orderDrives({
  required List<Company> companies,
  required Map<String, StudentCompanyStatus> statusesByCompanyId,
  DateTime? now,
}) {
  final bands = <String, DriveBand>{};
  for (final company in companies) {
    bands[company.id] = driveBand(
      DriveApplication(
        company: company,
        status: statusesByCompanyId[company.id],
        now: now,
      ),
    );
  }

  final sorted = [...companies];
  sorted.sort((a, b) {
    final bandA = bands[a.id] ?? DriveBand.ongoing;
    final bandB = bands[b.id] ?? DriveBand.ongoing;
    if (bandA != bandB) {
      return bandA.index.compareTo(bandB.index);
    }
    final byDeadline = bandA == DriveBand.concluded
        ? _byDeadlineDescending(a, b)
        : _byDeadlineAscending(a, b);
    if (byDeadline != 0) {
      return byDeadline;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}
