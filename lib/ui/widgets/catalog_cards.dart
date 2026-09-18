import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/catalog_query.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.onTap,
    this.completed = false,
  });

  final Challenge challenge;
  final VoidCallback onTap;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = context.watch<LocaleController>().strings;
    final copy = challenge.copyFor(locale);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: challenge.coverImageUrl == null
                  ? Container(
                      color: BrandColors.beige,
                      child: Icon(
                        Icons.landscape,
                        size: 48,
                        color: scheme.onPrimaryContainer,
                      ),
                    )
                  : Image.network(
                      challenge.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: BrandColors.beige,
                        child: const Icon(Icons.landscape, size: 48),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(
                        label: challenge.accessMode == AccessMode.story
                            ? strings.storyChallenge
                            : strings.openChallenge,
                      ),
                      _Chip(
                        label: challenge.isPaid ? strings.paid : strings.free,
                        active: challenge.isPaid,
                      ),
                      if (completed)
                        _Chip(label: strings.completed, active: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (copy.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      copy.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PromoStripeCard extends StatelessWidget {
  const PromoStripeCard({super.key, required this.promo, required this.onTap});

  final PromoStripe promo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = context.watch<LocaleController>().strings;
    final copy = promo.copyFor(locale);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: promo.imageUrl == null
                  ? Container(
                      color: BrandColors.beige,
                      child: const Icon(
                        Icons.campaign,
                        size: 48,
                        color: BrandColors.forest,
                      ),
                    )
                  : Image.network(
                      promo.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: BrandColors.beige,
                        child: Icon(Icons.campaign, size: 48),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Chip(label: 'Promo', active: true),
                  const SizedBox(height: 8),
                  Text(
                    copy.title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if ((copy.subtitle ?? copy.description).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      copy.subtitle ?? copy.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: onTap,
                      child: Text(copy.ctaLabel ?? strings.promoFallbackCta),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogHeroCarousel extends StatefulWidget {
  const CatalogHeroCarousel({
    super.key,
    required this.challenges,
    required this.routeStats,
    required this.onOpen,
  });

  final List<Challenge> challenges;
  final Map<String, CatalogRouteStats> routeStats;
  final ValueChanged<Challenge> onOpen;

  @override
  State<CatalogHeroCarousel> createState() => _CatalogHeroCarouselState();
}

class _CatalogHeroCarouselState extends State<CatalogHeroCarousel> {
  late final PageController _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenges = widget.challenges;
    if (challenges.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('catalog-hero-carousel'),
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BrandColors.beige),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pages,
                    itemCount: challenges.length,
                    itemBuilder: (context, index) {
                      final challenge = challenges[index];
                      return _HeroSlide(
                        challenge: challenge,
                        stats: widget.routeStats[challenge.id],
                        onTap: () => widget.onOpen(challenge),
                      );
                    },
                  ),
                  if (challenges.length > 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: BrandColors.cream,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            key: const Key('catalog-hero-next'),
                            tooltip: MaterialLocalizations.of(context)
                                .nextPageTooltip,
                            onPressed: () {
                              final current = _pages.page?.round() ?? 0;
                              final next = (current + 1) % challenges.length;
                              _pages.animateToPage(
                                next,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOut,
                              );
                            },
                            icon: const Icon(
                              Icons.chevron_right,
                              color: BrandColors.forest,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({
    required this.challenge,
    required this.stats,
    required this.onTap,
  });

  final Challenge challenge;
  final CatalogRouteStats? stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = context.watch<LocaleController>().strings;
    final title = challenge.copyFor(locale).title;
    return KeyedSubtree(
      key: Key('catalog-hero-${challenge.id}'),
      child: Material(
        color: BrandColors.beige,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CatalogCoverImage(url: challenge.coverImageUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x99000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 56,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BrandColors.cream,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (stats != null && stats!.hasMeta) ...[
                      const SizedBox(height: 4),
                      CatalogRouteMeta(
                        stats: stats!,
                        strings: strings,
                        color: BrandColors.cream,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogFeaturedSection extends StatelessWidget {
  const CatalogFeaturedSection({
    super.key,
    required this.challenges,
    required this.routeStats,
    required this.onOpen,
  });

  final List<Challenge> challenges;
  final Map<String, CatalogRouteStats> routeStats;
  final ValueChanged<Challenge> onOpen;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    if (challenges.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('catalog-featured'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.catalogFeatured,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: BrandColors.forest,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            primary: false,
            itemCount: challenges.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final challenge = challenges[index];
              return CatalogFeaturedCard(
                challenge: challenge,
                stats: routeStats[challenge.id],
                onTap: () => onOpen(challenge),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CatalogFeaturedCard extends StatelessWidget {
  const CatalogFeaturedCard({
    super.key,
    required this.challenge,
    required this.onTap,
    this.stats,
  });

  final Challenge challenge;
  final CatalogRouteStats? stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = context.watch<LocaleController>().strings;
    final title = challenge.copyFor(locale).title;
    return SizedBox(
      key: Key('catalog-featured-${challenge.id}'),
      width: 196,
      child: Material(
        color: BrandColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BrandColors.beige),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CatalogCoverImage(url: challenge.coverImageUrl),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BrandColors.forest,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.2,
                        ),
                      ),
                      if (stats != null && stats!.hasMeta) ...[
                        const SizedBox(height: 4),
                        CatalogRouteMeta(
                          stats: stats!,
                          strings: strings,
                          color: BrandColors.bark,
                        ),
                      ],
                    ],
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

class CatalogCoverImage extends StatelessWidget {
  const CatalogCoverImage({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const ColoredBox(
        color: BrandColors.beige,
        child: Icon(Icons.landscape, size: 48, color: BrandColors.forest),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: BrandColors.beige,
        child: Icon(Icons.landscape, size: 48, color: BrandColors.forest),
      ),
    );
  }
}

class CatalogRouteMeta extends StatelessWidget {
  const CatalogRouteMeta({
    super.key,
    required this.stats,
    required this.strings,
    required this.color,
  });

  final CatalogRouteStats stats;
  final AppStrings strings;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (stats.estimatedDuration != null)
        strings.formatCatalogHours(stats.estimatedDuration!),
      if (stats.distanceKm != null) strings.formatDistanceKm(stats.distanceKm!),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? BrandColors.forest : BrandColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? BrandColors.forest : BrandColors.beige,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: active ? BrandColors.onPrimary : BrandColors.bark,
        ),
      ),
    );
  }
}
