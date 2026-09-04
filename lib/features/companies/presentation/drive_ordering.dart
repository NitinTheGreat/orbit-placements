import '../../../models/application_status.dart';
import '../../../models/branch_eligibility.dart';
import '../../../models/company.dart';
import '../../../models/student_company_status.dart';
import 'company_format.dart';

enum DriveBand { actionNeeded, openNoAction, ongoing, concluded, branchMismatch }

bool sinksForBranch({
  required BranchInfo? branch,
  required Company company,
  required StudentCompanyStatus? status,
}) {
  if (status?.optedIn == true) {
    return false;
  }
  return branchRelevance(
        branch: branch,
        eligibleBranches: company.eligibleBranches,
      ) ==
      BranchRelevance.notOpen;
}

DriveBand driveBand(
  DriveApplication application, {
  BranchInfo? branch,
}) {
  final company = application.company;
  if (sinksForBranch(
    branch: branch,
    company: company,
    status: application.status,
  )) {
    return DriveBand.branchMismatch;
  }
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

const List<DeadlineUrgency> urgencyOrder = <DeadlineUrgency>[
  DeadlineUrgency.today,
  DeadlineUrgency.imminent,
  DeadlineUrgency.thisWeek,
  DeadlineUrgency.distant,
  DeadlineUrgency.passed,
  DeadlineUrgency.unknown,
];

int urgencyRank(DeadlineUrgency urgency) => urgencyOrder.indexOf(urgency);

int _byUrgency(Company a, Company b, DateTime? now) {
  final left = urgencyRank(deadlineUrgency(a.registrationDeadline, now: now));
  final right = urgencyRank(deadlineUrgency(b.registrationDeadline, now: now));
  return left.compareTo(right);
}

int _byAnnouncedDescending(Company a, Company b) {
  final left = a.lastUpdatedDate ?? a.sourceDate ?? a.createdAt;
  final right = b.lastUpdatedDate ?? b.sourceDate ?? b.createdAt;
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
  BranchInfo? branch,
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
      branch: branch,
    );
  }

  final sorted = [...companies];
  sorted.sort((a, b) {
    final bandA = bands[a.id] ?? DriveBand.ongoing;
    final bandB = bands[b.id] ?? DriveBand.ongoing;
    if (bandA != bandB) {
      return bandA.index.compareTo(bandB.index);
    }
    if (bandA == DriveBand.actionNeeded) {
      final byUrgency = _byUrgency(a, b, now);
      if (byUrgency != 0) {
        return byUrgency;
      }
    }

    final byDeadline = bandA == DriveBand.concluded
        ? _byDeadlineDescending(a, b)
        : _byDeadlineAscending(a, b);
    if (byDeadline != 0) {
      return byDeadline;
    }

    final byAnnounced = _byAnnouncedDescending(a, b);
    if (byAnnounced != 0) {
      return byAnnounced;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}
