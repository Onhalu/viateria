import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/catalog_query.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';
import '../layout/breakpoints.dart';
import 'app_network_image.dart';

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
              aspectRatio: catalogCardAspectRatio,
              child: challenge.coverImageUrl == null
                  ? Container(
                      color: BrandColors.beige,
                      child: Icon(
                        Icons.landscape,
                        size: 48,
                        color: scheme.onPrimaryContainer,
                      ),
                    )
                  : CatalogCoverImage(
                      url: challenge.coverImageUrl,
                      card: true,
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
                    if (_hasCatalogMeta(
                      stats,
                      challenge.difficulty,
                      challenge.length,
                    )) ...[
                      const SizedBox(height: 4),
                      CatalogChallengeMeta(
                        stats: stats,
                        lengthBand: challenge.length == null
                            ? null
                            : catalogLengthBandForChallenge(challenge, null),
                        difficulty: challenge.difficulty,
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

class CatalogFeaturedSection extends StatefulWidget {
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
  State<CatalogFeaturedSection> createState() => _CatalogFeaturedSectionState();
}

class _CatalogFeaturedSectionState extends State<CatalogFeaturedSection> {
  final _scroll = ScrollController();
  var _index = 0;
  var _stride = _cardWidth + _gap;

  static const _cardWidth = 196.0;
  static const _gap = 16.0;
  static const _textBlock = 148.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || widget.challenges.isEmpty) return;
    final next = (_scroll.offset / _stride).round().clamp(
      0,
      widget.challenges.length - 1,
    );
    if (next != _index) setState(() => _index = next);
  }

  Future<void> _step(int delta) async {
    if (!_scroll.hasClients || widget.challenges.isEmpty) return;
    final next = (_index + delta).clamp(0, widget.challenges.length - 1);
    await _scroll.animateTo(
      next * _stride,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    if (widget.challenges.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.compactMax;
        final last = _index >= widget.challenges.length - 1;
        final cardWidth = wide
            ? _cardWidth
            : (constraints.maxWidth - 24).clamp(160.0, 420.0);
        final stride = cardWidth + _gap;
        _stride = stride;
        final listHeight = cardWidth / catalogCardAspectRatio + _textBlock;
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
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _step(-1),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _step(1),
              },
              child: Focus(
                child: Stack(
                  children: [
                    SizedBox(
                      height: listHeight,
                      child: ScrollConfiguration(
                        behavior: const MaterialScrollBehavior().copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: ListView.separated(
                          controller: _scroll,
                          scrollDirection: Axis.horizontal,
                          primary: false,
                          physics: _CardSnapPhysics(itemExtent: stride),
                          itemCount: widget.challenges.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: _gap),
                          itemBuilder: (context, index) {
                            final challenge = widget.challenges[index];
                            return CatalogFeaturedCard(
                              challenge: challenge,
                              stats: widget.routeStats[challenge.id],
                              onTap: () => widget.onOpen(challenge),
                              width: cardWidth,
                            );
                          },
                        ),
                      ),
                    ),
                    if (wide) ...[
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _FeaturedArrow(
                            key: const Key('catalog-featured-prev'),
                            tooltip: strings.featuredPrevious,
                            icon: Icons.chevron_left,
                            visible: _index > 0,
                            onPressed: () => _step(-1),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _FeaturedArrow(
                            key: const Key('catalog-featured-next'),
                            tooltip: strings.featuredNext,
                            icon: Icons.chevron_right,
                            visible: !last,
                            onPressed: () => _step(1),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!wide) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.challenges.length; i++)
                    Container(
                      key: Key('catalog-featured-dot-$i'),
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _index
                            ? BrandColors.forest
                            : BrandColors.beige,
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FeaturedArrow extends StatelessWidget {
  const _FeaturedArrow({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.visible,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            label: tooltip,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: BrandColors.cream.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2635483C),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onPressed,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(icon, color: BrandColors.forest, size: 24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardSnapPhysics extends ScrollPhysics {
  const _CardSnapPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  _CardSnapPhysics applyTo(ScrollPhysics? ancestor) {
    return _CardSnapPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  double _target(ScrollMetrics position) {
    if (itemExtent <= 0) return position.pixels;
    final index = (position.pixels / itemExtent).round();
    return (index * itemExtent).clamp(0.0, position.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);
    final target = _target(position);
    if (velocity.abs() < tolerance.velocity &&
        (position.pixels - target).abs() < tolerance.distance) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}

/// Challenges under the country flags. No section title.
///
/// [challenges] is already filtered: every catalog row when no flag is
/// selected, and only the selected countries once a flag is on.
class CatalogCountryResults extends StatelessWidget {
  const CatalogCountryResults({
    super.key,
    required this.challenges,
    required this.routeStats,
    required this.onOpen,
  });

  final List<Challenge> challenges;
  final Map<String, CatalogRouteStats> routeStats;
  final ValueChanged<Challenge> onOpen;

  /// Virtualized result grid. The zero-height marker keeps a render box for
  /// layout tests that measure the section's top edge.
  List<Widget> slivers({required int columns, required double width}) {
    if (challenges.isEmpty) return const [];
    final cell = columns <= 1 ? width : (width - 16 * (columns - 1)) / columns;
    // 4:3 cover plus title, badge, and a two-line excerpt.
    final extent = cell / catalogCardAspectRatio + 148;
    return [
      const SliverToBoxAdapter(
        child: SizedBox(key: Key('catalog-country-results'), height: 1),
      ),
      SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: extent,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final challenge = challenges[index];
          return CatalogFeaturedCard(
            challenge: challenge,
            stats: routeStats[challenge.id],
            onTap: () => onOpen(challenge),
            cardKeyPrefix: 'catalog-country',
            expand: true,
          );
        }, childCount: challenges.length),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class CatalogFeaturedCard extends StatelessWidget {
  const CatalogFeaturedCard({
    super.key,
    required this.challenge,
    required this.onTap,
    this.stats,
    this.cardKeyPrefix = 'catalog-featured',
    this.expand = false,
    this.width = 196,
  });

  final Challenge challenge;
  final CatalogRouteStats? stats;
  final VoidCallback onTap;
  final String cardKeyPrefix;
  final bool expand;
  final double width;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = context.watch<LocaleController>().strings;
    final copy = challenge.copyFor(locale);
    final title = copy.title;
    final excerpt = copy.description.trim();
    final hasMeta = _hasCatalogMeta(
      stats,
      challenge.difficulty,
      challenge.length,
    );
    return SizedBox(
      key: Key('$cardKeyPrefix-${challenge.id}'),
      width: expand ? null : width,
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
                aspectRatio: catalogCardAspectRatio,
                child: CatalogCoverImage(
                  url: challenge.coverImageUrl,
                  card: true,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                      if (hasMeta) ...[
                        const SizedBox(height: 8),
                        CatalogChallengeMeta(
                          stats: stats,
                          lengthBand: challenge.length == null
                              ? null
                              : catalogLengthBandForChallenge(challenge, null),
                          difficulty: challenge.difficulty,
                          strings: strings,
                          color: BrandColors.bark,
                        ),
                      ],
                      if (excerpt.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          excerpt,
                          key: Key('$cardKeyPrefix-excerpt-${challenge.id}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BrandColors.bark,
                            fontSize: 14,
                            height: 1.2,
                          ),
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
  const CatalogCoverImage({super.key, required this.url, this.card = false});

  final String? url;

  /// Card thumbnails pick cover or contain from the photo's own ratio.
  /// The home carousel stays a full-bleed cover.
  final bool card;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const ColoredBox(
        color: BrandColors.beige,
        child: Icon(Icons.landscape, size: 48, color: BrandColors.forest),
      );
    }
    if (!card) return AppNetworkImage(url: url);
    return LayoutBuilder(
      builder: (context, constraints) {
        final logical = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        final cache = logical == null
            ? null
            : cachePixelsFor(logical, MediaQuery.devicePixelRatioOf(context));
        return _CardCover(provider: _cardProvider(url!, cache));
      },
    );
  }
}

ImageProvider _cardProvider(String url, int? cacheWidth) {
  const asset = 'asset://';
  final ImageProvider image = url.startsWith(asset)
      ? AssetImage(url.substring(asset.length))
      : NetworkImage(supabaseRenderUrl(url, cacheWidth));
  if (cacheWidth == null) return image;
  return ResizeImage(image, width: cacheWidth);
}

/// Beige field. Photos near 4:3 crop from the center. Other ratios are
/// shown whole, with no blur and no shadow.
class _CardCover extends StatefulWidget {
  const _CardCover({required this.provider});

  final ImageProvider provider;

  @override
  State<_CardCover> createState() => _CardCoverState();
}

class _CardCoverState extends State<_CardCover> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _source;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
  }

  @override
  void didUpdateWidget(_CardCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      _source = null;
      _listen();
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _listen() {
    _stop();
    final stream = widget.provider.resolve(
      createLocalImageConfiguration(context),
    );
    var sync = true;
    _listener = ImageStreamListener((info, _) {
      final next = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (sync) {
        _source = next;
        return;
      }
      if (!mounted || next == _source) return;
      setState(() => _source = next);
    }, onError: (_, _) {});
    _stream = stream;
    stream.addListener(_listener!);
    sync = false;
  }

  void _stop() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final aspect = source == null || source.height == 0
        ? null
        : source.width / source.height;
    final crop = aspect != null && catalogCoverShouldCrop(aspect);
    return ColoredBox(
      color: BrandColors.beige,
      child: Image(
        image: widget.provider,
        fit: crop ? BoxFit.cover : BoxFit.contain,
        alignment: Alignment.center,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const AppImagePlaceholder(),
      ),
    );
  }
}

class CatalogChallengeMeta extends StatelessWidget {
  const CatalogChallengeMeta({
    super.key,
    required this.strings,
    required this.color,
    this.stats,
    this.lengthBand,
    this.difficulty,
  });

  final CatalogRouteStats? stats;

  /// CMS length. When null, [stats] hike-time band is used.
  final CatalogLengthBand? lengthBand;
  final CatalogDifficulty? difficulty;
  final AppStrings strings;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final band = lengthBand ?? stats?.lengthBand;
    final parts = <String>[
      if (band != null)
        switch (band) {
          CatalogLengthBand.short => strings.catalogLengthShort,
          CatalogLengthBand.medium => strings.catalogLengthMedium,
          CatalogLengthBand.long => strings.catalogLengthLong,
        },
      if (difficulty != null)
        switch (difficulty!) {
          CatalogDifficulty.easy => strings.catalogDifficultyEasy,
          CatalogDifficulty.normal => strings.catalogDifficultyNormal,
          CatalogDifficulty.hard => strings.catalogDifficultyHard,
        },
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
    );
  }
}

bool _hasCatalogMeta(
  CatalogRouteStats? stats,
  CatalogDifficulty? difficulty,
  ChallengeLength? length,
) {
  return length != null || stats?.lengthBand != null || difficulty != null;
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
