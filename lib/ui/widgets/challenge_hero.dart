import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../layout/breakpoints.dart';
import 'app_network_image.dart';

/// Full-bleed landscape crop. Under 600 dp the frame is 3:2 and at most
/// 300 dp tall. From 600 dp it is 16:9, and never wider than 2:1: the old
/// 480 dp cap turned 1280 dp into 2.67:1. Web uses the same frame.
class ChallengeHero extends StatelessWidget {
  const ChallengeHero({
    super.key,
    required this.url,
    required this.title,
    this.image,
    this.focalY,
    this.onBack,
    this.backLabel = 'Zpět',
  });

  final String url;
  final String title;

  /// Overrides [url] when tests supply a decoded photo.
  final ImageProvider? image;

  /// Alignment y. Null centres the photo. A stored `hero_focal_y` may override it.
  final double? focalY;
  final VoidCallback? onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final window = MediaQuery.sizeOf(context).width;
        final height = challengeHeroExtent(
          layoutWidth: width,
          windowWidth: window,
        );
        return SizedBox(
          width: width,
          height: height,
          child: CroppedCover(
            provider: image ?? challengeCoverProvider(context, url),
            title: title,
            wide: window >= Breakpoints.mediumMax,
            focalY: focalY,
            backTop: 12 + MediaQuery.paddingOf(context).top,
            back: onBack == null
                ? null
                : HeroBackButton(label: backLabel, onPressed: onBack),
          ),
        );
      },
    );
  }
}

/// 40 dp cream circle on a photo, 48 dp tap target, 20 dp forest arrow.
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
                    size: 20,
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

/// Pinned cover. Expanded height follows [challengeHeroExtent]. Scrolling
/// collapses it into a forest bar with the same back circle, the place, and
/// one Bricolage Grotesque line of the challenge name.
class ChallengeCollapsingHero extends StatelessWidget {
  const ChallengeCollapsingHero({
    super.key,
    required this.url,
    required this.title,
    required this.location,
    this.image,
    this.focalY,
    this.layoutWidth,
    this.onBack,
    this.backLabel = 'Zpět',
  });

  static const collapsedBody = 64.0;

  final String url;
  final String title;
  final String location;
  final ImageProvider? image;
  final double? focalY;

  /// Width the cover is actually laid out at. The screen passes the column
  /// width so a half-width desktop column is not sized as if it were the
  /// whole window.
  final double? layoutWidth;
  final VoidCallback? onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final window = MediaQuery.sizeOf(context).width;
    final width = layoutWidth ?? window;
    final expanded = math.max(
      challengeHeroExtent(layoutWidth: width, windowWidth: window),
      collapsedBody + top + 1,
    );
    return SliverPersistentHeader(
      pinned: true,
      delegate: _ChallengeHeroDelegate(
        provider: image ?? challengeCoverProvider(context, url),
        focalY: focalY,
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

/// `asset://path` loads a bundled photo. Anything else is a network cover.
ImageProvider challengeCoverProvider(BuildContext context, String url) {
  const asset = 'asset://';
  if (url.startsWith(asset)) {
    return AssetImage(url.substring(asset.length));
  }
  final width = MediaQuery.sizeOf(context).width;
  final cache = cachePixelsFor(width, MediaQuery.devicePixelRatioOf(context));
  return NetworkImage(supabaseRenderUrl(url, cache));
}

/// Default focal point: the centre, so the crop keeps the subject in frame.
const challengeHeroFocalY = 0.0;

/// Widest a wide-screen frame is allowed to get. Wider than this is what
/// the 480 dp cap did at 1280 dp (2.67:1) and 1920 dp (4:1).
const challengeHeroWideLimit = 2.0;

/// 3:2 below 600 dp, 16:9 from 600 dp.
double challengeHeroAspect(double windowWidth) =>
    windowWidth >= 600 ? 16 / 9 : 3 / 2;

/// 300 dp on mobile. 960 dp on a wide window, so 1280 dp can stay 16:9
/// (720 dp) and 1920 dp stops at 2:1 (960 dp) instead of 480 dp.
double challengeHeroMaxHeight(double windowWidth) =>
    windowWidth >= 600 ? 960 : 300;

/// Full-bleed height. The wide cap never makes the frame wider than 2:1.
double challengeHeroExtent({
  required double layoutWidth,
  required double windowWidth,
}) {
  if (layoutWidth <= 0) return 0;
  final natural = layoutWidth / challengeHeroAspect(windowWidth);
  var height = math.min(natural, challengeHeroMaxHeight(windowWidth));
  if (windowWidth >= 600) {
    final twoToOne = layoutWidth / challengeHeroWideLimit;
    if (height < twoToOne) height = twoToOne;
  }
  return height;
}

/// Share of a photo's height that [BoxFit.cover] drops. 0 when the frame
/// is as tall as the photo or taller.
double challengeHeroHeightCrop({
  required double layoutWidth,
  required double windowWidth,
  required double photoAspect,
}) {
  final height = challengeHeroExtent(
    layoutWidth: layoutWidth,
    windowWidth: windowWidth,
  );
  if (height <= 0 || photoAspect <= 0) return 0;
  final frameAspect = layoutWidth / height;
  if (frameAspect <= photoAspect) return 0;
  return 1 - photoAspect / frameAspect;
}

Alignment challengeHeroAlignment(double? focalY) {
  final y = focalY ?? challengeHeroFocalY;
  return Alignment(0, y.clamp(-1.0, 1.0));
}

class CroppedCover extends StatelessWidget {
  const CroppedCover({
    super.key,
    required this.provider,
    required this.title,
    required this.wide,
    this.focalY,
    this.back,
    this.backTop = 12,
  });

  final ImageProvider provider;
  final String title;
  final bool wide;
  final double? focalY;
  final Widget? back;
  final double backTop;

  @override
  Widget build(BuildContext context) {
    final pad = wide ? 24.0 : 16.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: BrandColors.forest),
        Image(
          key: const Key('challenge-hero-photo'),
          image: provider,
          fit: BoxFit.cover,
          alignment: challengeHeroAlignment(focalY),
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const AppImagePlaceholder(),
        ),
        const _HeroScrim(),
        Positioned(
          left: pad,
          right: pad,
          bottom: wide ? 16 : 12,
          child: Text(
            title,
            key: const Key('challenge-title'),
            maxLines: wide ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: BrandTypography.display(
              fontSize: wide ? 28 : 24,
              color: BrandColors.cream,
            ),
          ),
        ),
        if (back != null) Positioned(left: 12, top: backTop, child: back!),
      ],
    );
  }
}

/// Forest at 40% fading to clear over the top quarter of the photo.
class _HeroScrim extends StatelessWidget {
  const _HeroScrim();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(
        heightFactor: 0.25,
        widthFactor: 1,
        child: DecoratedBox(
          key: const Key('challenge-hero-scrim'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                BrandColors.forest.withValues(alpha: 0.4),
                BrandColors.forest.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeHeroDelegate extends SliverPersistentHeaderDelegate {
  _ChallengeHeroDelegate({
    required this.provider,
    required this.focalY,
    required this.title,
    required this.location,
    required this.onBack,
    required this.backLabel,
    required this.top,
    required this.maxExtent,
    required this.minExtent,
    required this.reduceMotion,
  });

  final ImageProvider provider;
  final double? focalY;
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
        const ColoredBox(color: BrandColors.forest),
        IgnorePointer(
          ignoring: expandedFade == 0,
          child: ExcludeSemantics(
            excluding: expandedFade == 0,
            child: Opacity(
              key: const Key('challenge-hero-expanded'),
              opacity: expandedFade,
              child: CroppedCover(
                provider: provider,
                title: title,
                wide: wide,
                focalY: focalY,
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
                        style: BrandTypography.display(
                          fontSize: 18,
                          color: BrandColors.cream,
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
    return provider != oldDelegate.provider ||
        focalY != oldDelegate.focalY ||
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
