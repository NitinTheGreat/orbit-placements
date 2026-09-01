import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/urgency_rail.dart';
import '../../../../models/company.dart';
import '../company_format.dart';

class DriveCard extends StatelessWidget {
  const DriveCard({super.key, required this.company, this.onTap});

  final Company company;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final urgency = deadlineUrgency(company.registrationDeadline);

    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(OrbitRadius.card),
          border: Border.all(
            color: urgency.isPressing ? colors.urgent.withValues(alpha: 0.45) : colors.border,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: OrbitSpacing.md,
                  horizontal: OrbitSpacing.md,
                ),
                child: UrgencyRail(urgency: urgency),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    OrbitSpacing.lg,
                    OrbitSpacing.lg,
                    OrbitSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Hero(
                              tag: 'company-name-${company.id}',
                              child: Material(
                                type: MaterialType.transparency,
                                child: Text(
                                  company.name,
                                  style: theme.textTheme.titleLarge,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: OrbitSpacing.sm),
                          StatusChip(status: company.status, dense: true),
                        ],
                      ),
                      if (company.category.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          company.category,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: OrbitSpacing.md),
                      _DeadlineLine(
                        deadline: company.registrationDeadline,
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
                            Text(
                              company.ctc!,
                              style: theme.textTheme.labelMedium,
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
      ),
    );
  }
}

class _DeadlineLine extends StatelessWidget {
  const _DeadlineLine({required this.deadline, required this.urgency});

  final DateTime? deadline;
  final DeadlineUrgency urgency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final pressing = urgency.isPressing;
    final tint = pressing ? colors.urgentInk : colors.inkMuted;

    return Row(
      children: [
        Icon(
          pressing ? Icons.timer_outlined : Icons.event_outlined,
          size: 15,
          color: tint,
        ),
        const SizedBox(width: OrbitSpacing.sm),
        Flexible(
          child: Text(
            CompanyFormat.deadlineLabel(deadline),
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
