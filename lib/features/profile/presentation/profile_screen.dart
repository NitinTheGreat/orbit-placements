import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/branch_eligibility.dart';
import '../../../models/display_name.dart';
import '../../../models/student_company_status.dart';
import '../../../services/firestore_service.dart';
import '../../../models/company.dart';
import 'profile_stats.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late final Stream<List<Company>> _companies = _firestoreService
      .watchCompanies();

  Future<void> _editNeoId(String uid, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => _NeoIdDialog(controller: controller),
    );
    controller.dispose();

    if (confirmed == null || confirmed.isEmpty) {
      return;
    }

    try {
      await _firestoreService.updateNeoId(uid: uid, neoId: confirmed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NeoID saved. That was your one edit.')),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save that. Try again.')),
        );
      }
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
            : StreamBuilder<List<Company>>(
                stream: _companies,
                builder: (context, companySnapshot) {
                  final allCompanies =
                      companySnapshot.data ?? const <Company>[];
                  return StreamBuilder<List<StudentCompanyStatus>>(
                stream: _firestoreService.watchStatusesForStudent(studentId),
                builder: (context, snapshot) {
                  final statuses =
                      snapshot.data ?? const <StudentCompanyStatus>[];
                  final byCompany = <String, StudentCompanyStatus>{
                    for (final status in statuses) status.companyId: status,
                  };
                  final stats = profileStats(
                    companies: allCompanies,
                    statusesByCompanyId: byCompany,
                    branch: branch,
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
                              displayName(
                                name: student?.name,
                                regNo: student?.regNo,
                              ),
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              branch == null
                                  ? (student?.regNo ?? '')
                                  : '${student?.regNo ?? ''} · '
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
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              value: '${stats.branchRelevant}',
                              label: 'open to your branch and level',
                            ),
                          ),
                          const SizedBox(width: OrbitSpacing.md),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                      const SizedBox(height: OrbitSpacing.md),
                      _NeoIdCard(
                        neoId: student?.neoId ?? '',
                        canEdit: student?.canEditNeoId ?? false,
                        onEdit: () => _editNeoId(studentId, student?.neoId),
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
      DriveOutcomeSlice.tracking => colors.inkFaint,
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

class _NeoIdCard extends StatelessWidget {
  const _NeoIdCard({
    required this.neoId,
    required this.canEdit,
    required this.onEdit,
  });

  final String neoId;
  final bool canEdit;
  final VoidCallback onEdit;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NeoID', style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  neoId.isEmpty ? 'Not set' : neoId,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: OrbitSpacing.xs),
                Text(
                  canEdit
                      ? 'Shortlists are matched on this. You can correct it '
                            'once.'
                      : 'Already corrected once, so this is locked now.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit)
            TextButton(onPressed: onEdit, child: const Text('Change'))
          else
            Icon(Icons.lock_outline, size: 18, color: colors.inkFaint),
        ],
      ),
    );
  }
}

class _NeoIdDialog extends StatelessWidget {
  const _NeoIdDialog({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    return AlertDialog(
      backgroundColor: colors.surfaceRaised,
      title: const Text('Change your NeoID'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This is the one time you can change it. Orbit matches you to '
            'shortlists on this value, so get it right before you save — '
            'after this the field is locked.',
            style: theme.textTheme.bodySmall?.copyWith(color: colors.urgentInk),
          ),
          const SizedBox(height: OrbitSpacing.lg),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'NeoID'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep it as it is'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(controller.text.trim().toUpperCase()),
          child: const Text('Save, I am sure'),
        ),
      ],
    );
  }
}
