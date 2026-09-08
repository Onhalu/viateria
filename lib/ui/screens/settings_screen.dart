import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeController = context.watch<LocaleController>();
    final strings = localeController.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        children: [
          ListTile(title: Text(strings.language)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cs', label: Text('CS')),
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'de', label: Text('DE')),
              ],
              selected: {localeController.locale},
              onSelectionChanged: (value) async {
                final next = value.first;
                final auth = context.read<AppServices>().auth;
                await localeController.setLocale(next);
                if (auth.currentUser != null) {
                  await auth.updateLocale(next);
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () => context.read<AppServices>().auth.signOut(),
              child: Text(strings.signOut),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              AppStrings.supported.join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
