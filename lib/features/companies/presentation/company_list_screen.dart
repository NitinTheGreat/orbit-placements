import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../models/company.dart';
import '../../../services/firestore_service.dart';
import 'company_format.dart';

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late final Stream<List<Company>> _companies =
      _firestoreService.watchCompanies();

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          if (session.isAdmin)
            IconButton(
              tooltip: 'Add company',
              icon: const Icon(Icons.add_business_outlined),
              onPressed: () => context.goNamed(AppRoutes.admin),
            ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: session.signOut,
          ),
        ],
      ),
      body: StreamBuilder<List<Company>>(
        stream: _companies,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _CompanyListMessage(
              icon: Icons.error_outline,
              title: 'Could not load drives',
              subtitle: 'Check your connection and try again.',
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final companies = snapshot.data!;
          if (companies.isEmpty) {
            return const _CompanyListMessage(
              icon: Icons.inbox_outlined,
              title: 'No drives yet',
              subtitle: 'Companies will show up here as they are added.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: companies.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _CompanyCard(company: companies[index]),
          );
        },
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () => context.goNamed(
          AppRoutes.companyDetail,
          pathParameters: {'companyId': company.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      company.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  StatusChip(status: company.status),
                ],
              ),
              if (company.category.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  company.category,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (company.ctc != null && company.ctc!.isNotEmpty)
                    _MetaItem(icon: Icons.payments_outlined, text: company.ctc!),
                  if (company.stipend != null && company.stipend!.isNotEmpty)
                    _MetaItem(
                      icon: Icons.work_outline,
                      text: company.stipend!,
                    ),
                  _MetaItem(
                    icon: Icons.event_outlined,
                    text: CompanyFormat.deadlineLabel(
                      company.registrationDeadline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CompanyListMessage extends StatelessWidget {
  const _CompanyListMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
