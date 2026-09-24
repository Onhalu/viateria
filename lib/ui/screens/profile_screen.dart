import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../domain/profile_stats.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../map/place.dart';
import '../../map/place_catalog.dart';
import '../../models/models.dart';
import '../../theme/brand_assets.dart';
import '../../theme/brand_colors.dart';
import '../navigation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.places});

  /// Test seam. Production uses [AppServices.places].
  final PlaceCatalog? places;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  var _started = false;
  List<Place> _places = const [];
  List<Challenge> _completed = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    final catalog = widget.places ?? services.places;
    final places = await _orDefault(catalog.fetchAll(), const <Place>[]);
    final completed = await _orDefault(
      services.progress.fetchCompleted(),
      const <ChallengeProgress>[],
    );
    final published = await _orDefault(
      services.catalog.fetchPublishedChallenges(),
      const <Challenge>[],
    );
    if (!mounted) return;
    setState(() {
      _places = places;
      _completed = completedChallengesForProfile(
        published: published,
        completedProgress: completed,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final localeController = context.watch<LocaleController>();
    final strings = localeController.strings;
    final services = context.read<AppServices>();
    final user = services.auth.currentUser;
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
      child: Material(
        color: BrandColors.cream,
        child: ListView(
          children: [
            const SizedBox(height: 24),
            const Center(child: BrandMark(size: 48)),
            const SizedBox(height: 16),
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
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (email != null && email.isNotEmpty && email != identity) ...[
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            ListenableBuilder(
              listenable: services.verifiedPlaces,
              builder: (context, _) {
                return _ProfileStatsBody(
                  strings: strings,
                  locale: localeController.locale,
                  counts: visitedPlaceCountsByCategory(
                    places: _places,
                    verifiedIds: services.verifiedPlaces.ids,
                  ),
                  completed: _completed,
                );
              },
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }
}

Future<T> _orDefault<T>(Future<T> future, T fallback) async {
  try {
    return await future;
  } catch (_) {
    return fallback;
  }
}

class _ProfileStatsBody extends StatelessWidget {
  const _ProfileStatsBody({
    required this.strings,
    required this.locale,
    required this.counts,
    required this.completed,
  });

  final AppStrings strings;
  final String locale;
  final List<CategoryVisitCount> counts;
  final List<Challenge> completed;

  static const _gridGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall
        ?.copyWith(fontWeight: FontWeight.w700, color: BrandColors.forest);
    final rows = [counts.take(2).toList(), counts.skip(2).take(2).toList()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: KeyedSubtree(
            key: const Key('profile-visited-places'),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: _gridGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var j = 0; j < rows[i].length; j++) ...[
                        if (j > 0) const SizedBox(width: _gridGap),
                        Expanded(
                          child: _CategoryVisitCard(
                            strings: strings,
                            count: rows[i][j],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            strings.completedChallenges,
            key: const Key('profile-completed-title'),
            style: titleStyle,
          ),
        ),
        KeyedSubtree(
          key: const Key('profile-completed-challenges'),
          child: completed.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    strings.completedChallengesEmpty,
                    key: const Key('profile-completed-empty'),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: BrandColors.bark),
                  ),
                )
              : Column(
                  children: [
                    for (final challenge in completed)
                      ListTile(
                        key: Key('profile-completed-${challenge.id}'),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        title: Text(
                          challenge.copyFor(locale).title,
                          style: const TextStyle(color: BrandColors.forest),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: BrandColors.forest,
                        ),
                        onTap: () => openChallenge(
                          context,
                          challenge.id,
                          fromProfile: true,
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CategoryVisitCard extends StatelessWidget {
  const _CategoryVisitCard({required this.strings, required this.count});

  final AppStrings strings;
  final CategoryVisitCount count;

  static const _iconSize = 22.0;
  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: Key('profile-visited-card-${count.category.name}'),
      decoration: BoxDecoration(
        color: BrandColors.cream,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: BrandColors.beige),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                BrandColors.forest,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                'assets/map/icons/${count.category.iconName}@2x.png',
                width: _iconSize,
                height: _iconSize,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.t(count.category.profileL10nKey),
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                color: BrandColors.bark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count.fraction,
              key: Key('profile-visited-${count.category.name}'),
              style: const TextStyle(
                fontSize: 20,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: BrandColors.forest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
