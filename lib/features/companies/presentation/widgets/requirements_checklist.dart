import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../models/application_status.dart';
import '../../../../models/company.dart';
import '../company_format.dart';

class RequirementsChecklist extends StatelessWidget {
  const RequirementsChecklist({
    super.key,
    required this.company,
    required this.completedIds,
    required this.editable,
    required this.onToggle,
  });

  final Company company;
  final List<String> completedIds;
  final bool editable;
  final void Function(String requirementId, bool completed) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('What you need to do', style: theme.textTheme.titleLarge),
            const Spacer(),
            Text(
              applicationSummary(
                requirements: company.requirements,
                completedIds: completedIds,
              ),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: OrbitSpacing.md),
        if (company.requirements.isEmpty)
          Container(
            padding: const EdgeInsets.all(OrbitSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(OrbitRadius.control),
            ),
            child: Text(
              'No steps listed in the mail yet — check the original email.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          ...company.requirements.map(
            (requirement) => _RequirementTile(
              requirement: requirement,
              completed: completedIds.contains(requirement.id),
              editable: editable,
              onToggle: onToggle,
            ),
          ),
      ],
    );
  }
}

class _RequirementTile extends StatelessWidget {
  const _RequirementTile({
    required this.requirement,
    required this.completed,
    required this.editable,
    required this.onToggle,
  });

  final CompanyRequirement requirement;
  final bool completed;
  final bool editable;
  final void Function(String requirementId, bool completed) onToggle;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(requirement.url!);
    if (uri == null) {
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    final label = requirement.label.isEmpty
        ? (requirement.type == RequirementType.neopat
              ? 'Register on NeoPAT'
              : requirement.type.label)
        : requirement.label;

    return Container(
      margin: const EdgeInsets.only(bottom: OrbitSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OrbitSpacing.sm,
              OrbitSpacing.sm,
              OrbitSpacing.lg,
              OrbitSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: completed,
                  onChanged: editable
                      ? (value) => onToggle(requirement.id, value ?? false)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: OrbitSpacing.xs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: OrbitSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 15,
                            color: completed ? colors.inkMuted : colors.ink,
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: colors.inkFaint,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          requirement.isRequired ? 'Required' : 'Optional',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!requirement.hasUrl)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OrbitSpacing.xxl + OrbitSpacing.sm,
                0,
                OrbitSpacing.lg,
                OrbitSpacing.md,
              ),
              child: Text(
                requirement.type == RequirementType.neopat
                    ? 'Complete this in the NeoPAT app — no direct link in '
                          'the email.'
                    : 'No direct link in the email — check the original '
                          'message below.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.inkFaint,
                ),
              ),
            ),
          if (requirement.hasUrl)
            InkWell(
              onTap: () => _open(context),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(OrbitRadius.control),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: OrbitSpacing.lg,
                  vertical: OrbitSpacing.md,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 15, color: colors.accentInk),
                    const SizedBox(width: OrbitSpacing.sm),
                    Expanded(
                      child: Text(
                        requirement.url!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.accentInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SourceReference extends StatelessWidget {
  const SourceReference({super.key, required this.company});

  final Company company;

  Future<void> _copy(BuildContext context, String subject) async {
    await Clipboard.setData(ClipboardData(text: subject));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject copied — search it in Gmail.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    if (company.sourceSubject == null && company.lastUpdatedSubject == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (company.sourceSubject != null)
          _SourceLine(
            prefix: 'From',
            subject: company.sourceSubject!,
            date: company.sourceDate,
            onTap: () => _copy(context, company.sourceSubject!),
          ),
        if (company.hasSeparateUpdate)
          _SourceLine(
            prefix: 'Updated',
            subject: company.lastUpdatedSubject!,
            date: company.lastUpdatedDate,
            onTap: () => _copy(context, company.lastUpdatedSubject!),
          ),
        const SizedBox(height: OrbitSpacing.xs),
        Text(
          'Tap to copy the subject, then search it in Gmail.',
          style: theme.textTheme.labelSmall?.copyWith(color: colors.inkFaint),
        ),
      ],
    );
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({
    required this.prefix,
    required this.subject,
    required this.date,
    required this.onTap,
  });

  final String prefix;
  final String subject;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OrbitRadius.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OrbitSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.mail_outline, size: 15, color: colors.inkFaint),
            const SizedBox(width: OrbitSpacing.sm),
            Expanded(
              child: Text(
                date == null
                    ? '$prefix: $subject'
                    : '$prefix: $subject — ${CompanyFormat.date(date)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            Icon(Icons.copy, size: 14, color: colors.inkFaint),
          ],
        ),
      ),
    );
  }
}
