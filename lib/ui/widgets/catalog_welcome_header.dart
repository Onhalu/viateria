import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../l10n/locale_controller.dart';
import '../../theme/brand_colors.dart';

class CatalogWelcomeHeader extends StatelessWidget {
  const CatalogWelcomeHeader({super.key});

  static const avatarSize = 40.0;
  static const horizontalPadding = 16.0;
  static const verticalPadding = 12.0;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    final user = context.read<AppServices>().auth.currentUser;
    final rawName = user?.displayName?.trim();
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : strings.welcomeNameFallback;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return ColoredBox(
      key: const Key('catalog-welcome-header'),
      color: BrandColors.sage,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
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
                      style: TextStyle(
                        color: BrandColors.cream.withValues(alpha: 0.85),
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
              _RoundHeaderButton(
                key: const Key('catalog-welcome-map'),
                icon: Icons.map_outlined,
                tooltip: strings.navMap,
                onPressed: () => GoRouter.maybeOf(context)?.go('/map'),
              ),
              const SizedBox(width: 4),
              _RoundHeaderButton(
                key: const Key('catalog-welcome-profile'),
                icon: Icons.person_outline,
                tooltip: strings.navProfile,
                onPressed: () => GoRouter.maybeOf(context)?.go('/profile'),
              ),
            ],
          ),
        ),
      ),
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
      style: IconButton.styleFrom(
        foregroundColor: BrandColors.cream,
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, size: 22, color: BrandColors.cream),
    );
  }
}
