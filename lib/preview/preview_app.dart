import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/orbit_mark.dart';
import '../core/widgets/orbit_notice.dart';
import '../core/widgets/status_chip.dart';
import '../features/companies/presentation/widgets/drive_card.dart';
import '../models/company.dart';

void main() {
  runApp(const PreviewApp());
}

List<Company> sampleCompanies() {
  final now = DateTime.now();
  return [
    Company(
      id: 'c1',
      name: 'Rubrik',
      category: 'Super Dream',
      ctc: '32 LPA',
      stipend: '80k per month',
      registrationDeadline: now.add(const Duration(hours: 9)),
      visitDate: now.add(const Duration(days: 12)),
      status: CompanyStatus.registrationOpen,
      eligibleBranches: const ['CSE', 'IT', 'ECE'],
      eligibilityCriteria: 'CGPA 8.0 and above, no standing arrears',
      requirements: const [
        CompanyRequirement(
          id: 'registration-form',
          type: RequirementType.googleForm,
          label: 'Fill the registration form on the portal',
          url: 'https://forms.example.com/rubrik-2026',
          isRequired: true,
        ),
        CompanyRequirement(
          id: 'resume',
          type: RequirementType.other,
          label: 'Upload a one-page resume',
          isRequired: true,
        ),
        CompanyRequirement(
          id: 'ppt',
          type: RequirementType.other,
          label: 'Attend the pre-placement talk',
          isRequired: false,
        ),
      ],
    ),
    Company(
      id: 'c2',
      name: 'Zoho',
      category: 'Dream',
      ctc: '12 LPA',
      registrationDeadline: now.add(const Duration(days: 2)),
      status: CompanyStatus.inProgress,
    ),
    Company(
      id: 'c3',
      name: 'Cisco Systems',
      category: 'Super Dream',
      ctc: '24 LPA',
      stipend: '65k per month',
      registrationDeadline: now.add(const Duration(days: 5)),
      status: CompanyStatus.inProgress,
    ),
    Company(
      id: 'c4',
      name: 'Tata Consultancy Services',
      category: 'Core',
      ctc: '7 LPA',
      registrationDeadline: now.add(const Duration(days: 21)),
      status: CompanyStatus.resultsDeclared,
    ),
    Company(
      id: 'c5',
      name: 'Wells Fargo',
      category: 'Dream',
      ctc: '18 LPA',
      registrationDeadline: now.subtract(const Duration(days: 3)),
      status: CompanyStatus.closed,
    ),
  ];
}

class PreviewApp extends StatefulWidget {
  const PreviewApp({super.key});

  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orbit preview',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return OrbitTheme(
          colors: isDark ? OrbitColors.dark : OrbitColors.light,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _PreviewHome(
        mode: _mode,
        onToggle: () => setState(
          () => _mode = _mode == ThemeMode.light
              ? ThemeMode.dark
              : ThemeMode.light,
        ),
      ),
    );
  }
}

class _PreviewHome extends StatelessWidget {
  const _PreviewHome({required this.mode, required this.onToggle});

  final ThemeMode mode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final companies = sampleCompanies();
    final reduceMotion = prefersReducedMotion(context);

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
                          'Hello, Nitin',
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
                  IconButton(
                    tooltip: 'Toggle theme',
                    icon: Icon(
                      mode == ThemeMode.light
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      size: 20,
                    ),
                    color: colors.inkMuted,
                    onPressed: onToggle,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  OrbitSpacing.lg,
                  0,
                  OrbitSpacing.lg,
                  OrbitSpacing.xxl,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(OrbitSpacing.lg),
                    margin: const EdgeInsets.only(bottom: OrbitSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.urgentWash,
                      borderRadius: BorderRadius.circular(OrbitRadius.control),
                      border: Border.all(
                        color: colors.urgent.withValues(alpha: 0.3),
                      ),
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
                                'Gmail is not connected',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colors.urgentInk,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Orbit has stopped tracking your mail. Tap to '
                                'reconnect.',
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
                  ...companies.asMap().entries.map((entry) {
                    final card = DriveCard(company: entry.value, onTap: () {});
                    return Padding(
                      padding: const EdgeInsets.only(bottom: OrbitSpacing.md),
                      child: reduceMotion
                          ? card
                          : card
                                .animate(delay: OrbitMotion.stagger * entry.key)
                                .fadeIn(duration: OrbitMotion.entrance)
                                .slideY(
                                  begin: 0.08,
                                  end: 0,
                                  duration: OrbitMotion.entrance,
                                  curve: OrbitMotion.settle,
                                ),
                    );
                  }),
                  const SizedBox(height: OrbitSpacing.xl),
                  Text('Components', style: theme.textTheme.titleLarge),
                  const SizedBox(height: OrbitSpacing.md),
                  Wrap(
                    spacing: OrbitSpacing.sm,
                    runSpacing: OrbitSpacing.sm,
                    children: CompanyStatus.values
                        .map((status) => StatusChip(status: status))
                        .toList(),
                  ),
                  const SizedBox(height: OrbitSpacing.lg),
                  const OrbitNotice(
                    title: 'Use your VIT email',
                    message:
                        'nitin@gmail.com is not a VIT student account. Sign in '
                        'with your @vitstudent.ac.in address.',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: OrbitSpacing.md),
                  const OrbitNotice(
                    tone: NoticeTone.success,
                    title: 'Gmail connected',
                    message: 'Orbit is watching your inbox for placement mail.',
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: OrbitSpacing.xl),
                  Row(
                    children: [
                      const OrbitMark(size: 44),
                      const SizedBox(width: OrbitSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Orbit', style: theme.textTheme.displaySmall),
                            Text(
                              'Space Grotesk display, IBM Plex Sans body',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: OrbitSpacing.xl),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Connect Gmail'),
                  ),
                  const SizedBox(height: OrbitSpacing.md),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Sign out'),
                  ),
                  const SizedBox(height: OrbitSpacing.xl),
                  const OrbitEmptyState(
                    icon: Icons.calendar_today_outlined,
                    headline: 'No drives yet',
                    guidance:
                        'When a company opens registrations, it lands here '
                        'with its deadline and what you need to submit.',
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
