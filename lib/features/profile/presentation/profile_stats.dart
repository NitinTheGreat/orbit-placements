import '../../../models/application_status.dart';
import '../../../models/branch_eligibility.dart';
import '../../../models/company.dart';
import '../../../models/student_company_status.dart';
import '../../companies/presentation/drive_ordering.dart';

enum DriveOutcomeSlice {
  actionNeeded,
  inProgress,
  selected,
  rejected,
  closed,
  tracking,
}

extension DriveOutcomeSliceLabel on DriveOutcomeSlice {
  String get label => switch (this) {
    DriveOutcomeSlice.actionNeeded => 'Action needed',
    DriveOutcomeSlice.inProgress => 'In progress',
    DriveOutcomeSlice.selected => 'Selected',
    DriveOutcomeSlice.rejected => 'Not selected',
    DriveOutcomeSlice.closed => 'Closed',
    DriveOutcomeSlice.tracking => 'Tracking',
  };
}

DriveOutcomeSlice? sliceFor(DriveApplication application, {BranchInfo? branch}) {
  final band = driveBand(application, branch: branch);
  if (band == DriveBand.branchMismatch) {
    return null;
  }
  if (application.overallStatus == OverallStatus.selected) {
    return DriveOutcomeSlice.selected;
  }
  if (application.overallStatus == OverallStatus.rejected) {
    return DriveOutcomeSlice.rejected;
  }
  if (band == DriveBand.concluded) {
    return DriveOutcomeSlice.closed;
  }
  if (band == DriveBand.actionNeeded) {
    return DriveOutcomeSlice.actionNeeded;
  }
  if (application.isInProgress) {
    return DriveOutcomeSlice.inProgress;
  }
  if (application.optedIn == false) {
    return null;
  }
  return DriveOutcomeSlice.tracking;
}

class ProfileStats {
  const ProfileStats({
    required this.drivesTracked,
    required this.branchRelevant,
    required this.requirementsDone,
    required this.requirementsTotal,
    required this.breakdown,
  });

  final int drivesTracked;
  final int branchRelevant;
  final int requirementsDone;
  final int requirementsTotal;
  final Map<DriveOutcomeSlice, int> breakdown;

  double? get completionRate {
    if (requirementsTotal == 0) {
      return null;
    }
    return requirementsDone / requirementsTotal;
  }

  String get completionLabel {
    final rate = completionRate;
    if (rate == null) {
      return 'Nothing to do yet';
    }
    return '${(rate * 100).round()}%';
  }

  int get breakdownTotal =>
      breakdown.values.fold(0, (total, value) => total + value);
}

ProfileStats profileStats({
  required List<Company> companies,
  required Map<String, StudentCompanyStatus> statusesByCompanyId,
  BranchInfo? branch,
  DateTime? now,
}) {
  var tracked = 0;
  var relevant = 0;
  var done = 0;
  var total = 0;
  final breakdown = <DriveOutcomeSlice, int>{};

  for (final company in companies) {
    final status = statusesByCompanyId[company.id];
    final application = DriveApplication(
      company: company,
      status: status,
      now: now,
    );

    if (branchRelevance(
          branch: branch,
          eligibleBranches: company.eligibleBranches,
        ) !=
        BranchRelevance.notOpen) {
      relevant += 1;
    }

    final slice = sliceFor(application, branch: branch);
    if (slice == null) {
      continue;
    }

    tracked += 1;
    breakdown[slice] = (breakdown[slice] ?? 0) + 1;

    final progress = requiredProgress(
      company.requirements,
      application.completedIds,
    );
    done += progress.done;
    total += progress.total;
  }

  return ProfileStats(
    drivesTracked: tracked,
    branchRelevant: relevant,
    requirementsDone: done,
    requirementsTotal: total,
    breakdown: breakdown,
  );
}
