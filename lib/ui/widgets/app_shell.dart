import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion_tokens.dart';
import '../layout/breakpoints.dart';
import '../motion/motion_reduce.dart';
import 'bottom_bar_extension.dart';
import 'shell_bottom_surface.dart';

/// Shared left and right inset for the bottom nav pill and the payment bar.
const kNavSideInset = 16.0;

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const horizontalInset = kNavSideInset;
  static const bottomInset = 12.0;
  static const topInset = 8.0;
  static const barRadius = 28.0;
  static const indicatorSize = Size(40, 32);
  static const indicatorRadius = 16.0;
  static const pressedOpacity = 0.85;
  static const unselectedOpacity = 0.75;
  static const barHeight = 64.0;

  static Color get unselectedForeground =>
      BrandColors.forest.withValues(alpha: unselectedOpacity);

  static Color get selectedPill => BrandColors.creamPill;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _bar = BottomBarExtensionController();

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    final destinations = [
      (
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        label: strings.catalogTitle,
      ),
      (
        icon: Icons.flag_outlined,
        selectedIcon: Icons.flag,
        label: strings.navLastChallenge,
      ),
      (
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        label: strings.navMap,
      ),
      (
        icon: Icons.person_outline,
        selectedIcon: Icons.person_outline,
        label: strings.navProfile,
      ),
    ];

    return BottomBarExtension(
      controller: _bar,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rail = Breakpoints.usesNavigationRail(constraints.maxWidth);
          if (rail) {
            final compactRail =
                Breakpoints.ofWidth(constraints.maxWidth) == WindowClass.medium;
            return Scaffold(
              body: Row(
                children: [
                  _NavRail(
                    destinations: destinations,
                    selectedIndex: widget.navigationShell.currentIndex,
                    compact: compactRail,
                    onSelected: (index) {
                      widget.navigationShell.goBranch(
                        index,
                        initialLocation:
                            index == widget.navigationShell.currentIndex,
                      );
                    },
                  ),
                  Expanded(child: widget.navigationShell),
                ],
              ),
            );
          }
          return Scaffold(
            extendBody: true,
            body: widget.navigationShell,
            bottomNavigationBar: _ShellBottomSlot(
              controller: _bar,
              destinations: destinations,
              navigationShell: widget.navigationShell,
            ),
          );
        },
      ),
    );
  }
}

class _ShellBottomSlot extends StatelessWidget {
  const _ShellBottomSlot({
    required this.controller,
    required this.destinations,
    required this.navigationShell,
  });

  final BottomBarExtensionController controller;
  final List<({IconData icon, IconData selectedIcon, String label})>
  destinations;
  final StatefulNavigationShell navigationShell;

  bool _onDetail(String path) =>
      path.contains('/challenge/') || path == '/last';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, controller.visible]),
      builder: (context, _) {
        final path = GoRouter.of(context).state.uri.path;
        final match = controller.owner == path && _onDetail(path);
        final panel = match ? controller.content : null;
        final shown = match && controller.visible.value && panel != null;
        return ShellBottomSurface(
          shown: shown,
          panel: panel,
          nav: SizedBox(
            key: const Key('app-bottom-nav'),
            height: AppShell.barHeight,
            child: _NavPillBar(
              destinations: destinations,
              selectedIndex: navigationShell.currentIndex,
              onSelected: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.destinations,
    required this.selectedIndex,
    required this.compact,
    required this.onSelected,
  });

  final List<({IconData icon, IconData selectedIcon, String label})>
  destinations;
  final int selectedIndex;
  final bool compact;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      key: const Key('app-nav-rail'),
      backgroundColor: BrandColors.shellFill,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: compact
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      minWidth: AppTheme.minTap + 16,
      minExtendedWidth: 180,
      indicatorColor: BrandColors.creamPill,
      selectedIconTheme: const IconThemeData(color: BrandColors.cream),
      unselectedIconTheme: IconThemeData(color: AppShell.unselectedForeground),
      selectedLabelTextStyle: const TextStyle(
        color: BrandColors.cream,
        fontSize: AppTheme.labelSize,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: AppShell.unselectedForeground,
        fontSize: AppTheme.labelSize,
        fontWeight: FontWeight.w500,
      ),
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
            padding: const EdgeInsets.symmetric(vertical: 4),
          ),
      ],
    );
  }
}

/// Icon band, gap, and label band. The sliding pill shares [iconTop] so it
/// stays behind the glyph while it travels.
const _navIconBand = 32.0;
const _navLabelGap = 4.0;
const _navLabelBand = 18.0;
const _navIconTop =
    (AppShell.barHeight - _navIconBand - _navLabelGap - _navLabelBand) / 2;

class _NavPillBar extends StatelessWidget {
  const _NavPillBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<({IconData icon, IconData selectedIcon, String label})>
  destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduced = motionReduced(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = destinations.length;
        final slot = count == 0 ? 0.0 : constraints.maxWidth / count;
        final left =
            selectedIndex * slot + (slot - AppShell.indicatorSize.width) / 2;
        return Stack(
          children: [
            AnimatedPositioned(
              key: const Key('nav-pill-motion'),
              duration: reduced ? Duration.zero : MotionTokens.tab,
              curve: MotionTokens.tabCurve,
              left: left,
              top: _navIconTop,
              width: AppShell.indicatorSize.width,
              height: AppShell.indicatorSize.height,
              child: const _NavIndicator(),
            ),
            Row(
              children: [
                for (var index = 0; index < count; index++)
                  Expanded(
                    child: _SageNavDestination(
                      icon: destinations[index].icon,
                      selectedIcon: destinations[index].selectedIcon,
                      label: destinations[index].label,
                      selected: selectedIndex == index,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NavIndicator extends StatelessWidget {
  const _NavIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sage-nav-indicator'),
      decoration: BoxDecoration(
        color: AppShell.selectedPill,
        borderRadius: BorderRadius.circular(AppShell.indicatorRadius),
      ),
    );
  }
}

class _SageNavDestination extends StatefulWidget {
  const _SageNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SageNavDestination> createState() => _SageNavDestinationState();
}

class _SageNavDestinationState extends State<_SageNavDestination> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? BrandColors.cream
        : AppShell.unselectedForeground;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: Opacity(
          opacity: _pressed ? AppShell.pressedOpacity : 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: _navIconBand,
                child: Icon(
                  widget.selected ? widget.selectedIcon : widget.icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: _navLabelGap),
              SizedBox(
                height: _navLabelBand,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: AppTheme.labelSize,
                    height: 1,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
