import 'package:flutter/material.dart';

import '../../models/company.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final CompanyStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (Color background, Color foreground) = switch (status) {
      CompanyStatus.open => (scheme.primaryContainer, scheme.onPrimaryContainer),
      CompanyStatus.closed => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      _ => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
