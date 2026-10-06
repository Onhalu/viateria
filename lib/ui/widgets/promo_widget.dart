import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/promo.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';

/// Catalog promo slot between Featured and the country flags.
///
/// One active stripe is a single forest card. Two or more snap in a
/// horizontal carousel with a 24px peek. None, expired, or out of audience
/// collapses to zero height — no section title and no skeleton.
class PromoWidget extends StatelessWidget {
  const PromoWidget({
    super.key,
    required this.promos,
    required this.onOpen,
    this.now,
  });

  final List<PromoStripe> promos;
  final ValueChanged<PromoStripe> onOpen;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final moment = now ?? DateTime.now();
    final active = visiblePromos(promos, moment);
    if (active.isEmpty) return const SizedBox.shrink();
    if (active.length == 1) {
      return PromoStrip(
        promo: active.first,
        now: moment,
        onOpen: () => onOpen(active.first),
      );
    }
    return _PromoCarousel(promos: active, onOpen: onOpen, now: moment);
  }
}

class PromoStrip extends StatelessWidget {
  const PromoStrip({
    super.key,
    required this.promo,
    required this.onOpen,
    this.now,
  });

  final PromoStripe promo;
  final VoidCallback onOpen;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>();
    final strings = locale.strings;
    final copy = promo.copyFor(locale.locale);
    final subtitle = (copy.subtitle ?? copy.description).trim();
    final countdown = promoValidityLabel(
      now: now ?? DateTime.now(),
      endsAt: promo.endsAt,
      strings: strings,
    );
    final enabled = promo.hasTarget;
    final tag = promo.kind == PromoKind.discount
        ? strings.promoDiscountTag
        : strings.promoTag;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PromoTag(id: promo.id, label: tag),
            if (countdown != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _PromoCountdown(id: promo.id, label: countdown),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          copy.title,
          key: Key('promo-title-${promo.id}'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            color: BrandColors.cream,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            key: Key('promo-subtitle-${promo.id}'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: BrandColors.cream.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: Key('promo-cta-${promo.id}'),
            onPressed: enabled ? onOpen : null,
            style: FilledButton.styleFrom(
              backgroundColor: BrandColors.cream,
              foregroundColor: BrandColors.forest,
              disabledBackgroundColor: BrandColors.cream.withValues(alpha: 0.4),
              disabledForegroundColor: BrandColors.forest.withValues(
                alpha: 0.4,
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(copy.ctaLabel ?? strings.promoFallbackCta),
          ),
        ),
      ],
    );

    return Material(
      key: Key('promo-surface-${promo.id}'),
      color: BrandColors.forest,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('promo-strip-${promo.id}'),
        onTap: enabled ? onOpen : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: promo.hasCover
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 36,
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            promo.imageUrl!,
                            key: Key('promo-cover-${promo.id}'),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: BrandColors.sage,
                              child: Icon(
                                Icons.landscape,
                                color: BrandColors.cream,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 64, child: body),
                  ],
                )
              : body,
        ),
      ),
    );
  }
}

class _PromoTag extends StatelessWidget {
  const _PromoTag({required this.id, required this.label});

  final String id;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('promo-tag-$id'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BrandColors.sage,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: BrandColors.cream,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

class _PromoCountdown extends StatelessWidget {
  const _PromoCountdown({required this.id, required this.label});

  final String id;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('promo-countdown-$id'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.schedule, size: 18, color: BrandColors.sage),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: BrandColors.cream,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel({
    required this.promos,
    required this.onOpen,
    required this.now,
  });

  final List<PromoStripe> promos;
  final ValueChanged<PromoStripe> onOpen;
  final DateTime now;

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = promoCarouselItemWidth(width);
        final fraction = width <= 0 ? 1.0 : (itemWidth / width).clamp(0.5, 1.0);
        return Column(
          key: const Key('promo-carousel'),
          children: [
            SizedBox(
              height: 248,
              child: _PromoPager(
                key: ValueKey(fraction),
                viewportFraction: fraction,
                promos: widget.promos,
                now: widget.now,
                onOpen: widget.onOpen,
                onPage: (page) => setState(() => _index = page),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              key: const Key('promo-dots'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.promos.length; i++)
                  Container(
                    key: Key('promo-dot-$i'),
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
        );
      },
    );
  }
}

class _PromoPager extends StatefulWidget {
  const _PromoPager({
    super.key,
    required this.viewportFraction,
    required this.promos,
    required this.now,
    required this.onOpen,
    required this.onPage,
  });

  final double viewportFraction;
  final List<PromoStripe> promos;
  final DateTime now;
  final ValueChanged<PromoStripe> onOpen;
  final ValueChanged<int> onPage;

  @override
  State<_PromoPager> createState() => _PromoPagerState();
}

class _PromoPagerState extends State<_PromoPager> {
  late final PageController _pages = PageController(
    viewportFraction: widget.viewportFraction,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      key: const Key('promo-page-view'),
      controller: _pages,
      padEnds: false,
      itemCount: widget.promos.length,
      onPageChanged: widget.onPage,
      itemBuilder: (context, index) {
        final promo = widget.promos[index];
        return Padding(
          padding: EdgeInsets.only(
            right: index == widget.promos.length - 1 ? 0 : 12,
          ),
          child: PromoStrip(
            promo: promo,
            now: widget.now,
            onOpen: () => widget.onOpen(promo),
          ),
        );
      },
    );
  }
}
