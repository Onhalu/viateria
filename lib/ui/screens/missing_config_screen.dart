import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../theme/brand_assets.dart';

class MissingConfigScreen extends StatelessWidget {
  const MissingConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLockup(width: BrandAssets.splashLockupWidth),
              const SizedBox(height: 24),
              Text(
                strings.missingConfig,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
