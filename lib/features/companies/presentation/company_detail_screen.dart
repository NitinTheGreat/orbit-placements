import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/orbit_notice.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/urgency_rail.dart';
import '../../../models/company.dart';
import '../../../models/student_company_status.dart';
import '../../../services/firestore_service.dart';
import 'company_format.dart';

class CompanyDetailScreen extends StatefulWidget {
  const CompanyDetailScreen({super.key, required this.companyId});

  final String companyId;

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late final Stream<Company?> _company = _firestoreService.watchCompany(
    widget.companyId,
  );

  @override
  Widget build(BuildContext context) {
    final colors = OrbitTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 21),
          color: colors.ink,
          onPressed: () => context.goNamed(AppRoutes.companies),
        ),
        title: Text('Drive', style: Theme.of(context).textTheme.titleMedium),
      ),
      body: StreamBuilder<Company?>(
        stream: _company,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const OrbitEmptyState(
              icon: Icons.wifi_off_outlined,
              headline: 'This drive did not load',
              guidance:
                  'Check your connection and open it again from your list.',
            );
          }
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.active) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            );
          }

          final company = snapshot.data;
          if (company == null) {
            return const OrbitEmptyState(
              icon: Icons.inbox_outlined,
              headline: 'This drive was removed',
              guidance:
                  'The placement cell took it down. Head back to see what is '
                  'still open.',
            );
          }

          return _DetailBody(
            company: company,
            firestoreService: _firestoreService,
          );
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.company, required this.firestoreService});

  final Company company;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final studentId = session.user?.uid;

    if (studentId == null) {
      return _content(context, null);
    }

    return StreamBuilder<StudentCompanyStatus?>(
      stream: firestoreService.watchStatus(
        studentId: studentId,
        companyId: company.id,
      ),
      builder: (context, snapshot) => _content(context, snapshot.data),
    );
  }

  Widget _content(BuildContext context, StudentCompanyStatus? status) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final urgency = deadlineUrgency(company.registrationDeadline);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        OrbitSpacing.xl,
        OrbitSpacing.sm,
        OrbitSpacing.xl,
        OrbitSpacing.xxl,
      ),
      children: [
        Hero(
          tag: 'company-name-${company.id}',
          child: Material(
            type: MaterialType.transparency,
            child: Text(company.name, style: theme.textTheme.displaySmall),
          ),
        ),
        if (company.category.isNotEmpty) ...[
          const SizedBox(height: OrbitSpacing.xs),
          Text(company.category, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: OrbitSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(status: company.status),
        ),
        const SizedBox(height: OrbitSpacing.xl),
        _TrackingToggle(
          company: company,
          firestoreService: firestoreService,
          status: status,
        ),
        const SizedBox(height: OrbitSpacing.xl),
        _DeadlineCard(deadline: company.registrationDeadline, urgency: urgency),
        const SizedBox(height: OrbitSpacing.xl),
        _Section(
          title: 'The offer',
          children: [
            _Fact(label: 'CTC', value: company.ctc),
            _Fact(label: 'Stipend', value: company.stipend),
          ],
        ),
        const SizedBox(height: OrbitSpacing.xl),
        _Section(
          title: 'Who can apply',
          children: [
            _Fact(
              label: 'Branches',
              value: company.eligibleBranches.isEmpty
                  ? null
                  : company.eligibleBranches.join(', '),
            ),
            _Fact(label: 'Criteria', value: company.eligibilityCriteria),
            _Fact(
              label: 'Visits campus',
              value: company.visitDate == null
                  ? null
                  : CompanyFormat.date(company.visitDate),
            ),
          ],
        ),
        const SizedBox(height: OrbitSpacing.xl),
        _RoundsTimeline(company: company, status: status),
        const SizedBox(height: OrbitSpacing.xl),
        Text('What you need to submit', style: theme.textTheme.titleLarge),
        const SizedBox(height: OrbitSpacing.md),
        if (company.requirements.isEmpty)
          Container(
            padding: const EdgeInsets.all(OrbitSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(OrbitRadius.control),
            ),
            child: Text(
              'Nothing listed yet. Check your mail for the registration form.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          ...company.requirements.map(
            (requirement) => _RequirementRow(requirement: requirement),
          ),
      ],
    );
  }
}

class _TrackingToggle extends StatelessWidget {
  const _TrackingToggle({
    required this.company,
    required this.firestoreService,
    required this.status,
  });

  final Company company;
  final FirestoreService firestoreService;
  final StudentCompanyStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final session = SessionScope.of(context);
    final studentId = session.user?.uid;

    if (studentId == null) {
      return const SizedBox.shrink();
    }

    final tracking = status?.optedIn ?? true;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OrbitSpacing.lg,
        vertical: OrbitSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Track this drive', style: theme.textTheme.labelLarge),
        subtitle: Text(
          tracking
              ? 'Orbit updates your progress from your mail.'
              : 'Orbit ignores this drive when reading your mail.',
          style: theme.textTheme.bodySmall,
        ),
        value: tracking,
        onChanged: (value) => firestoreService.setOptedIn(
          studentId: studentId,
          companyId: company.id,
          optedIn: value,
        ),
      ),
    );
  }
}

class _RoundsTimeline extends StatelessWidget {
  const _RoundsTimeline({required this.company, required this.status});

  final Company company;
  final StudentCompanyStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final rounds = company.orderedRounds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rounds', style: theme.textTheme.titleLarge),
        const SizedBox(height: OrbitSpacing.md),
        if (rounds.isEmpty)
          Container(
            padding: const EdgeInsets.all(OrbitSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(OrbitRadius.control),
            ),
            child: Text(
              'No rounds announced yet. Orbit adds them as the placement cell '
              'sends them out.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          for (int index = 0; index < rounds.length; index++)
            _RoundRow(
              round: rounds[index],
              entry: status?.entryFor(rounds[index].id),
              isLast: index == rounds.length - 1,
            ),
      ],
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({
    required this.round,
    required this.entry,
    required this.isLast,
  });

  final CompanyRound round;
  final RoundHistoryEntry? entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final result = entry?.result;

    final (Color dot, Color wash, Color ink, IconData icon) = switch (result) {
      RoundResult.cleared => (
        colors.successInk,
        colors.successWash,
        colors.successInk,
        Icons.check,
      ),
      RoundResult.rejected => (
        colors.urgentInk,
        colors.urgentWash,
        colors.urgentInk,
        Icons.close,
      ),
      RoundResult.invited => (
        colors.accentEdge,
        colors.accentWash,
        colors.accentInk,
        Icons.arrow_forward,
      ),
      RoundResult.pending => (
        colors.inkMuted,
        colors.surfaceSunken,
        colors.inkMuted,
        Icons.hourglass_empty,
      ),
      null => (
        colors.borderStrong,
        colors.surfaceSunken,
        colors.inkFaint,
        Icons.remove,
      ),
    };

    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 12.25,
            top: 26,
            bottom: 0,
            child: Container(width: 1.5, color: colors.border),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: wash,
                shape: BoxShape.circle,
                border: Border.all(color: dot, width: 1.4),
              ),
              child: Icon(icon, size: 14, color: ink),
            ),
            const SizedBox(width: OrbitSpacing.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : OrbitSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            round.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: OrbitSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: OrbitSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: wash,
                            borderRadius: BorderRadius.circular(
                              OrbitRadius.pill,
                            ),
                          ),
                          child: Text(
                            result?.label ?? 'Not announced for you',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      round.announcedAt == null
                          ? round.type.label
                          : '${round.type.label}, announced '
                                '${CompanyFormat.date(round.announcedAt)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeadlineCard extends StatelessWidget {
  const _DeadlineCard({required this.deadline, required this.urgency});

  final DateTime? deadline;
  final DeadlineUrgency urgency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final pressing = urgency.isPressing;
    final tint = pressing ? colors.urgentInk : urgencyColor(urgency, colors);

    return Container(
      padding: const EdgeInsets.all(OrbitSpacing.lg),
      decoration: BoxDecoration(
        color: pressing ? colors.urgentWash : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        border: Border.all(
          color: pressing
              ? colors.urgent.withValues(alpha: 0.4)
              : colors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: OrbitRadius.rail,
            height: 52,
            child: UrgencyRail(urgency: urgency),
          ),
          const SizedBox(width: OrbitSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration closes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pressing ? tint : colors.inkMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  CompanyFormat.deadlineLabel(deadline),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: pressing ? tint : colors.ink,
                  ),
                ),
                if (deadline != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    CompanyFormat.dateTime(deadline),
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: OrbitSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(OrbitRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final missing = value == null || value!.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OrbitSpacing.lg,
        vertical: OrbitSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              missing ? 'Not announced' : value!,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                color: missing ? colors.inkFaint : colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.requirement});

  final CompanyRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final hasUrl = requirement.url != null && requirement.url!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: OrbitSpacing.sm),
      padding: const EdgeInsets.all(OrbitSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: requirement.isRequired
                  ? colors.accentWash
                  : colors.surfaceSunken,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              requirement.isRequired ? Icons.priority_high : Icons.remove,
              size: 14,
              color: requirement.isRequired
                  ? colors.accentInk
                  : colors.inkFaint,
            ),
          ),
          const SizedBox(width: OrbitSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.label.isEmpty
                      ? requirement.type
                      : requirement.label,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 1),
                Text(
                  requirement.isRequired
                      ? 'Required to be considered'
                      : 'Optional',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: requirement.isRequired
                        ? colors.accentInk
                        : colors.inkFaint,
                  ),
                ),
                if (hasUrl) ...[
                  const SizedBox(height: OrbitSpacing.sm),
                  Text(
                    requirement.url!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.accentInk,
                      decoration: TextDecoration.underline,
                      decorationColor: colors.accentInk.withValues(alpha: 0.4),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
