import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../layout/breakpoints.dart';
import 'app_network_image.dart';

/// Full-width challenge cover. The whole photo is visible: height follows
/// the image aspect ratio and is capped at 70% of the viewport. A capped
/// photo is letterboxed over a blurred copy of itself and is never cropped.
class ChallengeHero extends StatefulWidget {
  const ChallengeHero({
    super.key,
    required this.url,
    required this.title,
    this.image,
    this.onBack,
    this.backLabel = 'Zpět',
  });

  final String url;
  final String title;

  /// Overrides [url] when tests supply a decoded photo.
  final ImageProvider? image;
  final VoidCallback? onBack;
  final String backLabel;

  @override
  State<ChallengeHero> createState() => _ChallengeHeroState();
}

class _ChallengeHeroState extends State<ChallengeHero> {
  final _cover = _CoverSubscription();
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
  }

  @override
  void didUpdateWidget(ChallengeHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.image != widget.image) {
      _imageSize = null;
      _listen();
    }
  }

  @override
  void dispose() {
    _cover.cancel();
    super.dispose();
  }

  void _listen() {
    _cover.listen(
      provider: _provider,
      context: context,
      onSize: (size) {
        if (!mounted || size == _imageSize) return;
        setState(() => _imageSize = size);
      },
    );
  }

  ImageProvider get _provider =>
      widget.image ?? challengeCoverProvider(context, widget.url);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final viewport = MediaQuery.sizeOf(context).height;
        final height = challengeHeroExtent(
          width: width,
          viewportHeight: viewport,
          imageWidth: _imageSize?.width,
          imageHeight: _imageSize?.height,
        );
        return SizedBox(
          width: width,
          height: height,
          child: UncroppedCover(
            provider: _provider,
            imageSize: _imageSize,
            title: widget.title,
            wide: width >= Breakpoints.mediumMax,
            letterboxed: challengeHeroLetterboxed(
              width: width,
              viewportHeight: viewport,
              imageWidth: _imageSize?.width,
              imageHeight: _imageSize?.height,
            ),
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

/// Pinned cover. Expanded height follows the photo. Scrolling collapses it
/// into a forest bar with the same back circle, the place, and one Playfair
/// line of the challenge name.
class ChallengeCollapsingHero extends StatefulWidget {
  const ChallengeCollapsingHero({
    super.key,
    required this.url,
    required this.title,
    required this.location,
    this.image,
    this.layoutWidth,
    this.onBack,
    this.backLabel = 'Zpět',
  });

  static const collapsedBody = 64.0;

  final String url;
  final String title;
  final String location;
  final ImageProvider? image;

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
  final _cover = _CoverSubscription();
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
  }

  @override
  void didUpdateWidget(ChallengeCollapsingHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.image != widget.image) {
      _imageSize = null;
      _listen();
    }
  }

  @override
  void dispose() {
    _cover.cancel();
    super.dispose();
  }

  void _listen() {
    _cover.listen(
      provider: widget.image ?? challengeCoverProvider(context, widget.url),
      context: context,
      onSize: (size) {
        if (!mounted || size == _imageSize) return;
        setState(() => _imageSize = size);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final width = widget.layoutWidth ?? MediaQuery.sizeOf(context).width;
    final expanded = math.max(
      challengeHeroExtent(
        width: width,
        viewportHeight: MediaQuery.sizeOf(context).height,
        imageWidth: _imageSize?.width,
        imageHeight: _imageSize?.height,
      ),
      ChallengeCollapsingHero.collapsedBody + top + 1,
    );
    return SliverPersistentHeader(
      pinned: true,
      delegate: _ChallengeHeroDelegate(
        provider: widget.image ?? challengeCoverProvider(context, widget.url),
        imageSize: _imageSize,
        layoutWidth: width,
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

/// Height of a full-width cover that shows the whole photo.
///
/// Without a resolved image, falls back to [challengeHeroHeight]. The result
/// never exceeds 70% of [viewportHeight].
double challengeHeroExtent({
  required double width,
  required double viewportHeight,
  double? imageWidth,
  double? imageHeight,
}) {
  final cap = viewportHeight > 0
      ? viewportHeight * challengeHeroViewportCap
      : double.infinity;
  final fallback = math.min(challengeHeroHeight(width), cap);
  if (imageWidth == null ||
      imageHeight == null ||
      imageWidth <= 0 ||
      imageHeight <= 0 ||
      width <= 0) {
    return fallback;
  }
  return math.min(width * imageHeight / imageWidth, cap);
}

/// True when the photo is taller than the 70% cap and must be letterboxed.
bool challengeHeroLetterboxed({
  required double width,
  required double viewportHeight,
  double? imageWidth,
  double? imageHeight,
}) {
  if (imageWidth == null ||
      imageHeight == null ||
      imageWidth <= 0 ||
      imageHeight <= 0 ||
      width <= 0 ||
      viewportHeight <= 0) {
    return false;
  }
  final natural = width * imageHeight / imageWidth;
  return natural > viewportHeight * challengeHeroViewportCap + 0.5;
}

const challengeHeroViewportCap = 0.7;

/// Width / 4, at least 160 dp. Desktop (width ≥ 840) also caps at 240 dp.
/// Used only until the photo's own aspect ratio is known.
double challengeHeroHeight(double width) {
  final ratio = width / 4;
  if (width >= Breakpoints.mediumMax) {
    return ratio.clamp(160.0, 240.0);
  }
  return ratio < 160 ? 160.0 : ratio;
}

class UncroppedCover extends StatelessWidget {
  const UncroppedCover({
    super.key,
    required this.provider,
    required this.imageSize,
    required this.title,
    required this.wide,
    required this.letterboxed,
    this.back,
    this.backTop = 12,
  });

  final ImageProvider provider;
  final Size? imageSize;
  final String title;
  final bool wide;
  final bool letterboxed;
  final Widget? back;
  final double backTop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = Size(constraints.maxWidth, constraints.maxHeight);
        var photo = Offset.zero & frame;
        final source = imageSize;
        if (source != null && source.width > 0 && source.height > 0) {
          final fitted = applyBoxFit(BoxFit.contain, source, frame);
          photo = Alignment.center.inscribe(
            fitted.destination,
            Offset.zero & frame,
          );
        }
        final pad = wide ? 24.0 : 16.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: BrandColors.forest),
            if (letterboxed)
              ClipRect(
                child: ImageFiltered(
                  key: const Key('challenge-hero-letterbox'),
                  imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Image(
                    image: provider,
                    fit: BoxFit.cover,
                    width: frame.width,
                    height: frame.height,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const AppImagePlaceholder(),
                  ),
                ),
              ),
            Image(
              key: const Key('challenge-hero-photo'),
              image: provider,
              fit: BoxFit.contain,
              width: frame.width,
              height: frame.height,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const AppImagePlaceholder(),
            ),
            Positioned(
              left: photo.left,
              top: photo.top + photo.height * 0.3,
              width: photo.width,
              height: photo.height * 0.7,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x0035483C), Color(0xCC35483C)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: photo.left + pad,
              width: math.max(0, photo.width - pad * 2),
              bottom: frame.height - photo.bottom + (wide ? 16 : 12),
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
            if (back != null)
              Positioned(left: 12, top: backTop, child: back!),
          ],
        );
      },
    );
  }
}

class _CoverSubscription {
  ImageProvider? _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  void listen({
    required ImageProvider provider,
    required BuildContext context,
    required ValueChanged<Size> onSize,
  }) {
    if (_provider == provider && _stream != null) return;
    cancel();
    _provider = provider;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, _) {
      onSize(
        Size(info.image.width.toDouble(), info.image.height.toDouble()),
      );
    }, onError: (_, _) {});
    _stream = stream;
    stream.addListener(_listener!);
  }

  void cancel() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _stream = null;
    _listener = null;
    _provider = null;
  }
}

class _ChallengeHeroDelegate extends SliverPersistentHeaderDelegate {
  _ChallengeHeroDelegate({
    required this.provider,
    required this.imageSize,
    required this.layoutWidth,
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
  final Size? imageSize;
  final double layoutWidth;
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
    final viewport = MediaQuery.sizeOf(context).height;
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
              child: UncroppedCover(
                provider: provider,
                imageSize: imageSize,
                title: title,
                wide: wide,
                letterboxed: challengeHeroLetterboxed(
                  width: layoutWidth,
                  viewportHeight: viewport,
                  imageWidth: imageSize?.width,
                  imageHeight: imageSize?.height,
                ),
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
        imageSize != oldDelegate.imageSize ||
        layoutWidth != oldDelegate.layoutWidth ||
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
