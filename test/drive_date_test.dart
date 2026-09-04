import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/drive_date.dart';
import 'package:orbit/models/company.dart';

final now = DateTime(2026, 9, 5, 12);

CompanyRound round(String name, {DateTime? scheduled, int order = 1, RoundType type = RoundType.oa}) {
  return CompanyRound(
    id: name, name: name, order: order, type: type,
    announcedAt: now.subtract(const Duration(days: 2)),
    scheduledDate: scheduled,
  );
}

Company drive({
  CompanyStatus status = CompanyStatus.inProgress,
  DateTime? deadline,
  List<CompanyRound> rounds = const [],
}) {
  return Company(
    id: 'c', name: 'c', category: '',
    status: status, registrationDeadline: deadline, rounds: rounds,
  );
}

void main() {
  test('an upcoming round wins, labelled with its name', () {
    final d = driveDate(
      drive(rounds: [round('Online test', scheduled: now.add(const Duration(days: 3)))]),
      now: now,
    );
    expect(d.kind, DriveDateKind.upcomingRound);
    expect(d.label, 'Online test');
    expect(d.date, now.add(const Duration(days: 3)));
  });

  test('the soonest upcoming round wins when several are dated', () {
    final d = driveDate(
      drive(rounds: [
        round('Interview', scheduled: now.add(const Duration(days: 9)), order: 2),
        round('OA', scheduled: now.add(const Duration(days: 2)), order: 1),
      ]),
      now: now,
    );
    expect(d.label, 'OA');
  });

  test('an open registration is used when no round is upcoming', () {
    final d = driveDate(
      drive(
        status: CompanyStatus.registrationOpen,
        deadline: now.add(const Duration(days: 1)),
      ),
      now: now,
    );
    expect(d.kind, DriveDateKind.registration);
    expect(d.label, 'Registration closes');
  });

  test('an upcoming round outranks an open registration', () {
    final d = driveDate(
      drive(
        status: CompanyStatus.registrationOpen,
        deadline: now.add(const Duration(days: 1)),
        rounds: [round('PPT', scheduled: now.add(const Duration(days: 4)))],
      ),
      now: now,
    );
    expect(d.kind, DriveDateKind.upcomingRound);
  });

  test('the most recent past round is used when nothing is upcoming', () {
    final d = driveDate(
      drive(rounds: [
        round('OA', scheduled: now.subtract(const Duration(days: 9)), order: 1),
        round('Interview', scheduled: now.subtract(const Duration(days: 2)), order: 2),
      ]),
      now: now,
    );
    expect(d.kind, DriveDateKind.pastRound);
    expect(d.label, 'Interview was');
    expect(d.isPast, isTrue);
  });

  test('a closed registration is a sensible last resort', () {
    final d = driveDate(
      drive(
        status: CompanyStatus.inProgress,
        deadline: now.subtract(const Duration(days: 3)),
      ),
      now: now,
    );
    expect(d.kind, DriveDateKind.pastRound);
    expect(d.label, 'Registration closed');
  });

  test('nothing known reads as not announced, never as no deadline', () {
    final d = driveDate(drive(), now: now);
    expect(d.kind, DriveDateKind.unknown);
    expect(d.label, 'Date not announced');
    expect(d.isKnown, isFalse);
    expect(d.label.toLowerCase(), isNot(contains('no deadline')));
  });

  test('rounds with no scheduled date are ignored entirely', () {
    final d = driveDate(drive(rounds: [round('OA'), round('Interview', order: 2)]), now: now);
    expect(d.kind, DriveDateKind.unknown);
  });

  test('a passed registration on an open drive is not treated as open', () {
    final d = driveDate(
      drive(
        status: CompanyStatus.registrationOpen,
        deadline: now.subtract(const Duration(days: 1)),
      ),
      now: now,
    );
    expect(d.kind, DriveDateKind.pastRound);
  });

  test('a future deadline still reads as closing, whatever the drive status', () {
    for (final state in [
      CompanyStatus.registrationOpen,
      CompanyStatus.inProgress,
    ]) {
      final d = driveDate(
        drive(status: state, deadline: now.add(const Duration(days: 1))),
        now: now,
      );
      expect(d.kind, DriveDateKind.registration, reason: state.name);
      expect(d.label, 'Registration closes');
    }
  });

  test('a deadline tomorrow is never described as closed', () {
    final d = driveDate(
      drive(status: CompanyStatus.inProgress, deadline: now.add(const Duration(days: 1))),
      now: now,
    );
    expect(d.isPast, isFalse);
    expect(d.label, isNot(contains('closed')));
  });
}
