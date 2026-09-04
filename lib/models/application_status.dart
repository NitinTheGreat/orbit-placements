import '../features/companies/presentation/company_format.dart';
import 'company.dart';
import 'student_company_status.dart';

const Set<CompanyStatus> concludedStatuses = {
  CompanyStatus.closed,
  CompanyStatus.resultsDeclared,
};

bool applicationComplete(
  List<CompanyRequirement> requirements,
  List<String> completedIds,
) {
  final completed = completedIds.toSet();
  for (final requirement in requirements) {
    if (requirement.isRequired && !completed.contains(requirement.id)) {
      return false;
    }
  }
  return true;
}

({int done, int total}) requiredProgress(
  List<CompanyRequirement> requirements,
  List<String> completedIds,
) {
  final completed = completedIds.toSet();
  final required = requirements.where((r) => r.isRequired).toList();
  final done = required.where((r) => completed.contains(r.id)).length;
  return (done: done, total: required.length);
}

bool actionNeeded({
  required bool? optedIn,
  required bool complete,
  required CompanyStatus status,
  required DateTime? registrationDeadline,
  DateTime? now,
}) {
  if (optedIn == false) {
    return false;
  }
  if (complete) {
    return false;
  }
  if (concludedStatuses.contains(status)) {
    return false;
  }
  if (registrationDeadline == null) {
    return false;
  }
  return registrationDeadline.toLocal().isAfter(now ?? DateTime.now());
}

const Set<RoundResult> activeRoundResults = {
  RoundResult.cleared,
  RoundResult.invited,
};

bool inProgress({
  required bool? optedIn,
  required OverallStatus overallStatus,
  required List<RoundHistoryEntry> roundHistory,
}) {
  if (optedIn == false) {
    return false;
  }
  if (overallStatus != OverallStatus.active) {
    return false;
  }
  return roundHistory.any((entry) => activeRoundResults.contains(entry.result));
}

bool wasShortlisted({
  required bool? optedIn,
  required OverallStatus overallStatus,
  required List<RoundHistoryEntry> roundHistory,
}) {
  if (overallStatus == OverallStatus.selected) {
    return true;
  }
  if (optedIn == false) {
    return false;
  }
  return roundHistory.any((entry) => activeRoundResults.contains(entry.result));
}

bool registrationStillOpen(Company company, {DateTime? now}) {
  if (company.status != CompanyStatus.registrationOpen) {
    return false;
  }
  final deadline = company.registrationDeadline;
  if (deadline == null) {
    return true;
  }
  return deadline.toLocal().isAfter(now ?? DateTime.now());
}

bool checklistEditable(
  CompanyStatus status,
  DateTime? deadline, {
  DateTime? now,
}) {
  if (status == CompanyStatus.closed) {
    return false;
  }
  if (deadline == null) {
    return true;
  }
  return deadline.toLocal().isAfter(now ?? DateTime.now());
}

String companyStage(Company company, {DateTime? now}) {
  if (company.status == CompanyStatus.closed) {
    return 'Drive closed';
  }
  if (company.status == CompanyStatus.resultsDeclared) {
    return 'Results declared';
  }

  final rounds = company.orderedRounds;
  if (rounds.isNotEmpty) {
    final latest = rounds.last;
    final name = latest.name.trim();
    if (name.isEmpty) {
      return latest.type.label;
    }
    final lowered = name.toLowerCase();
    if (lowered.contains('scheduled') ||
        lowered.contains('announced') ||
        lowered.contains('declared')) {
      return name;
    }
    return switch (latest.type) {
      RoundType.ppt || RoundType.oa => '$name scheduled',
      RoundType.interview => '$name announced',
      RoundType.other => name,
    };
  }

  final deadline = company.registrationDeadline?.toLocal();
  final reference = now ?? DateTime.now();
  if (deadline != null && reference.isAfter(deadline)) {
    return 'Registration closed';
  }
  return 'Registration open';
}

String applicationSummary({
  required List<CompanyRequirement> requirements,
  required List<String> completedIds,
}) {
  final progress = requiredProgress(requirements, completedIds);
  if (progress.total == 0 || progress.done == progress.total) {
    return 'Applied';
  }
  if (progress.done == 0) {
    return 'Not started';
  }
  return '${progress.done} of ${progress.total} steps done';
}

enum DriveOutcomeTag { selected, rejected, notShortlisted, driveClosed, none }

bool wasLeftOffARoster(List<RoundHistoryEntry> roundHistory) {
  return roundHistory.any((entry) => entry.result == RoundResult.notListed);
}

DriveOutcomeTag outcomeTag({
  required OverallStatus overallStatus,
  required CompanyStatus companyStatus,
  List<RoundHistoryEntry> roundHistory = const [],
}) {
  if (overallStatus == OverallStatus.selected) {
    return DriveOutcomeTag.selected;
  }
  if (overallStatus == OverallStatus.rejected) {
    return wasLeftOffARoster(roundHistory)
        ? DriveOutcomeTag.notShortlisted
        : DriveOutcomeTag.rejected;
  }
  if (companyStatus == CompanyStatus.closed) {
    return DriveOutcomeTag.driveClosed;
  }
  return DriveOutcomeTag.none;
}

class DriveApplication {
  const DriveApplication({
    required this.company,
    required this.status,
    this.now,
  });

  final Company company;
  final StudentCompanyStatus? status;
  final DateTime? now;

  List<String> get completedIds => status?.completedRequirementIds ?? const [];

  bool? get optedIn => status?.optedIn;

  OverallStatus get overallStatus =>
      status?.overallStatus ?? OverallStatus.active;

  bool get isComplete =>
      applicationComplete(company.requirements, completedIds);

  bool get needsAction => actionNeeded(
    optedIn: optedIn,
    complete: isComplete,
    status: company.status,
    registrationDeadline: company.registrationDeadline,
    now: now,
  );

  bool get isInProgress => inProgress(
    optedIn: optedIn,
    overallStatus: overallStatus,
    roundHistory: status?.roundHistory ?? const [],
  );

  bool get isShortlisted => wasShortlisted(
    optedIn: optedIn,
    overallStatus: overallStatus,
    roundHistory: status?.roundHistory ?? const [],
  );

  bool get isConcluded => concludedStatuses.contains(company.status);

  bool get isOpenNow => registrationStillOpen(company, now: now);

  bool get isEditable =>
      checklistEditable(company.status, company.registrationDeadline, now: now);

  String get stage => companyStage(company, now: now);

  DriveOutcomeTag get tag => outcomeTag(
    overallStatus: overallStatus,
    companyStatus: company.status,
    roundHistory: status?.roundHistory ?? const [],
  );

  String get summary => applicationSummary(
    requirements: company.requirements,
    completedIds: completedIds,
  );

  DeadlineUrgency get urgency {
    if (tag != DriveOutcomeTag.none) {
      return DeadlineUrgency.passed;
    }
    return raisedUrgency(
      deadlineUrgency(company.registrationDeadline, now: now),
      needsAction,
    );
  }
}

DeadlineUrgency raisedUrgency(DeadlineUrgency urgency, bool actionNeeded) {
  if (!actionNeeded) {
    return urgency;
  }
  return switch (urgency) {
    DeadlineUrgency.distant => DeadlineUrgency.thisWeek,
    DeadlineUrgency.thisWeek => DeadlineUrgency.imminent,
    _ => urgency,
  };
}
