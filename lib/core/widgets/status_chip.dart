import 'package:flutter/material.dart';

import '../../models/company.dart';
import '../theme/app_tokens.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.dense = false});

  final CompanyStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final reduceMotion = prefersReducedMotion(context);

    final (Color wash, Color ink) = switch (status) {
      CompanyStatus.open => (colors.successWash, colors.successInk),
      CompanyStatus.closed => (colors.surfaceSunken, colors.inkMuted),
      _ => (colors.accentWash, colors.accentInk),
    };

    final chip = Container(
      key: ValueKey(status),
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
          Text(
            status.label,
            style: (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
                ?.copyWith(color: ink, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    if (reduceMotion) {
      return chip;
    }

    return AnimatedSwitcher(
      duration: OrbitMotion.base,
      switchInCurve: OrbitMotion.spring,
      switchOutCurve: OrbitMotion.settle,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerRight,
          children: [...previousChildren, ?currentChild],
        );
      },
      child: chip,
    );
  }
}
