import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../models/application_status.dart';

class StagePill extends StatelessWidget {
  const StagePill({super.key, required this.application, this.dense = false});

  final DriveApplication application;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    final (String text, Color wash, Color ink) = switch (application.tag) {
      DriveOutcomeTag.selected => (
        'Selected',
        colors.successWash,
        colors.successInk,
      ),
      DriveOutcomeTag.rejected => (
        'Not selected',
        colors.urgentWash,
        colors.urgentInk,
      ),
      DriveOutcomeTag.driveClosed => (
        application.stage,
        colors.surfaceSunken,
        colors.inkMuted,
      ),
      DriveOutcomeTag.none => (
        application.stage,
        colors.accentWash,
        colors.accentInk,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? OrbitSpacing.sm : OrbitSpacing.md,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(OrbitRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
          ),
          const SizedBox(width: OrbitSpacing.sm),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (dense
                          ? theme.textTheme.labelSmall
                          : theme.textTheme.labelMedium)
                      ?.copyWith(color: ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
