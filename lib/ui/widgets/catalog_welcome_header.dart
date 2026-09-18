import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../domain/catalog_query.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../theme/brand_colors.dart';
import 'app_shell.dart';
import 'catalog_filters.dart';

class CatalogWelcomeHeader extends StatelessWidget {
  const CatalogWelcomeHeader({
    super.key,
    required this.search,
    required this.filter,
    required this.onFilterChanged,
  });

  final TextEditingController search;
  final CatalogFilter filter;
  final ValueChanged<CatalogFilter> onFilterChanged;

  static const avatarSize = 40.0;
  static const actionSize = 40.0;
  static const horizontalInset = AppShell.horizontalInset;
  static const topGap = AppShell.topInset;
  static const barRadius = AppShell.barRadius;
  static const innerHorizontalPadding = 16.0;
  static const innerPadding = EdgeInsets.fromLTRB(
    innerHorizontalPadding,
    10,
    innerHorizontalPadding,
    12,
  );

  static ButtonStyle get actionStyle => IconButton.styleFrom(
    foregroundColor: BrandColors.cream,
    backgroundColor: BrandColors.creamPill,
    minimumSize: const Size(actionSize, actionSize),
    maximumSize: const Size(actionSize, actionSize),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: const CircleBorder(),
  );

  @override
  Widget build(BuildContext context) {
    final localeController = context.watch<LocaleController>();
    final strings = localeController.strings;
    final user = context.read<AppServices>().auth.currentUser;
    final rawName = user?.displayName?.trim();
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : strings.welcomeNameFallback;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          horizontalInset,
          topGap,
          horizontalInset,
          topGap,
        ),
        child: Material(
          key: const Key('catalog-welcome-header'),
          color: BrandColors.shellFill,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(barRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: innerPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      key: const Key('catalog-welcome-avatar'),
                      width: avatarSize,
                      height: avatarSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: BrandColors.cream.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: BrandColors.cream,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            strings.welcomeBack,
                            key: const Key('catalog-welcome-greeting'),
                            style: const TextStyle(
                              color: BrandColors.cream,
                              fontSize: 13,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            name,
                            key: const Key('catalog-welcome-name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BrandColors.cream,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _LocaleHeaderButton(controller: localeController),
                    const SizedBox(width: 4),
                    _RoundHeaderButton(
                      key: const Key('catalog-welcome-profile'),
                      icon: Icons.person_outline,
                      tooltip: strings.navProfile,
                      onPressed: () =>
                          GoRouter.maybeOf(context)?.go('/profile'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CatalogSearchField(
                  controller: search,
                  hintText: strings.catalogSearchHint,
                  onChanged: (value) =>
                      onFilterChanged(filter.copyWith(query: value)),
                ),
                const SizedBox(height: 8),
                CatalogFilterChipRow(
                  filter: filter,
                  strings: strings,
                  onChanged: onFilterChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocaleHeaderButton extends StatelessWidget {
  const _LocaleHeaderButton({required this.controller});

  final LocaleController controller;

  Future<void> _select(BuildContext context, String value) async {
    final auth = context.read<AppServices>().auth;
    await controller.setLocale(value);
    if (auth.currentUser != null) {
      await auth.updateLocale(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = controller.locale;
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        for (final locale in AppStrings.supported)
          MenuItemButton(
            key: Key('catalog-welcome-locale-$locale'),
            onPressed: () => _select(context, locale),
            child: Text(
              locale.toUpperCase(),
              style: TextStyle(
                fontWeight: locale == current
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
      ],
      builder: (context, menuController, child) {
        return SizedBox(
          key: const Key('catalog-welcome-locale'),
          width: CatalogWelcomeHeader.actionSize,
          height: CatalogWelcomeHeader.actionSize,
          child: IconButton(
            tooltip: controller.strings.language,
            onPressed: () {
              if (menuController.isOpen) {
                menuController.close();
              } else {
                menuController.open();
              }
            },
            style: CatalogWelcomeHeader.actionStyle,
            icon: Text(
              current.toUpperCase(),
              key: const Key('catalog-welcome-locale-label'),
              style: const TextStyle(
                color: BrandColors.cream,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: CatalogWelcomeHeader.actionStyle,
      icon: Icon(icon, size: 22, color: BrandColors.cream),
    );
  }
}
