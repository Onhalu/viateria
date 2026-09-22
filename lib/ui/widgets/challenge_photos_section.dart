import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/challenge_photos.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';

/// Widget tests swap this for [MemoryImage] so the gallery does not hit the
/// network. Production leaves it null and uses [Image.network].
@visibleForTesting
ImageProvider<Object> Function(String url)? debugChallengePhotoImageProvider;

class ChallengePhotosHeader extends StatelessWidget {
  const ChallengePhotosHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('challenge-photos-section'),
      child: Text(
        title,
        key: const Key('challenge-photos-title'),
        style: const TextStyle(
          color: BrandColors.forest,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ChallengePhotosEmpty extends StatelessWidget {
  const ChallengePhotosEmpty({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      key: const Key('challenge-photos-empty'),
      style: const TextStyle(
        color: BrandColors.bark,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Staggered mosaic. Bands are separate sliver children so image widgets
/// (and their network loads) are built as they approach the viewport.
class ChallengePhotoMosaicSliver extends StatelessWidget {
  const ChallengePhotoMosaicSliver({
    super.key,
    required this.photos,
    required this.waypoints,
  });

  final List<ChallengeGalleryPhoto> photos;
  final List<Waypoint> waypoints;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        if (photos.isEmpty || width <= challengePhotoGap) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final layout = layoutChallengePhotoMosaic(
          count: photos.length,
          width: width,
        );
        final bands = bandChallengePhotoMosaic(layout);
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final band = bands[index];
            return SizedBox(
              height: band.height,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final frame in band.tiles)
                    Positioned(
                      left: frame.left,
                      top: frame.top - band.top,
                      width: frame.width,
                      height: frame.height,
                      child: _ChallengePhotoTile(
                        photo: photos[frame.index],
                        waypoints: waypoints,
                        frame: frame,
                        onTap: () {
                          showChallengePhotoLightbox(
                            context: context,
                            photos: photos,
                            waypoints: waypoints,
                            initialIndex: frame.index,
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          }, childCount: bands.length),
        );
      },
    );
  }
}

class _ChallengePhotoTile extends StatelessWidget {
  const _ChallengePhotoTile({
    required this.photo,
    required this.waypoints,
    required this.frame,
    required this.onTap,
  });

  final ChallengeGalleryPhoto photo;
  final List<Waypoint> waypoints;
  final ChallengePhotoTileFrame frame;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final placeName = challengePhotoPlaceName(
      waypoints: waypoints,
      waypointId: photo.waypointId,
      locale: locale,
    );
    final cacheWidth = _cachePixels(context, frame.width);
    return Semantics(
      key: Key('challenge-photo-tile-${frame.index}'),
      button: true,
      label: placeName,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(challengePhotoRadius),
          ),
          child: SizedBox(
            width: frame.width,
            height: frame.height,
            child: _ChallengePhotoImage(
              url: photo.imageUrl,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengePhotoImage extends StatelessWidget {
  const _ChallengePhotoImage({
    required this.url,
    required this.fit,
    this.cacheWidth,
    this.filterQuality = FilterQuality.low,
  });

  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final override = debugChallengePhotoImageProvider;
    if (override != null) {
      return Image(
        image: override(url),
        fit: fit,
        gaplessPlayback: true,
        filterQuality: filterQuality,
        errorBuilder: (_, _, _) => const ColoredBox(color: BrandColors.cream),
      );
    }
    return Image.network(
      url,
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      filterQuality: filterQuality,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(color: BrandColors.cream);
      },
      errorBuilder: (_, _, _) => const ColoredBox(color: BrandColors.cream),
    );
  }
}

int? _cachePixels(BuildContext context, double logicalWidth) {
  if (!logicalWidth.isFinite || logicalWidth <= 0) return null;
  final px = (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round();
  if (px <= 0) return null;
  return px;
}

Future<void> showChallengePhotoLightbox({
  required BuildContext context,
  required List<ChallengeGalleryPhoto> photos,
  required List<Waypoint> waypoints,
  required int initialIndex,
}) {
  if (photos.isEmpty) return Future<void>.value();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: BrandColors.forest.withValues(alpha: 0.8),
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) {
      return ChallengePhotoLightbox(
        photos: photos,
        waypoints: waypoints,
        initialIndex: initialIndex,
      );
    },
  );
}

class ChallengePhotoLightbox extends StatefulWidget {
  const ChallengePhotoLightbox({
    super.key,
    required this.photos,
    required this.waypoints,
    required this.initialIndex,
  });

  final List<ChallengeGalleryPhoto> photos;
  final List<Waypoint> waypoints;
  final int initialIndex;

  @override
  State<ChallengePhotoLightbox> createState() => _ChallengePhotoLightboxState();
}

class _ChallengePhotoLightboxState extends State<ChallengePhotoLightbox> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    final last = widget.photos.length - 1;
    _index = widget.initialIndex.clamp(0, last);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeController = context.watch<LocaleController>();
    final photo = widget.photos[_index];
    final placeName = challengePhotoPlaceName(
      waypoints: widget.waypoints,
      waypointId: photo.waypointId,
      locale: localeController.locale,
    );
    final cacheWidth = _cachePixels(context, MediaQuery.sizeOf(context).width);
    return Material(
      key: const Key('challenge-photo-lightbox'),
      type: MaterialType.transparency,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const Key('challenge-photo-lightbox-close'),
                tooltip: localeController.strings.closeCta,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: BrandColors.cream),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ChallengePhotoImage(
                    url: widget.photos[index].imageUrl,
                    fit: BoxFit.contain,
                    cacheWidth: cacheWidth,
                    filterQuality: FilterQuality.medium,
                  ),
                );
              },
            ),
          ),
          ColoredBox(
            key: const Key('challenge-photo-caption-bar'),
            color: BrandColors.cream,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    placeName,
                    key: const Key('challenge-photo-caption'),
                    style: const TextStyle(
                      color: BrandColors.forest,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
