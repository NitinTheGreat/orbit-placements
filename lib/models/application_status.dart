import '../features/companies/presentation/company_format.dart';
import 'company.dart';
import 'student_company_status.dart';

const Set<CompanyStatus> actionableStatuses = {
  CompanyStatus.registrationOpen,
  CompanyStatus.inProgress,
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
  if (!actionableStatuses.contains(status)) {
    return false;
  }
  if (registrationDeadline == null) {
    return false;
  }
  return registrationDeadline.toLocal().isAfter(now ?? DateTime.now());
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

  bool get isComplete =>
      applicationComplete(company.requirements, completedIds);

  bool get needsAction => actionNeeded(
    optedIn: status?.optedIn,
    complete: isComplete,
    status: company.status,
    registrationDeadline: company.registrationDeadline,
    now: now,
  );

  bool get isEditable =>
      checklistEditable(company.status, company.registrationDeadline, now: now);

  String get summary => applicationSummary(
    requirements: company.requirements,
    completedIds: completedIds,
  );

  DeadlineUrgency get urgency => raisedUrgency(
    deadlineUrgency(company.registrationDeadline, now: now),
    needsAction,
  );
}
