import '../../../models/application_status.dart';
import '../../../models/company.dart';
import '../../../models/student_company_status.dart';

enum DriveOutcomeSlice { actionNeeded, inProgress, selected, rejected, closed }

extension DriveOutcomeSliceLabel on DriveOutcomeSlice {
  String get label => switch (this) {
    DriveOutcomeSlice.actionNeeded => 'Action needed',
    DriveOutcomeSlice.inProgress => 'In progress',
    DriveOutcomeSlice.selected => 'Selected',
    DriveOutcomeSlice.rejected => 'Not selected',
    DriveOutcomeSlice.closed => 'Closed',
  };
}

DriveOutcomeSlice? sliceFor(DriveApplication application) {
  if (application.overallStatus == OverallStatus.selected) {
    return DriveOutcomeSlice.selected;
  }
  if (application.overallStatus == OverallStatus.rejected) {
    return DriveOutcomeSlice.rejected;
  }
  if (application.needsAction) {
    return DriveOutcomeSlice.actionNeeded;
  }
  if (application.isInProgress) {
    return DriveOutcomeSlice.inProgress;
  }
  if (concludedStatuses.contains(application.company.status)) {
    return DriveOutcomeSlice.closed;
  }
  return null;
}

class ProfileStats {
  const ProfileStats({
    required this.drivesTracked,
    required this.requirementsDone,
    required this.requirementsTotal,
    required this.breakdown,
  });

  final int drivesTracked;
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
  DateTime? now,
}) {
  var tracked = 0;
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

    if (status?.optedIn != false) {
      tracked += 1;
    }

    final progress = requiredProgress(
      company.requirements,
      application.completedIds,
    );
    done += progress.done;
    total += progress.total;

    final slice = sliceFor(application);
    if (slice != null) {
      breakdown[slice] = (breakdown[slice] ?? 0) + 1;
    }
  }

  return ProfileStats(
    drivesTracked: tracked,
    requirementsDone: done,
    requirementsTotal: total,
    breakdown: breakdown,
  );
}
