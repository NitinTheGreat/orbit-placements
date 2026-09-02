import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/branch_eligibility.dart';
import '../../../models/student_company_status.dart';
import '../../../services/firestore_service.dart';
import '../../companies/presentation/company_page_controller.dart';
import 'profile_stats.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final CompanyPageController _controller = CompanyPageController();

  @override
  void initState() {
    super.initState();
    _controller.start();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final session = SessionScope.of(context);
    final student = session.student;
    final studentId = session.user?.uid;
    final branch = branchForRegNo(student?.regNo);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: studentId == null
            ? const SizedBox.shrink()
            : StreamBuilder<List<StudentCompanyStatus>>(
                stream: _firestoreService.watchStatusesForStudent(studentId),
                builder: (context, snapshot) {
                  final statuses =
                      snapshot.data ?? const <StudentCompanyStatus>[];
                  final byCompany = <String, StudentCompanyStatus>{
                    for (final status in statuses) status.companyId: status,
                  };
                  final stats = profileStats(
                    companies: _controller.companies,
                    statusesByCompanyId: byCompany,
                  );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      OrbitSpacing.lg,
                      OrbitSpacing.lg,
                      OrbitSpacing.lg,
                      OrbitSpacing.xxl,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: OrbitSpacing.sm,
                          bottom: OrbitSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student?.name.trim().isNotEmpty == true
                                  ? student!.name
                                  : 'Your profile',
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              branch == null
                                  ? 'NeoID ${student?.neoId ?? '—'}'
                                  : 'NeoID ${student?.neoId ?? '—'} · '
                                        '${branch.name}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              value: '${stats.drivesTracked}',
                              label: stats.drivesTracked == 1
                                  ? 'drive tracked'
                                  : 'drives tracked',
                            ),
                          ),
                          const SizedBox(width: OrbitSpacing.md),
                          Expanded(
                            child: _StatTile(
                              value: stats.completionLabel,
                              label: stats.requirementsTotal == 0
                                  ? 'no steps yet'
                                  : '${stats.requirementsDone} of '
                                        '${stats.requirementsTotal} steps done',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: OrbitSpacing.md),
                      _BreakdownCard(stats: stats),
                      const SizedBox(height: OrbitSpacing.lg),
                      OutlinedButton.icon(
                        onPressed: session.signOut,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Sign out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.inkMuted,
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(OrbitSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colors.accentInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.stats});

  final ProfileStats stats;

  static Color _sliceColor(OrbitColors colors, DriveOutcomeSlice slice) {
    return switch (slice) {
      DriveOutcomeSlice.actionNeeded => colors.urgent,
      DriveOutcomeSlice.inProgress => colors.accent,
      DriveOutcomeSlice.selected => colors.success,
      DriveOutcomeSlice.rejected => colors.urgentInk,
      DriveOutcomeSlice.closed => colors.borderStrong,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final entries = DriveOutcomeSlice.values
        .where((slice) => (stats.breakdown[slice] ?? 0) > 0)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(OrbitSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where your drives stand', style: theme.textTheme.titleMedium),
          const SizedBox(height: OrbitSpacing.lg),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: OrbitSpacing.lg),
              child: Text(
                'Nothing to chart yet. Once drives start moving, the split '
                'shows up here.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  height: 132,
                  width: 132,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 34,
                      startDegreeOffset: -90,
                      sections: [
                        for (final slice in entries)
                          PieChartSectionData(
                            value: (stats.breakdown[slice] ?? 0).toDouble(),
                            color: _sliceColor(colors, slice),
                            radius: 26,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: OrbitSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final slice in entries)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: OrbitSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: _sliceColor(colors, slice),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: OrbitSpacing.sm),
                              Expanded(
                                child: Text(
                                  slice.label,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                '${stats.breakdown[slice]}',
                                style: theme.textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
