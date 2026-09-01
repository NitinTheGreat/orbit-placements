import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum NoticeTone { urgent, accent, success }

class OrbitNotice extends StatelessWidget {
  const OrbitNotice({
    super.key,
    required this.message,
    this.tone = NoticeTone.urgent,
    this.title,
    this.icon,
  });

  final String message;
  final NoticeTone tone;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    final (Color wash, Color ink) = switch (tone) {
      NoticeTone.urgent => (colors.urgentWash, colors.urgentInk),
      NoticeTone.accent => (colors.accentWash, colors.accentInk),
      NoticeTone.success => (colors.successWash, colors.successInk),
    };

    return Container(
      padding: const EdgeInsets.all(OrbitSpacing.lg),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: ink.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline, size: 19, color: ink),
          const SizedBox(width: OrbitSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.labelLarge?.copyWith(color: ink),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tone == NoticeTone.urgent ? ink : colors.ink,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrbitEmptyState extends StatelessWidget {
  const OrbitEmptyState({
    super.key,
    required this.headline,
    required this.guidance,
    required this.icon,
    this.action,
  });

  final String headline;
  final String guidance;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(OrbitSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(OrbitRadius.card),
              ),
              child: Icon(icon, size: 26, color: colors.inkFaint),
            ),
            const SizedBox(height: OrbitSpacing.xl),
            Text(
              headline,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: OrbitSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                guidance,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: OrbitSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
