import 'package:flutter/material.dart';

import '../../features/companies/presentation/company_format.dart';
import '../theme/app_tokens.dart';

Color urgencyColor(DeadlineUrgency urgency, OrbitColors colors) {
  return switch (urgency) {
    DeadlineUrgency.today || DeadlineUrgency.imminent => colors.urgent,
    DeadlineUrgency.thisWeek => colors.accentEdge,
    DeadlineUrgency.distant => colors.successInk,
    DeadlineUrgency.passed || DeadlineUrgency.unknown => colors.borderStrong,
  };
}

class UrgencyRail extends StatelessWidget {
  const UrgencyRail({super.key, required this.urgency, this.height});

  final DeadlineUrgency urgency;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitTheme.of(context);

    return AnimatedContainer(
      duration: OrbitMotion.base,
      curve: OrbitMotion.settle,
      width: OrbitRadius.rail,
      height: height,
      decoration: BoxDecoration(
        color: urgencyColor(urgency, colors),
        borderRadius: BorderRadius.circular(OrbitRadius.rail),
      ),
    );
  }
}
