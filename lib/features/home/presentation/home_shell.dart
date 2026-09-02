import 'package:flutter/material.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/pressable.dart';
import '../../assistant/presentation/assistant_button.dart';
import '../../companies/presentation/company_list_screen.dart';
import '../../companies/presentation/drive_filter.dart';
import '../../profile/presentation/profile_screen.dart';
import 'home_state.dart';
import 'widget_nudge.dart';
import 'widget_refresher.dart';

class HomeDestination {
  const HomeDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder builder;
}

final List<HomeDestination> homeDestinations = <HomeDestination>[
  HomeDestination(
    label: 'Drives',
    icon: Icons.travel_explore_outlined,
    activeIcon: Icons.travel_explore,
    builder: (context) => const CompanyListScreen(),
  ),
  HomeDestination(
    label: 'Open now',
    icon: Icons.lock_open_outlined,
    activeIcon: Icons.lock_open,
    builder: (context) => const CompanyListScreen(
      lock: DriveLock.openNow,
      title: 'Open now',
      subtitle: 'Registration has not closed yet',
    ),
  ),
  HomeDestination(
    label: 'Shortlisted',
    icon: Icons.workspace_premium_outlined,
    activeIcon: Icons.workspace_premium,
    builder: (context) => const CompanyListScreen(
      lock: DriveLock.shortlisted,
      title: 'Shortlisted',
      subtitle: 'Drives where you have cleared a round',
    ),
  ),
  HomeDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    builder: (context) => const ProfileScreen(),
  ),
];

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: homeTabIndex,
      builder: (context, index, _) {
        return Scaffold(
          body: WidgetNudge(
            child: WidgetRefresher(
              studentId: SessionScope.of(context).user?.uid,
              child: IndexedStack(
                index: index,
                children: [
                  for (final destination in homeDestinations)
                    destination.builder(context),
                ],
              ),
            ),
          ),
          floatingActionButton: const AssistantButton(),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: _HomeBar(
            index: index,
            onSelect: (next) => homeTabIndex.value = next,
          ),
        );
      },
    );
  }
}

class _HomeBar extends StatelessWidget {
  const _HomeBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OrbitSpacing.sm,
            vertical: OrbitSpacing.sm,
          ),
          child: Row(
            children: [
              for (var i = 0; i < homeDestinations.length; i++)
                Expanded(
                  child: _BarItem(
                    destination: homeDestinations[i],
                    active: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.destination,
    required this.active,
    required this.onTap,
  });

  final HomeDestination destination;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final tint = active ? colors.accentInk : colors.inkFaint;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: OrbitSpacing.sm),
        decoration: BoxDecoration(
          color: active ? colors.accentWash : Colors.transparent,
          borderRadius: BorderRadius.circular(OrbitRadius.control),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? destination.activeIcon : destination.icon,
              size: 21,
              color: tint,
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: tint,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
