import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/map_strings.dart';
import '../../../core/theme/map_colors.dart';
import '../../../l10n/locale_controller.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    this.icon = Icons.hourglass_empty,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = MapStrings(locale);
    return ColoredBox(
      color: const Color(0xFFF7F3E9),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: MapColors.accent),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.comingSoon,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
