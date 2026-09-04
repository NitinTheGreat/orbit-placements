import '../../../models/company.dart';

enum DriveDateKind { upcomingRound, registration, pastRound, unknown }

class DriveDate {
  const DriveDate({required this.kind, this.date, required this.label});

  final DriveDateKind kind;
  final DateTime? date;
  final String label;

  bool get isKnown => date != null;
  bool get isPast => kind == DriveDateKind.pastRound;
}

DriveDate driveDate(Company company, {DateTime? now}) {
  final reference = now ?? DateTime.now();

  final dated = company.orderedRounds
      .where((round) => round.scheduledDate != null)
      .toList();

  final upcoming =
      dated.where((round) => round.scheduledDate!.isAfter(reference)).toList()
        ..sort((a, b) => a.scheduledDate!.compareTo(b.scheduledDate!));

  if (upcoming.isNotEmpty) {
    final round = upcoming.first;
    return DriveDate(
      kind: DriveDateKind.upcomingRound,
      date: round.scheduledDate,
      label: round.name.trim().isEmpty ? round.type.label : round.name.trim(),
    );
  }

  final deadline = company.registrationDeadline;
  if (deadline != null && deadline.toLocal().isAfter(reference)) {
    return DriveDate(
      kind: DriveDateKind.registration,
      date: deadline,
      label: 'Registration closes',
    );
  }

  final past = dated..sort((a, b) => b.scheduledDate!.compareTo(a.scheduledDate!));
  if (past.isNotEmpty) {
    final round = past.first;
    final name = round.name.trim().isEmpty ? round.type.label : round.name.trim();
    return DriveDate(
      kind: DriveDateKind.pastRound,
      date: round.scheduledDate,
      label: '$name was',
    );
  }

  if (company.registrationDeadline != null) {
    return DriveDate(
      kind: DriveDateKind.pastRound,
      date: company.registrationDeadline,
      label: 'Registration closed',
    );
  }

  return const DriveDate(kind: DriveDateKind.unknown, label: 'Date not announced');
}
