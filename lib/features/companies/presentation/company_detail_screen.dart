import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../models/company.dart';
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(AppRoutes.companies),
        ),
        title: const Text('Drive details'),
      ),
      body: StreamBuilder<Company?>(
        stream: _company,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _CenteredMessage('Could not load this drive.');
          }
          if (!snapshot.hasData && snapshot.connectionState != ConnectionState.active) {
            return const Center(child: CircularProgressIndicator());
          }

          final company = snapshot.data;
          if (company == null) {
            return const _CenteredMessage('This drive no longer exists.');
          }

          return _CompanyDetailBody(company: company);
        },
      ),
    );
  }
}

class _CompanyDetailBody extends StatelessWidget {
  const _CompanyDetailBody({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(company.name, style: theme.textTheme.headlineSmall),
            ),
            StatusChip(status: company.status),
          ],
        ),
        if (company.category.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            company.category,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 24),
        _DetailRow(label: 'CTC', value: company.ctc),
        _DetailRow(label: 'Stipend', value: company.stipend),
        _DetailRow(
          label: 'Registration deadline',
          value: CompanyFormat.dateTime(company.registrationDeadline),
        ),
        _DetailRow(
          label: 'Visit date',
          value: CompanyFormat.date(company.visitDate),
        ),
        _DetailRow(
          label: 'Eligible branches',
          value: company.eligibleBranches.isEmpty
              ? null
              : company.eligibleBranches.join(', '),
        ),
        _DetailRow(
          label: 'Eligibility criteria',
          value: company.eligibilityCriteria,
        ),
        const SizedBox(height: 24),
        Text('Requirements', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (company.requirements.isEmpty)
          Text(
            'No requirements listed for this drive.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...company.requirements.map(
            (requirement) => _RequirementTile(requirement: requirement),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = (value == null || value!.isEmpty) ? 'Not set' : value!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(display, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _RequirementTile extends StatelessWidget {
  const _RequirementTile({required this.requirement});

  final CompanyRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUrl = requirement.url != null && requirement.url!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            requirement.isRequired
                ? Icons.check_box_outline_blank
                : Icons.remove_circle_outline,
            size: 20,
            color: requirement.isRequired
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.label.isEmpty ? requirement.type : requirement.label,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  requirement.isRequired ? 'Required' : 'Optional',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (hasUrl)
                  Text(
                    requirement.url!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
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

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
