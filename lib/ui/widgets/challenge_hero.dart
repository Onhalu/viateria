import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../layout/breakpoints.dart';
import 'app_network_image.dart';

/// Full-bleed challenge cover. About 4:1, clamped, always [BoxFit.cover].
class ChallengeHero extends StatelessWidget {
  const ChallengeHero({
    super.key,
    required this.url,
    required this.title,
    this.onBack,
    this.backLabel = 'Zpět',
  });

  final String url;
  final String title;
  final VoidCallback? onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= Breakpoints.mediumMax;
        final height = challengeHeroHeight(width);
        final padding = MediaQuery.paddingOf(context);
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                url: url,
                logicalWidth: width,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.7,
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x0035483C), Color(0xCC35483C)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: wide ? 24 : 16,
                right: wide ? 24 : 16,
                bottom: wide ? 16 : 12,
                child: Text(
                  title,
                  key: const Key('challenge-title'),
                  maxLines: wide ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.cream,
                    fontSize: wide ? 28 : 24,
                    height: 1.15,
                  ),
                ),
              ),
              if (onBack != null)
                Positioned(
                  left: 12 + padding.left,
                  top: 12 + padding.top,
                  child: HeroBackButton(label: backLabel, onPressed: onBack),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 40 dp cream circle, 48 dp tap target, forest arrow.
class HeroBackButton extends StatelessWidget {
  const HeroBackButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Material(
              color: BrandColors.cream.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('challenge-back'),
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.arrow_back,
                    size: 24,
                    color: BrandColors.forest,
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

/// Pinned cover. Expanded height is [challengeHeroHeight]. Scrolling
/// collapses it into a forest bar with the same back circle, the place,
/// and one Playfair line of the challenge name.
class ChallengeCollapsingHero extends StatelessWidget {
  const ChallengeCollapsingHero({
    super.key,
    required this.url,
    required this.title,
    required this.location,
    this.onBack,
    this.backLabel = 'Zpět',
  });

  static const collapsedBody = 64.0;

  final String url;
  final String title;
  final String location;
  final VoidCallback? onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;
    final expanded = math.max(
      challengeHeroHeight(width),
      collapsedBody + top + 1,
    );
    return SliverPersistentHeader(
      pinned: true,
      delegate: _ChallengeHeroDelegate(
        url: url,
        title: title,
        location: location,
        onBack: onBack,
        backLabel: backLabel,
        top: top,
        maxExtent: expanded,
        minExtent: collapsedBody + top,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      ),
    );
  }
}

/// 1 when the cover is fully open, 0 when the pinned bar is fully collapsed.
/// Reduced motion snaps instead of sitting on a blended frame.
double challengeHeroExpandedFade({
  required double shrinkOffset,
  required double maxExtent,
  required double minExtent,
  required bool reduceMotion,
}) {
  final range = maxExtent - minExtent;
  final t = range <= 0 ? 0.0 : (1 - (shrinkOffset / range)).clamp(0.0, 1.0);
  if (!reduceMotion) return t;
  return t > 0.5 ? 1.0 : 0.0;
}

/// Place line for the collapsed bar: the free-text region, otherwise the
/// country name for the app locale.
String challengeLocationLine(Challenge challenge, String locale) {
  final region = challenge.region?.trim() ?? '';
  if (region.isNotEmpty) return region;
  final code = (challenge.countryCode ?? '')
      .split(',')
      .first
      .trim()
      .toUpperCase();
  const names = <String, Map<String, String>>{
    'cs': {
      'CZ': 'Česko',
      'SK': 'Slovensko',
      'AT': 'Rakousko',
      'DE': 'Německo',
      'PL': 'Polsko',
    },
    'en': {
      'CZ': 'Czechia',
      'SK': 'Slovakia',
      'AT': 'Austria',
      'DE': 'Germany',
      'PL': 'Poland',
    },
    'de': {
      'CZ': 'Tschechien',
      'SK': 'Slowakei',
      'AT': 'Österreich',
      'DE': 'Deutschland',
      'PL': 'Polen',
    },
  };
  return names[locale]?[code] ?? names['en']?[code] ?? code;
}

class _ChallengeHeroDelegate extends SliverPersistentHeaderDelegate {
  _ChallengeHeroDelegate({
    required this.url,
    required this.title,
    required this.location,
    required this.onBack,
    required this.backLabel,
    required this.top,
    required this.maxExtent,
    required this.minExtent,
    required this.reduceMotion,
  });

  final String url;
  final String title;
  final String location;
  final VoidCallback? onBack;
  final String backLabel;
  final double top;
  final bool reduceMotion;

  @override
  final double maxExtent;

  @override
  final double minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final expandedFade = challengeHeroExpandedFade(
      shrinkOffset: shrinkOffset,
      maxExtent: maxExtent,
      minExtent: minExtent,
      reduceMotion: reduceMotion,
    );
    final collapsedFade = 1 - expandedFade;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.mediumMax;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: BrandColors.forest),
        IgnorePointer(
          ignoring: expandedFade == 0,
          child: ExcludeSemantics(
            excluding: expandedFade == 0,
            child: Opacity(
              key: const Key('challenge-hero-expanded'),
              opacity: expandedFade,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: url,
                    logicalWidth: MediaQuery.sizeOf(context).width,
                    fit: BoxFit.cover,
                  ),
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.7,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x0035483C), Color(0xCC35483C)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: wide ? 24 : 16,
                    right: wide ? 24 : 16,
                    bottom: wide ? 16 : 12,
                    child: Text(
                      title,
                      key: const Key('challenge-title'),
                      maxLines: wide ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w600,
                        color: BrandColors.cream,
                        fontSize: wide ? 28 : 24,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: ChallengeCollapsingHero.collapsedBody,
          child: IgnorePointer(
            ignoring: collapsedFade == 0,
            child: ExcludeSemantics(
              excluding: collapsedFade == 0,
              child: Opacity(
                key: const Key('challenge-hero-collapsed'),
                opacity: collapsedFade,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: onBack == null ? 16 : 68,
                    right: 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (location.isNotEmpty)
                        Text(
                          location,
                          key: const Key('challenge-collapsed-location'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: BrandColors.cream.withValues(alpha: 0.85),
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      Text(
                        title,
                        key: const Key('challenge-collapsed-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontWeight: FontWeight.w600,
                          color: BrandColors.cream,
                          fontSize: 18,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (onBack != null)
          Positioned(
            left: 12,
            top: top + 8,
            child: HeroBackButton(label: backLabel, onPressed: onBack),
          ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _ChallengeHeroDelegate oldDelegate) {
    return url != oldDelegate.url ||
        title != oldDelegate.title ||
        location != oldDelegate.location ||
        backLabel != oldDelegate.backLabel ||
        onBack != oldDelegate.onBack ||
        top != oldDelegate.top ||
        maxExtent != oldDelegate.maxExtent ||
        minExtent != oldDelegate.minExtent ||
        reduceMotion != oldDelegate.reduceMotion;
  }
}

/// Width / 4, at least 160 dp. Desktop (width ≥ 840) also caps at 240 dp.
double challengeHeroHeight(double width) {
  final ratio = width / 4;
  if (width >= Breakpoints.mediumMax) {
    return ratio.clamp(160.0, 240.0);
  }
  return ratio < 160 ? 160.0 : ratio;
}
