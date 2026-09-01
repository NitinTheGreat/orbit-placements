import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/orbit_notice.dart';
import '../../../core/widgets/pressable.dart';
import '../../../models/company.dart';
import '../../../models/gmail_sync.dart';
import '../../../services/firestore_service.dart';
import 'widgets/drive_card.dart';

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
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final session = SessionScope.of(context);
    final firstName = _firstName(session.student?.name);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OrbitSpacing.xl,
                OrbitSpacing.lg,
                OrbitSpacing.lg,
                OrbitSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName == null
                              ? 'Your drives'
                              : 'Hello, $firstName',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Every drive you need to act on',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (session.isAdmin)
                    IconButton(
                      tooltip: 'Add a drive',
                      icon: const Icon(Icons.add),
                      color: colors.ink,
                      onPressed: () => context.goNamed(AppRoutes.admin),
                    ),
                  IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout, size: 20),
                    color: colors.inkMuted,
                    onPressed: session.signOut,
                  ),
                ],
              ),
            ),
            if (!session.gmailSync.isConnected)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  OrbitSpacing.lg,
                  0,
                  OrbitSpacing.lg,
                  OrbitSpacing.md,
                ),
                child: _GmailBanner(status: session.gmailSync.status),
              ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  static String? _firstName(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }

  Widget _buildList() {
    return StreamBuilder<List<Company>>(
      stream: _companies,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const OrbitEmptyState(
            icon: Icons.wifi_off_outlined,
            headline: 'Drives did not load',
            guidance:
                'Check your connection and pull down to try again. Your saved '
                'drives are still safe.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          );
        }

        final companies = snapshot.data!;
        if (companies.isEmpty) {
          return const OrbitEmptyState(
            icon: Icons.calendar_today_outlined,
            headline: 'No drives yet',
            guidance:
                'When a company opens registrations, it lands here with its '
                'deadline and what you need to submit.',
          );
        }

        final reduceMotion = prefersReducedMotion(context);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            OrbitSpacing.lg,
            OrbitSpacing.xs,
            OrbitSpacing.lg,
            OrbitSpacing.xxl,
          ),
          itemCount: companies.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: OrbitSpacing.md),
          itemBuilder: (context, index) {
            final company = companies[index];
            final card = DriveCard(
              company: company,
              onTap: () => context.goNamed(
                AppRoutes.companyDetail,
                pathParameters: {'companyId': company.id},
              ),
            );
            if (reduceMotion) {
              return card;
            }
            return card
                .animate(delay: OrbitMotion.stagger * index)
                .fadeIn(duration: OrbitMotion.entrance)
                .slideY(
                  begin: 0.08,
                  end: 0,
                  duration: OrbitMotion.entrance,
                  curve: OrbitMotion.settle,
                );
          },
        );
      },
    );
  }
}

class _GmailBanner extends StatelessWidget {
  const _GmailBanner({required this.status});

  final GmailConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    return Pressable(
      onTap: () => context.goNamed(AppRoutes.gmailConnect),
      child: Container(
        padding: const EdgeInsets.all(OrbitSpacing.lg),
        decoration: BoxDecoration(
          color: colors.urgentWash,
          borderRadius: BorderRadius.circular(OrbitRadius.control),
          border: Border.all(color: colors.urgent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.link_off, size: 19, color: colors.urgentInk),
            const SizedBox(width: OrbitSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == GmailConnectionStatus.expired
                        ? 'Gmail access expired'
                        : 'Gmail is not connected',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.urgentInk,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Orbit has stopped tracking your mail. Tap to reconnect.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.urgentInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
