import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/widget_feed.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

final DateTime now = DateTime(2026, 9, 2, 9);

Company drive(
  String name, {
  CompanyStatus status = CompanyStatus.registrationOpen,
  DateTime? deadline,
  List<CompanyRound> rounds = const [],
}) {
  return Company(
    id: name,
    name: name,
    category: 'Core',
    status: status,
    registrationDeadline: deadline ?? now.add(const Duration(days: 4)),
    rounds: rounds,
  );
}

StudentCompanyStatus status(
  String companyId, {
  bool? optedIn,
  OverallStatus overall = OverallStatus.active,
  List<RoundHistoryEntry> rounds = const [],
}) {
  return StudentCompanyStatus(
    studentId: 's',
    companyId: companyId,
    optedIn: optedIn,
    overallStatus: overall,
    roundHistory: rounds,
  );
}

const cleared = [
  RoundHistoryEntry(roundId: 'r1', result: RoundResult.cleared),
];

WidgetFeed feedOf(
  List<Company> companies, [
  Map<String, StudentCompanyStatus> statuses = const {},
]) {
  return buildWidgetFeed(
    companies: companies,
    statusesByCompanyId: statuses,
    now: now,
  );
}

void main() {
  test('shortlisted drives win over open ones', () {
    final feed = feedOf(
      [drive('open a'), drive('shortlisted'), drive('open b')],
      {'shortlisted': status('shortlisted', rounds: cleared)},
    );

    expect(feed.headline, 'You are through');
    expect(feed.drives.map((d) => d.name).toList(), ['shortlisted']);
  });

  test('a selected drive counts as shortlisted', () {
    final feed = feedOf(
      [drive('offer')],
      {'offer': status('offer', overall: OverallStatus.selected)},
    );
    expect(feed.drives.single.name, 'offer');
  });

  test('falls back to open drives not yet opted into', () {
    final feed = feedOf(
      [drive('joined'), drive('untouched')],
      {'joined': status('joined', optedIn: true)},
    );

    expect(feed.headline, 'Open now');
    expect(feed.drives.map((d) => d.name).toList(), ['untouched']);
  });

  test('an explicit opt-out still counts as not opted into', () {
    final feed = feedOf(
      [drive('declined')],
      {'declined': status('declined', optedIn: false)},
    );
    expect(feed.drives.single.name, 'declined');
  });

  test('a closed drive never reaches the widget', () {
    final feed = feedOf([
      drive('gone', status: CompanyStatus.closed),
      drive('done', status: CompanyStatus.resultsDeclared),
    ]);
    expect(feed.isEmpty, isTrue);
    expect(feed.headline, 'Open now');
  });

  test('never more than two rows, soonest deadline first', () {
    final feed = feedOf([
      drive('third', deadline: now.add(const Duration(days: 9))),
      drive('first', deadline: now.add(const Duration(hours: 5))),
      drive('second', deadline: now.add(const Duration(days: 2))),
    ]);

    expect(feed.drives.length, widgetSlotCount);
    expect(feed.drives.map((d) => d.name).toList(), ['first', 'second']);
  });

  test('shortlisted rows read the drive stage, open rows read the deadline', () {
    final shortlisted = feedOf(
      [
        drive(
          'through',
          status: CompanyStatus.inProgress,
          rounds: const [
            CompanyRound(
              id: 'oa',
              name: 'Online assessment',
              order: 1,
              type: RoundType.oa,
            ),
          ],
        ),
      ],
      {'through': status('through', rounds: cleared)},
    );
    expect(shortlisted.drives.single.line, 'Online assessment scheduled');

    final open = feedOf([drive('waiting')]);
    expect(open.drives.single.line, isNotEmpty);
  });

  test('nothing anywhere gives an empty feed', () {
    expect(feedOf(const []).isEmpty, isTrue);
  });
}
