import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../layout/breakpoints.dart';
import 'app_network_image.dart';

/// Full-bleed hero band. The photo keeps its own aspect ratio: full width
/// until it would exceed the height cap, then the width shrinks and the
/// forest band fills the sides. Web uses this same layout.
class ChallengeHero extends StatefulWidget {
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

  /// Alignment y. Null uses −0.2. A stored `hero_focal_y` may override it.
  final double? focalY;
  final VoidCallback? onBack;
  final String backLabel;

  @override
  State<ChallengeHero> createState() => _ChallengeHeroState();
}

class _ChallengeHeroState extends State<ChallengeHero> {
  final _aspect = _HeroAspect();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(ChallengeHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.image != widget.image) {
      _aspect.reset();
    }
    _bind();
  }

  @override
  void dispose() {
    _aspect.unbind();
    super.dispose();
  }

  void _bind() {
    _aspect.bind(
      context,
      widget.image ?? challengeCoverProvider(context, widget.url),
      () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        widget.image ?? challengeCoverProvider(context, widget.url);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final window = MediaQuery.sizeOf(context).width;
        final height = challengeHeroExtent(
          layoutWidth: width,
          windowWidth: window,
          imageAspect: _aspect.aspect,
        );
        return SizedBox(
          width: width,
          height: height,
          child: CroppedCover(
            provider: provider,
            title: widget.title,
            wide: window >= Breakpoints.mediumMax,
            focalY: widget.focalY,
            imageAspect: _aspect.aspect,
            backTop: 12 + MediaQuery.paddingOf(context).top,
            back: widget.onBack == null
                ? null
                : HeroBackButton(
                    label: widget.backLabel,
                    onPressed: widget.onBack,
                  ),
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
/// one Playfair line of the challenge name.
class ChallengeCollapsingHero extends StatefulWidget {
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
  State<ChallengeCollapsingHero> createState() =>
      _ChallengeCollapsingHeroState();
}

class _ChallengeCollapsingHeroState extends State<ChallengeCollapsingHero> {
  final _aspect = _HeroAspect();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(ChallengeCollapsingHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.image != widget.image) {
      _aspect.reset();
    }
    _bind();
  }

  @override
  void dispose() {
    _aspect.unbind();
    super.dispose();
  }

  void _bind() {
    _aspect.bind(
      context,
      widget.image ?? challengeCoverProvider(context, widget.url),
      () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        widget.image ?? challengeCoverProvider(context, widget.url);
    final top = MediaQuery.paddingOf(context).top;
    final window = MediaQuery.sizeOf(context).width;
    final width = widget.layoutWidth ?? window;
    final expanded = math.max(
      challengeHeroExtent(
        layoutWidth: width,
        windowWidth: window,
        imageAspect: _aspect.aspect,
      ),
      ChallengeCollapsingHero.collapsedBody + top + 1,
    );
    return SliverPersistentHeader(
      pinned: true,
      delegate: _ChallengeHeroDelegate(
        provider: provider,
        focalY: widget.focalY,
        imageAspect: _aspect.aspect,
        title: widget.title,
        location: widget.location,
        onBack: widget.onBack,
        backLabel: widget.backLabel,
        top: top,
        maxExtent: expanded,
        minExtent: ChallengeCollapsingHero.collapsedBody + top,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      ),
    );
  }
}

/// Reads the photo's pixel ratio once, so the frame can match it.
class _HeroAspect {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? aspect;

  void bind(
    BuildContext context,
    ImageProvider provider,
    VoidCallback onChanged,
  ) {
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    unbind();
    _listener = ImageStreamListener((info, _) {
      final height = info.image.height;
      if (height == 0) return;
      final next = info.image.width / height;
      if (aspect == next) return;
      aspect = next;
      onChanged();
    }, onError: (_, _) {});
    _stream = stream;
    stream.addListener(_listener!);
  }

  void reset() {
    unbind();
    aspect = null;
  }

  void unbind() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
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

/// Default focal point: slightly above center.
const challengeHeroFocalY = -0.2;

/// 3:2 below 600 dp, 16:9 from 600 dp.
double challengeHeroAspect(double windowWidth) =>
    windowWidth >= 600 ? 16 / 9 : 3 / 2;

/// 300 dp on mobile, 480 dp on desktop.
double challengeHeroMaxHeight(double windowWidth) =>
    windowWidth >= 600 ? 480 : 300;

double _heroFrameAspect(double windowWidth, double? imageAspect) {
  if (imageAspect != null && imageAspect > 0 && imageAspect.isFinite) {
    return imageAspect;
  }
  return challengeHeroAspect(windowWidth);
}

/// Band height. Uses the photo's own ratio once it is known. Until then the
/// placeholder is 3:2 below 600 dp and 16:9 from 600 dp, still under the cap.
double challengeHeroExtent({
  required double layoutWidth,
  required double windowWidth,
  double? imageAspect,
}) {
  if (layoutWidth <= 0) return 0;
  final natural = layoutWidth / _heroFrameAspect(windowWidth, imageAspect);
  return math.min(natural, challengeHeroMaxHeight(windowWidth));
}

/// Photo width. Full bleed when the photo fits under the height cap.
/// Otherwise the width is `cap × aspect` and the band fills the sides,
/// instead of [BoxFit.cover] zooming a wider frame.
double challengeHeroPhotoWidth({
  required double layoutWidth,
  required double windowWidth,
  double? imageAspect,
}) {
  if (layoutWidth <= 0) return 0;
  final aspect = _heroFrameAspect(windowWidth, imageAspect);
  final cap = challengeHeroMaxHeight(windowWidth);
  final natural = layoutWidth / aspect;
  if (natural <= cap) return layoutWidth;
  return cap * aspect;
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
    this.imageAspect,
    this.back,
    this.backTop = 12,
  });

  final ImageProvider provider;
  final String title;
  final bool wide;
  final double? focalY;

  /// Pixel width ÷ height of [provider], once decoded. Null keeps the
  /// placeholder ratio from [challengeHeroAspect].
  final double? imageAspect;
  final Widget? back;
  final double backTop;

  @override
  Widget build(BuildContext context) {
    final pad = wide ? 24.0 : 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final window = MediaQuery.sizeOf(context).width;
        final layout = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : window;
        final photoWidth = challengeHeroPhotoWidth(
          layoutWidth: layout,
          windowWidth: window,
          imageAspect: imageAspect,
        );
        final photoHeight = challengeHeroExtent(
          layoutWidth: layout,
          windowWidth: window,
          imageAspect: imageAspect,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: BrandColors.forest),
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: photoWidth,
                height: photoHeight,
                child: Image(
                  key: const Key('challenge-hero-photo'),
                  image: provider,
                  fit: BoxFit.contain,
                  alignment: challengeHeroAlignment(focalY),
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const AppImagePlaceholder(),
                ),
              ),
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
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.cream,
                  fontSize: wide ? 28 : 24,
                  height: 1.15,
                ),
              ),
            ),
            if (back != null) Positioned(left: 12, top: backTop, child: back!),
          ],
        );
      },
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
    required this.imageAspect,
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
  final double? imageAspect;
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
                imageAspect: imageAspect,
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
    return provider != oldDelegate.provider ||
        focalY != oldDelegate.focalY ||
        imageAspect != oldDelegate.imageAspect ||
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
