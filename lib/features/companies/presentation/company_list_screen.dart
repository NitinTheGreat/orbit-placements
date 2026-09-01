import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/orbit_notice.dart';
import '../../../core/widgets/pressable.dart';
import '../../../models/gmail_sync.dart';
import '../../../models/student_company_status.dart';
import '../../../services/firestore_service.dart';
import '../../../services/sync_service.dart';
import 'company_format.dart';
import 'company_page_controller.dart';
import 'drive_list_empty_state.dart';
import 'widgets/drive_card.dart';

const double _loadMoreThreshold = 400;

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final SyncService _syncService = SyncService();
  final CompanyPageController _controller = CompanyPageController();
  final ScrollController _scrollController = ScrollController();

  bool _showAllDespiteOptOut = false;

  @override
  void initState() {
    super.initState();
    _controller.start();
    _controller.addListener(_onControllerChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _controller.loadMore();
    }
  }

  Future<void> _refresh() async {
    try {
      await _syncService.syncNow();
    } on SyncException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
    await _controller.refresh();
  }

  static String? _firstName(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final session = SessionScope.of(context);
    final firstName = _firstName(session.student?.name);
    final studentId = session.user?.uid;

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
                        _LastCheckedLine(sync: session.gmailSync),
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
            Expanded(
              child: studentId == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<StudentCompanyStatus>>(
                      stream: _firestoreService.watchStatusesForStudent(
                        studentId,
                      ),
                      builder: (context, snapshot) {
                        final optedOutCount = (snapshot.data ?? [])
                            .where((status) => status.isOptedOut)
                            .length;
                        return _buildBody(
                          gmailConnected: session.gmailSync.isConnected,
                          optedOutCount: optedOutCount,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required bool gmailConnected,
    required int optedOutCount,
  }) {
    if (_controller.error != null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          children: const [
            SizedBox(height: 80),
            OrbitEmptyState(
              icon: Icons.wifi_off_outlined,
              headline: 'Drives did not load',
              guidance:
                  'Check your connection and pull down to try again. Your '
                  'saved drives are still safe.',
            ),
          ],
        ),
      );
    }

    if (_controller.isLoading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }

    final companies = _controller.companies;
    final emptyState = _showAllDespiteOptOut
        ? null
        : resolveEmptyState(
            gmailConnected: gmailConnected,
            companyCount: companies.length,
            optedOutOfAll: everyDriveOptedOut(
              companyCount: companies.length,
              optedOutCount: optedOutCount,
            ),
          );

    if (emptyState != null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          children: [
            const SizedBox(height: 60),
            _EmptyStateView(
              state: emptyState,
              onShowAll: () => setState(() => _showAllDespiteOptOut = true),
            ),
          ],
        ),
      );
    }

    final reduceMotion = prefersReducedMotion(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          OrbitSpacing.lg,
          OrbitSpacing.xs,
          OrbitSpacing.lg,
          OrbitSpacing.xxl,
        ),
        itemCount: companies.length + (_controller.hasMore ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: OrbitSpacing.md),
        itemBuilder: (context, index) {
          if (index >= companies.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: OrbitSpacing.xl),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            );
          }

          final company = companies[index];
          final card = DriveCard(
            company: company,
            onTap: () => context.goNamed(
              AppRoutes.companyDetail,
              pathParameters: {'companyId': company.id},
            ),
          );
          if (reduceMotion || index >= _controller.pageSize) {
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
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView({required this.state, required this.onShowAll});

  final DriveListEmptyState state;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case DriveListEmptyState.gmailDisconnected:
        return OrbitEmptyState(
          icon: Icons.mark_email_unread_outlined,
          headline: 'Connect Gmail to start tracking',
          guidance:
              'Orbit reads your placement mail to build this list. Reconnect '
              'and your drives appear here on their own.',
          action: FilledButton(
            onPressed: () => context.goNamed(AppRoutes.gmailConnect),
            child: const Text('Connect Gmail'),
          ),
        );
      case DriveListEmptyState.noDrives:
        return const OrbitEmptyState(
          icon: Icons.calendar_today_outlined,
          headline: 'No drives yet',
          guidance:
              'Orbit is watching your inbox. When the placement cell opens a '
              'drive, it lands here with its deadline and what to submit.',
        );
      case DriveListEmptyState.allOptedOut:
        return OrbitEmptyState(
          icon: Icons.notifications_off_outlined,
          headline: 'Tracking is off everywhere',
          guidance:
              'Orbit is ignoring every drive it knows about. Open one and turn '
              'tracking back on to follow your rounds again.',
          action: OutlinedButton(
            onPressed: onShowAll,
            child: const Text('Show all drives'),
          ),
        );
    }
  }
}

class _LastCheckedLine extends StatelessWidget {
  const _LastCheckedLine({required this.sync});

  final GmailSync sync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    if (!sync.isConnected) {
      return Text(
        'Every drive you need to act on',
        style: theme.textTheme.bodySmall,
      );
    }

    final stale = sync.isStale(DateTime.now());
    return Text(
      'Last checked ${relativeSince(sync.lastSyncedAt)}',
      style: theme.textTheme.bodySmall?.copyWith(
        color: stale ? colors.urgentInk : null,
        fontWeight: stale ? FontWeight.w600 : null,
      ),
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

    final headline = switch (status) {
      GmailConnectionStatus.needsReconnect ||
      GmailConnectionStatus.expired => 'Gmail disconnected',
      _ => 'Gmail is not connected',
    };

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
                    headline,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.urgentInk,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Reconnect to keep tracking. Tap to fix.',
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
