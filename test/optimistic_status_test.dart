import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/companies/presentation/optimistic_status.dart';
import 'package:orbit/models/application_status.dart';
import 'package:orbit/models/company.dart';
import 'package:orbit/models/student_company_status.dart';

StudentCompanyStatus serverStatus({
  List<String> completed = const [],
  bool? optedIn,
}) {
  return StudentCompanyStatus(
    studentId: 's',
    companyId: 'c',
    optedIn: optedIn,
    completedRequirementIds: completed,
  );
}

void main() {
  group('optimistic requirements', () {
    test('a tick shows immediately over the server list', () {
      const pending = OptimisticStatus();
      final next = pending.withRequirement('neopat', true);
      expect(next.completedIds(const []), ['neopat']);
      expect(next.isPending('neopat'), isTrue);
    });

    test('an untick removes immediately', () {
      final next = const OptimisticStatus().withRequirement('neopat', false);
      expect(next.completedIds(const ['neopat']), isEmpty);
    });

    test('reverting drops the override and the server value returns', () {
      final next = const OptimisticStatus()
          .withRequirement('neopat', true)
          .withoutRequirement('neopat');
      expect(next.completedIds(const []), isEmpty);
      expect(next.isEmpty, isTrue);
    });

    test('several pending ticks coexist', () {
      final next = const OptimisticStatus()
          .withRequirement('a', true)
          .withRequirement('b', true)
          .withRequirement('c', false);
      expect(next.completedIds(const ['c']).toSet(), {'a', 'b'});
    });

    test('a repeat tap on the same item replaces the override', () {
      final next = const OptimisticStatus()
          .withRequirement('a', true)
          .withRequirement('a', false);
      expect(next.completedIds(const ['a']), isEmpty);
    });
  });

  group('optimistic tracking toggle', () {
    test('a missing doc still reads as tracked', () {
      expect(const OptimisticStatus().optedIn(null), isTrue);
    });

    test('turning off shows immediately', () {
      expect(const OptimisticStatus().withOptedIn(false).optedIn(null), isFalse);
    });

    test('reverting restores the server value', () {
      final next = const OptimisticStatus()
          .withOptedIn(false)
          .withoutOptedIn();
      expect(next.optedIn(true), isTrue);
      expect(next.isEmpty, isTrue);
    });
  });

  group('reconciling with the server', () {
    test('an override clears once the server agrees', () {
      final pending = const OptimisticStatus().withRequirement('neopat', true);
      final settled = pending.reconcile(
        serverStatus(completed: const ['neopat']),
      );
      expect(settled.isEmpty, isTrue);
    });

    test('an override survives while the server lags', () {
      final pending = const OptimisticStatus().withRequirement('neopat', true);
      final settled = pending.reconcile(serverStatus());
      expect(settled.isPending('neopat'), isTrue);
      expect(settled.completedIds(const []), ['neopat']);
    });

    test('a tracking override clears once the server agrees', () {
      final pending = const OptimisticStatus().withOptedIn(false);
      expect(pending.reconcile(serverStatus(optedIn: false)).isEmpty, isTrue);
      expect(
        pending.reconcile(serverStatus(optedIn: true)).isOptedInPending,
        isTrue,
      );
    });

    test('a missing doc counts as opted in when reconciling', () {
      final pending = const OptimisticStatus().withOptedIn(true);
      expect(pending.reconcile(null).isEmpty, isTrue);
    });

    test('one settled override does not clear another still pending', () {
      final pending = const OptimisticStatus()
          .withRequirement('done', true)
          .withRequirement('slow', true);
      final settled = pending.reconcile(serverStatus(completed: const ['done']));
      expect(settled.isPending('done'), isFalse);
      expect(settled.isPending('slow'), isTrue);
    });
  });

  group('applying to a status doc', () {
    test('a missing doc with no pending edits stays missing', () {
      expect(
        const OptimisticStatus().applyTo(
          null,
          studentId: 's',
          companyId: 'c',
        ),
        isNull,
      );
    });

    test('a pending edit materialises a doc so the UI can read it', () {
      final applied = const OptimisticStatus()
          .withRequirement('neopat', true)
          .applyTo(null, studentId: 's', companyId: 'c');
      expect(applied, isNotNull);
      expect(applied!.completedRequirementIds, ['neopat']);
      expect(applied.optedIn, isNull);
    });

    test('server-only fields are carried through untouched', () {
      final server = StudentCompanyStatus(
        studentId: 's',
        companyId: 'c',
        currentRoundId: 'oa',
        overallStatus: OverallStatus.selected,
        roundHistory: const [
          RoundHistoryEntry(roundId: 'oa', result: RoundResult.cleared),
        ],
      );
      final applied = const OptimisticStatus()
          .withRequirement('neopat', true)
          .applyTo(server, studentId: 's', companyId: 'c');
      expect(applied!.currentRoundId, 'oa');
      expect(applied.overallStatus, OverallStatus.selected);
      expect(applied.roundHistory.single.result, RoundResult.cleared);
    });

    test('completion derived from the optimistic doc flips immediately', () {
      const requirements = [
        CompanyRequirement(
          id: 'neopat',
          type: RequirementType.neopat,
          label: 'Register',
          isRequired: true,
        ),
      ];
      final applied = const OptimisticStatus()
          .withRequirement('neopat', true)
          .applyTo(null, studentId: 's', companyId: 'c');
      expect(
        applicationComplete(requirements, applied!.completedRequirementIds),
        isTrue,
      );
    });
  });
}
