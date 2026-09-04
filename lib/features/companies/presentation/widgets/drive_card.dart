import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/urgency_rail.dart';
import '../../../../models/application_status.dart';
import '../../../../models/branch_eligibility.dart';
import '../../../../models/company.dart';
import '../../../../models/student_company_status.dart';
import '../application_channel.dart';
import '../company_format.dart';
import '../drive_date.dart';
import '../currency_format.dart';
import 'stage_pill.dart';

class DriveCard extends StatelessWidget {
  const DriveCard({
    super.key,
    required this.company,
    this.status,
    this.branch,
    this.deEmphasiseConcluded = false,
    this.onTap,
  });

  final Company company;
  final StudentCompanyStatus? status;
  final BranchInfo? branch;
  final bool deEmphasiseConcluded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final application = DriveApplication(company: company, status: status);
    final relevance = branchRelevance(
      branch: branch,
      eligibleBranches: company.eligibleBranches,
    );
    final offBranch = relevance == BranchRelevance.notOpen;
    final muted =
        offBranch || (deEmphasiseConcluded && application.isConcluded);
    final urgency = muted ? DeadlineUrgency.passed : application.urgency;
    final channel = applicationChannel(company.requirements);

    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(OrbitRadius.card),
          border: Border.all(
            color: urgency.isPressing
                ? colors.urgent.withValues(alpha: 0.45)
                : colors.border,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: OrbitSpacing.md,
              top: OrbitSpacing.md,
              bottom: OrbitSpacing.md,
              child: UrgencyRail(urgency: urgency),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OrbitSpacing.xl + OrbitSpacing.xs,
                OrbitSpacing.lg,
                OrbitSpacing.lg,
                OrbitSpacing.lg,
              ),
              child: Opacity(
                opacity: muted ? 0.58 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'company-name-${company.id}',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Text(
                          company.name,
                          style: theme.textTheme.titleLarge,
                          softWrap: true,
                        ),
                      ),
                    ),
                    if (company.category.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(company.category, style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: OrbitSpacing.md),
                    Wrap(
                      spacing: OrbitSpacing.sm,
                      runSpacing: OrbitSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StagePill(application: application, dense: true),
                        if (offBranch) const OffBranchTag(),
                        if (channel != null) NeutralTag(label: channel),
                      ],
                    ),
                    const SizedBox(height: OrbitSpacing.md),
                    _DeadlineLine(
                      shown: driveDate(company),
                      urgency: urgency,
                    ),
                    if (company.ctc != null && company.ctc!.isNotEmpty) ...[
                      const SizedBox(height: OrbitSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 15,
                            color: colors.inkFaint,
                          ),
                          const SizedBox(width: OrbitSpacing.sm),
                          Expanded(
                            child: Text(
                              formatAmounts(company.ctc),
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NeutralTag extends StatelessWidget {
  const NeutralTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OrbitSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(OrbitRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.inkMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class OffBranchTag extends StatelessWidget {
  const OffBranchTag({super.key});

  @override
  Widget build(BuildContext context) {
    return const NeutralTag(label: 'Not open to your branch');
  }
}

class _DeadlineLine extends StatelessWidget {
  const _DeadlineLine({required this.shown, required this.urgency});

  final DriveDate shown;
  final DeadlineUrgency urgency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final pressing =
        urgency.isPressing && shown.kind == DriveDateKind.registration;
    final tint = pressing ? colors.urgentInk : colors.inkMuted;

    return Row(
      children: [
        Icon(
          pressing ? Icons.timer_outlined : Icons.event_outlined,
          size: 15,
          color: tint,
        ),
        const SizedBox(width: OrbitSpacing.sm),
        Expanded(
          child: Text(
            switch (shown.kind) {
              DriveDateKind.unknown => shown.label,
              DriveDateKind.registration => CompanyFormat.deadlineLabel(
                shown.date,
              ),
              _ => '${shown.label} ${CompanyFormat.date(shown.date)}',
            },
            style: theme.textTheme.labelMedium?.copyWith(
              color: tint,
              fontWeight: pressing ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
