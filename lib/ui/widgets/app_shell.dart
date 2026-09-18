import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../theme/brand_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const indicatorSize = Size(40, 32);
  static const indicatorRadius = 16.0;
  static const pressedOpacity = 0.85;
  static const unselectedOpacity = 0.75;
  static const barHeight = 64.0;

  static Color get unselectedForeground =>
      BrandColors.forest.withValues(alpha: unselectedOpacity);

  static Color get selectedPill => BrandColors.cream.withValues(alpha: 0.22);

  static Color get hairline => BrandColors.forest.withValues(alpha: 0.12);

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
        selectedIcon: Icons.person,
        label: strings.navProfile,
      ),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Material(
        key: const Key('app-bottom-nav-shell'),
        color: BrandColors.sage,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredBox(
              color: hairline,
              child: const SizedBox(height: 1, width: double.infinity),
            ),
            SafeArea(
              top: false,
              child: SizedBox(
                key: const Key('app-bottom-nav'),
                height: barHeight,
                child: Row(
                  children: [
                    for (var index = 0; index < destinations.length; index++)
                      Expanded(
                        child: _SageNavDestination(
                          icon: destinations[index].icon,
                          selectedIcon: destinations[index].selectedIcon,
                          label: destinations[index].label,
                          selected: navigationShell.currentIndex == index,
                          onTap: () {
                            navigationShell.goBranch(
                              index,
                              initialLocation:
                                  index == navigationShell.currentIndex,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
              Container(
                key: widget.selected ? const Key('sage-nav-indicator') : null,
                width: AppShell.indicatorSize.width,
                height: AppShell.indicatorSize.height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? AppShell.selectedPill
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppShell.indicatorRadius),
                ),
                child: Icon(
                  widget.selected ? widget.selectedIcon : widget.icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
