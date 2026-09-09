import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeController = context.watch<LocaleController>();
    final strings = localeController.strings;
    final user = context.read<AppServices>().auth.currentUser;
    final name = user?.displayName?.trim();
    final email = user?.email?.trim();
    final identity = (name != null && name.isNotEmpty)
        ? name
        : (email != null && email.isNotEmpty)
        ? email
        : strings.navProfile;
    final initial = identity.isNotEmpty ? identity[0].toUpperCase() : '?';

    return SafeArea(
      bottom: false,
      child: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: CircleAvatar(
              radius: 36,
              child: Text(
                initial,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            identity,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (email != null &&
              email.isNotEmpty &&
              email != identity) ...[
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
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
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(strings.navLastChallenge),
            onTap: () => context.push('/last'),
          ),
          ListTile(
            leading: const Icon(Icons.explore_outlined),
            title: Text(strings.catalogTitle),
            onTap: () => context.go('/'),
          ),
          const SizedBox(height: 8),
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
