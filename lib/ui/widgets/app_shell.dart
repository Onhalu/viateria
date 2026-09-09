import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/map_strings.dart';
import '../../core/theme/map_colors.dart';
import '../../l10n/locale_controller.dart';
import 'package:provider/provider.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const horizontalInset = 0.0;
  static const bottomInset = 0.0;
  static const topInset = 0.0;
  static const barRadius = 0.0;
  static const barHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = MapStrings(locale);
    final items = <_NavItem>[
      _NavItem(Icons.home_outlined, Icons.home, strings.navHome),
      _NavItem(Icons.map_outlined, Icons.map, strings.navMap),
      _NavItem(
        Icons.format_list_bulleted,
        Icons.format_list_bulleted,
        strings.navList,
      ),
      _NavItem(
        Icons.calendar_today_outlined,
        Icons.calendar_today,
        strings.navPlanner,
      ),
      _NavItem(Icons.bookmark_outline, Icons.bookmark, strings.navSaved),
      _NavItem(Icons.person_outline, Icons.person, strings.navProfile),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: navigationShell,
      bottomNavigationBar: Material(
        key: const Key('app-bottom-nav-shell'),
        color: MapColors.surfaceFill,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: barHeight,
            child: Row(
              key: const Key('app-bottom-nav'),
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      selected: navigationShell.currentIndex == i,
                      onTap: () {
                        navigationShell.goBranch(
                          i,
                          initialLocation: i == navigationShell.currentIndex,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MapColors.accent : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: AppShell.barHeight,
          child: Icon(
            selected ? item.selectedIcon : item.icon,
            color: color,
            size: 26,
          ),
        ),
      ),
    );
  }
}
