import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/company_format.dart';
import 'package:orbit/features/companies/presentation/currency_format.dart';
import 'package:orbit/features/companies/presentation/drive_filter.dart';
import 'package:orbit/models/application_status.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

final now = DateTime(2026, 9, 2, 12);
final future = now.add(const Duration(days: 5));
final past = now.subtract(const Duration(days: 1));

CompanyRequirement requirement(
  String id, {
  bool required = true,
  RequirementType type = RequirementType.googleForm,
}) {
  return CompanyRequirement(
    id: id,
    type: type,
    label: id,
    isRequired: required,
  );
}

CompanyRound round(String id, int order, RoundType type, {String? name}) {
  return CompanyRound(id: id, name: name ?? id, order: order, type: type);
}

Company company({
  List<CompanyRequirement> requirements = const [],
  List<CompanyRound> rounds = const [],
  CompanyStatus status = CompanyStatus.registrationOpen,
  DateTime? deadline,
  String? stipend,
  StipendPeriod stipendPeriod = StipendPeriod.unspecified,
}) {
  return Company(
    id: 'c1',
    name: 'Rubrik',
    category: 'Super Dream',
    requirements: requirements,
    rounds: rounds,
    status: status,
    registrationDeadline: deadline,
    stipend: stipend,
    stipendPeriod: stipendPeriod,
  );
}

StudentCompanyStatus status({
  bool? optedIn,
  List<String> completed = const [],
  OverallStatus overall = OverallStatus.active,
  List<RoundHistoryEntry> history = const [],
}) {
  return StudentCompanyStatus(
    studentId: 'u1',
    companyId: 'c1',
    optedIn: optedIn,
    completedRequirementIds: completed,
    overallStatus: overall,
    roundHistory: history,
  );
}

void main() {
  group('missing status doc', () {
    test('reads as opted in with nothing completed', () {
      final application = DriveApplication(
        company: company(requirements: [requirement('a')], deadline: future),
        status: null,
        now: now,
      );

      expect(application.optedIn, isNull);
      expect(application.completedIds, isEmpty);
      expect(application.overallStatus, OverallStatus.active);
      expect(application.isComplete, isFalse);
      expect(application.needsAction, isTrue);
      expect(application.isInProgress, isFalse);
    });

    test('a drive with no required items is complete even with no doc', () {
      final application = DriveApplication(
        company: company(
          requirements: [requirement('a', required: false)],
          deadline: future,
        ),
        status: null,
        now: now,
      );
      expect(application.isComplete, isTrue);
      expect(application.needsAction, isFalse);
    });
  });

  group('applicationComplete', () {
    test('an empty required set counts as complete', () {
      expect(applicationComplete(const [], const []), isTrue);
    });

    test('every required id must be present', () {
      final reqs = [requirement('a'), requirement('b')];
      expect(applicationComplete(reqs, ['a']), isFalse);
      expect(applicationComplete(reqs, ['a', 'b']), isTrue);
    });

    test('optional items never block completion', () {
      final reqs = [requirement('a'), requirement('b', required: false)];
      expect(applicationComplete(reqs, ['a']), isTrue);
    });
  });

  group('actionNeeded', () {
    test('true for an open incomplete drive before the deadline', () {
      expect(
        DriveApplication(
          company: company(requirements: [requirement('a')], deadline: future),
          status: status(),
          now: now,
        ).needsAction,
        isTrue,
      );
    });

    test('false when opted out, complete, or past the deadline', () {
      expect(
        DriveApplication(
          company: company(requirements: [requirement('a')], deadline: future),
          status: status(optedIn: false),
          now: now,
        ).needsAction,
        isFalse,
      );
      expect(
        DriveApplication(
          company: company(requirements: [requirement('a')], deadline: future),
          status: status(completed: ['a']),
          now: now,
        ).needsAction,
        isFalse,
      );
      expect(
        DriveApplication(
          company: company(requirements: [requirement('a')], deadline: past),
          status: status(),
          now: now,
        ).needsAction,
        isFalse,
      );
    });

    test('false once the drive is closed or results are declared', () {
      for (final concluded in [
        CompanyStatus.closed,
        CompanyStatus.resultsDeclared,
      ]) {
        expect(
          DriveApplication(
            company: company(
              requirements: [requirement('a')],
              deadline: future,
              status: concluded,
            ),
            status: status(),
            now: now,
          ).needsAction,
          isFalse,
          reason: '$concluded should suppress actionNeeded',
        );
      }
    });

    test('in progress still counts as actionable', () {
      expect(
        DriveApplication(
          company: company(
            requirements: [requirement('a')],
            deadline: future,
            status: CompanyStatus.inProgress,
          ),
          status: status(),
          now: now,
        ).needsAction,
        isTrue,
      );
    });

    test('a required item added after completion reopens the application', () {
      final completed = ['a'];
      expect(
        DriveApplication(
          company: company(requirements: [requirement('a')], deadline: future),
          status: status(completed: completed),
          now: now,
        ).needsAction,
        isFalse,
      );
      expect(
        DriveApplication(
          company: company(
            requirements: [requirement('a'), requirement('b')],
            deadline: future,
          ),
          status: status(completed: completed),
          now: now,
        ).needsAction,
        isTrue,
      );
    });
  });

  group('inProgress', () {
    const cleared = RoundHistoryEntry(
      roundId: 'ppt',
      result: RoundResult.cleared,
    );
    const invited = RoundHistoryEntry(
      roundId: 'ppt',
      result: RoundResult.invited,
    );

    test('true when active with at least one cleared round', () {
      expect(
        DriveApplication(
          company: company(),
          status: status(history: const [cleared]),
          now: now,
        ).isInProgress,
        isTrue,
      );
    });

    test('false with no cleared round', () {
      expect(
        DriveApplication(
          company: company(),
          status: status(history: const [invited]),
          now: now,
        ).isInProgress,
        isFalse,
      );
    });

    test('false when opted out or no longer active', () {
      expect(
        DriveApplication(
          company: company(),
          status: status(optedIn: false, history: const [cleared]),
          now: now,
        ).isInProgress,
        isFalse,
      );
      expect(
        DriveApplication(
          company: company(),
          status: status(
            overall: OverallStatus.selected,
            history: const [cleared],
          ),
          now: now,
        ).isInProgress,
        isFalse,
      );
    });
  });

  group('companyStage priority', () {
    test('1 closed beats everything below it', () {
      expect(
        companyStage(
          company(
            status: CompanyStatus.closed,
            rounds: [round('oa', 1, RoundType.oa)],
            deadline: future,
          ),
          now: now,
        ),
        'Drive closed',
      );
    });

    test('2 results declared beats rounds and deadline', () {
      expect(
        companyStage(
          company(
            status: CompanyStatus.resultsDeclared,
            rounds: [round('oa', 1, RoundType.oa)],
            deadline: future,
          ),
          now: now,
        ),
        'Results declared',
      );
    });

    test('3 the highest-order round wins over the deadline', () {
      expect(
        companyStage(
          company(
            rounds: [
              round('ppt', 1, RoundType.ppt, name: 'Pre-placement talk'),
              round('oa', 2, RoundType.oa, name: 'Online assessment'),
            ],
            deadline: past,
          ),
          now: now,
        ),
        'Online assessment scheduled',
      );
    });

    test('3 interviews read as announced, other types stay unsuffixed', () {
      expect(
        companyStage(
          company(
            rounds: [
              round('tr', 1, RoundType.interview, name: 'Technical Round 1'),
            ],
          ),
          now: now,
        ),
        'Technical Round 1 announced',
      );
      expect(
        companyStage(
          company(
            rounds: [round('doc', 1, RoundType.other, name: 'Document check')],
          ),
          now: now,
        ),
        'Document check',
      );
    });

    test('3 a name that already reads as a phrase is not suffixed again', () {
      expect(
        companyStage(
          company(rounds: [round('oa', 1, RoundType.oa, name: 'OA scheduled')]),
          now: now,
        ),
        'OA scheduled',
      );
    });

    test('4 no rounds and a passed deadline reads as registration closed', () {
      expect(
        companyStage(company(deadline: past), now: now),
        'Registration closed',
      );
    });

    test('5 no rounds and a future deadline reads as registration open', () {
      expect(
        companyStage(company(deadline: future), now: now),
        'Registration open',
      );
      expect(companyStage(company(), now: now), 'Registration open');
    });
  });

  group('outcome tag priority', () {
    test('selected outranks everything', () {
      expect(
        outcomeTag(
          overallStatus: OverallStatus.selected,
          companyStatus: CompanyStatus.closed,
        ),
        DriveOutcomeTag.selected,
      );
    });

    test('rejected outranks a closed drive', () {
      expect(
        outcomeTag(
          overallStatus: OverallStatus.rejected,
          companyStatus: CompanyStatus.closed,
        ),
        DriveOutcomeTag.rejected,
      );
    });

    test('a closed drive with an active student is the third branch', () {
      expect(
        outcomeTag(
          overallStatus: OverallStatus.active,
          companyStatus: CompanyStatus.closed,
        ),
        DriveOutcomeTag.driveClosed,
      );
    });

    test('an ordinary open drive has no tag', () {
      expect(
        outcomeTag(
          overallStatus: OverallStatus.active,
          companyStatus: CompanyStatus.registrationOpen,
        ),
        DriveOutcomeTag.none,
      );
    });
  });

  group('priority bump', () {
    test('an outstanding step lifts a five day deadline to the coral band', () {
      expect(deadlineUrgency(future, now: now), DeadlineUrgency.thisWeek);
      expect(
        DriveApplication(
          company: company(requirements: [requirement('a')], deadline: future),
          status: status(),
          now: now,
        ).urgency,
        DeadlineUrgency.imminent,
      );
    });

    test('a completed drive keeps the deadline its own urgency', () {
      expect(
        DriveApplication(
          company: company(requirements: [requirement('a')], deadline: future),
          status: status(completed: ['a']),
          now: now,
        ).urgency,
        DeadlineUrgency.thisWeek,
      );
    });

    test('an outcome tag mutes the rail entirely', () {
      expect(
        DriveApplication(
          company: company(requirements: [requirement('a')], deadline: future),
          status: status(overall: OverallStatus.selected),
          now: now,
        ).urgency,
        DeadlineUrgency.passed,
      );
    });

    test('opting out suppresses the bump but keeps the checklist editable', () {
      final application = DriveApplication(
        company: company(requirements: [requirement('a')], deadline: future),
        status: status(optedIn: false),
        now: now,
      );
      expect(application.urgency, DeadlineUrgency.thisWeek);
      expect(application.isEditable, isTrue);
      expect(application.needsAction, isFalse);
    });
  });

  group('checklist editability', () {
    test('locks once closed or past the deadline', () {
      expect(
        checklistEditable(CompanyStatus.closed, future, now: now),
        isFalse,
      );
      expect(
        checklistEditable(CompanyStatus.inProgress, past, now: now),
        isFalse,
      );
      expect(
        checklistEditable(CompanyStatus.registrationOpen, future, now: now),
        isTrue,
      );
    });
  });

  group('Indian digit grouping', () {
    test('groups the documented examples', () {
      expect(groupIndian('800000'), '8,00,000');
      expect(groupIndian('1234567'), '12,34,567');
      expect(groupIndian('45000'), '45,000');
    });

    test('only reformats runs of five or more digits', () {
      expect(formatAmounts('1234'), '1234');
      expect(formatAmounts('45000'), '45,000');
    });

    test('leaves surrounding text and shorthand untouched', () {
      expect(formatAmounts('12 LPA'), '12 LPA');
      expect(formatAmounts('80k per month'), '80k per month');
      expect(formatAmounts('Rs 800000 per year'), 'Rs 8,00,000 per year');
    });

    test('handles an absent value', () {
      expect(formatAmounts(null), '');
      expect(formatAmounts(''), '');
    });
  });

  group('stipend period append', () {
    test('appends when monthly and no month wording is present', () {
      expect(formatStipend('40000', StipendPeriod.monthly), '40,000 / month');
    });

    test('never double appends when the string already says month', () {
      expect(
        formatStipend('40000 per month', StipendPeriod.monthly),
        '40,000 per month',
      );
      expect(
        formatStipend('40000/month', StipendPeriod.monthly),
        '40,000/month',
      );
      expect(formatStipend('45000 pm', StipendPeriod.monthly), '45,000 pm');
    });

    test('does not append for total or unspecified', () {
      expect(formatStipend('300000', StipendPeriod.total), '3,00,000');
      expect(formatStipend('300000', StipendPeriod.unspecified), '3,00,000');
    });

    test('an absent stipend stays empty', () {
      expect(formatStipend(null, StipendPeriod.monthly), '');
    });
  });

  group('tabs', () {
    final open = company(requirements: [requirement('a')], deadline: future);
    final closed = company(
      requirements: [requirement('a')],
      deadline: past,
      status: CompanyStatus.closed,
    );

    test('All keeps everything', () {
      expect(
        matchesFilter(
          filter: DriveFilter.all,
          company: closed,
          status: status(optedIn: false),
          now: now,
        ),
        isTrue,
      );
    });

    test('Action needed matches the derived flag', () {
      expect(
        matchesFilter(
          filter: DriveFilter.actionNeeded,
          company: open,
          status: null,
          now: now,
        ),
        isTrue,
      );
      expect(
        matchesFilter(
          filter: DriveFilter.actionNeeded,
          company: open,
          status: status(completed: ['a']),
          now: now,
        ),
        isFalse,
      );
    });

    test('In progress needs a cleared round', () {
      expect(
        matchesFilter(
          filter: DriveFilter.inProgress,
          company: open,
          status: status(
            history: const [
              RoundHistoryEntry(roundId: 'ppt', result: RoundResult.cleared),
            ],
          ),
          now: now,
        ),
        isTrue,
      );
      expect(
        matchesFilter(
          filter: DriveFilter.inProgress,
          company: open,
          status: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('Selected and Rejected read the personal outcome', () {
      expect(
        matchesFilter(
          filter: DriveFilter.selected,
          company: open,
          status: status(overall: OverallStatus.selected),
          now: now,
        ),
        isTrue,
      );
      expect(
        matchesFilter(
          filter: DriveFilter.rejected,
          company: open,
          status: status(overall: OverallStatus.rejected),
          now: now,
        ),
        isTrue,
      );
    });

    test('Closed reads the drive, not the student outcome', () {
      expect(
        matchesFilter(
          filter: DriveFilter.closed,
          company: closed,
          status: status(overall: OverallStatus.selected),
          now: now,
        ),
        isTrue,
      );
      expect(
        matchesFilter(
          filter: DriveFilter.closed,
          company: open,
          status: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('a passed deadline alone does not mean closed', () {
      expect(
        matchesFilter(
          filter: DriveFilter.closed,
          company: company(deadline: past),
          status: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('empty state headlines', () {
      expect(emptyStateHeadline(DriveFilter.actionNeeded), "You're caught up.");
      expect(
        emptyStateHeadline(DriveFilter.selected),
        'Nothing yet — keep at it.',
      );
    });
  });

  group('not shortlisted', () {
    test('a roster miss reads as Not shortlisted, not Not selected', () {
      expect(
        outcomeTag(
          overallStatus: OverallStatus.rejected,
          companyStatus: CompanyStatus.inProgress,
          roundHistory: const [
            RoundHistoryEntry(roundId: 'oa', result: RoundResult.cleared),
            RoundHistoryEntry(
              roundId: 'final',
              result: RoundResult.notListed,
            ),
          ],
        ),
        DriveOutcomeTag.notShortlisted,
      );
    });

    test('an explicit rejection still reads as Not selected', () {
      expect(
        outcomeTag(
          overallStatus: OverallStatus.rejected,
          companyStatus: CompanyStatus.inProgress,
          roundHistory: const [
            RoundHistoryEntry(roundId: 'oa', result: RoundResult.rejected),
          ],
        ),
        DriveOutcomeTag.rejected,
      );
    });

    test('an offer outranks a roster miss on an earlier round', () {
      expect(
        outcomeTag(
          overallStatus: OverallStatus.selected,
          companyStatus: CompanyStatus.resultsDeclared,
          roundHistory: const [
            RoundHistoryEntry(roundId: 'oa', result: RoundResult.notListed),
          ],
        ),
        DriveOutcomeTag.selected,
      );
    });

    test('the wire value round-trips distinctly from rejected', () {
      expect(RoundResult.fromWire('not_listed'), RoundResult.notListed);
      expect(RoundResult.notListed.wireName, 'not_listed');
      expect(RoundResult.notListed.label, 'Not shortlisted');
      expect(RoundResult.fromWire('rejected'), RoundResult.rejected);
    });

    test('an unknown result still falls back to pending', () {
      expect(RoundResult.fromWire('something_new'), RoundResult.pending);
    });
  });
}
