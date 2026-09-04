import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/orbit_notice.dart';
import '../../../core/widgets/pressable.dart';
import '../../../models/branch_eligibility.dart';
import '../../../models/display_name.dart';
import '../../../models/gmail_sync.dart';
import '../../../models/student_company_status.dart';
import '../../../services/firestore_service.dart';
import '../../../services/sync_service.dart';
import '../../home/presentation/home_state.dart';
import 'company_format.dart';
import 'company_page_controller.dart';
import 'drive_filter.dart';
import 'drive_list_empty_state.dart';
import 'drive_ordering.dart';
import 'widgets/drive_card.dart';

const double _loadMoreThreshold = 400;

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key, this.lock, this.title, this.subtitle});

  final DriveLock? lock;
  final String? title;
  final String? subtitle;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
    await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final session = SessionScope.of(context);
    final greeting = greetingName(
      name: session.student?.name,
      regNo: session.student?.regNo,
    );
    final studentId = session.user?.uid;
    final locked = widget.lock != null;

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
                          widget.title ??
                              (greeting == null
                                  ? 'Your drives'
                                  : 'Hello, $greeting'),
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: theme.textTheme.bodySmall,
                          )
                        else
                          _LastCheckedLine(sync: session.gmailSync),
                      ],
                    ),
                  ),
                  if (!locked && session.isAdmin)
                    IconButton(
                      tooltip: 'Add a drive',
                      icon: const Icon(Icons.add),
                      color: colors.ink,
                      onPressed: () => context.goNamed(AppRoutes.admin),
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
                        final statuses = snapshot.data ?? const [];
                        final byCompany = {
                          for (final status in statuses)
                            status.companyId: status,
                        };
                        final branch = branchForRegNo(session.student?.regNo);
                        final optedOutCount = statuses
                            .where((status) => status.isOptedOut)
                            .length;

                        if (locked) {
                          return _buildBody(
                            gmailConnected: session.gmailSync.isConnected,
                            optedOutCount: optedOutCount,
                            statusesByCompanyId: byCompany,
                            branch: branch,
                            filter: DriveFilter.all,
                          );
                        }

                        return ValueListenableBuilder<DriveFilter>(
                          valueListenable: drivesFilter,
                          builder: (context, filter, _) {
                            return Column(
                              children: [
                                _FilterChips(
                                  selected: filter,
                                  onSelect: (next) => drivesFilter.value = next,
                                ),
                                Expanded(
                                  child: _buildBody(
                                    gmailConnected:
                                        session.gmailSync.isConnected,
                                    optedOutCount: optedOutCount,
                                    statusesByCompanyId: byCompany,
                                    branch: branch,
                                    filter: filter,
                                  ),
                                ),
                              ],
                            );
                          },
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
    required Map<String, StudentCompanyStatus> statusesByCompanyId,
    required BranchInfo? branch,
    required DriveFilter filter,
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

    final lock = widget.lock;
    final narrowedView = lock != null || filter != DriveFilter.all;
    if (narrowedView && _controller.hasMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.loadAllRemaining();
        }
      });
    }
    final loaded = _controller.companies;
    final matched = lock == null
        ? applyFilter(
            filter: filter,
            companies: loaded,
            statusesByCompanyId: statusesByCompanyId,
            branch: branch,
          )
        : applyLock(
            lock: lock,
            companies: loaded,
            statusesByCompanyId: statusesByCompanyId,
          );
    final companies = orderDrives(
      companies: matched,
      statusesByCompanyId: statusesByCompanyId,
      branch: branch,
    );

    if (narrowedView && companies.isEmpty && _controller.hasMore) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }

    if (narrowedView && companies.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          children: [
            const SizedBox(height: 60),
            OrbitEmptyState(
              icon: switch (lock) {
                DriveLock.openNow => Icons.lock_clock_outlined,
                DriveLock.shortlisted => Icons.workspace_premium_outlined,
                null => switch (filter) {
                  DriveFilter.actionNeeded => Icons.check_circle_outline,
                  DriveFilter.selected => Icons.emoji_events_outlined,
                  DriveFilter.closed => Icons.lock_outline,
                  _ => Icons.filter_list_off,
                },
              },
              headline: lock == null
                  ? emptyStateHeadline(filter)
                  : lockEmptyHeadline(lock),
              guidance: '',
            ),
          ],
        ),
      );
    }

    final emptyState = _showAllDespiteOptOut
        ? null
        : resolveEmptyState(
            gmailConnected: gmailConnected,
            companyCount: loaded.length,
            optedOutOfAll: everyDriveOptedOut(
              companyCount: loaded.length,
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
            status: statusesByCompanyId[company.id],
            branch: branch,
            deEmphasiseConcluded: widget.lock == DriveLock.shortlisted,
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});

  final DriveFilter selected;
  final ValueChanged<DriveFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: OrbitSpacing.lg),
        itemCount: DriveFilter.values.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: OrbitSpacing.sm),
        itemBuilder: (context, index) {
          final filter = DriveFilter.values[index];
          final active = filter == selected;
          return Center(
            child: Pressable(
              onTap: () => onSelect(filter),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: OrbitSpacing.lg,
                  vertical: OrbitSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: active ? colors.accentWash : colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(OrbitRadius.control),
                  border: Border.all(
                    color: active ? colors.accentEdge : colors.border,
                  ),
                ),
                child: Text(
                  filter.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: active ? colors.accentInk : colors.inkMuted,
                    fontWeight: active ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
