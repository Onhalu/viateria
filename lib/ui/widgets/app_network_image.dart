import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import '../../theme/brand_colors.dart';
import 'error_state.dart';

/// Decode width in physical pixels for [Image.cacheWidth].
int? cachePixelsFor(double logicalWidth, double devicePixelRatio) {
  if (logicalWidth.isNaN || logicalWidth.isInfinite || logicalWidth <= 0) {
    return null;
  }
  if (devicePixelRatio.isNaN ||
      devicePixelRatio.isInfinite ||
      devicePixelRatio <= 0) {
    return null;
  }
  return (logicalWidth * devicePixelRatio).round().clamp(1, 4096);
}

/// Supabase Storage render URL so covers are not downloaded at full size.
///
/// Other hosts are returned unchanged.
String supabaseRenderUrl(String url, int? width) {
  if (width == null || width <= 0) return url;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return url;
  if (!uri.host.contains('supabase.co')) return url;
  const objectPrefix = '/storage/v1/object/';
  if (!uri.path.contains(objectPrefix)) return url;
  final path = uri.path.replaceFirst(objectPrefix, '/storage/v1/render/image/');
  final params = Map<String, String>.from(uri.queryParameters);
  params['width'] = '$width';
  params.putIfAbsent('quality', () => '70');
  // Width only. A `resize=cover` param would crop to a different ratio
  // before the card can decide cover vs contain.
  params.remove('resize');
  return uri.replace(path: path, queryParameters: params).toString();
}

/// 4:3 card photos within ±15% of 4:3 (1.13–1.53) may crop. Anything else
/// is shown whole.
bool catalogCoverShouldCrop(double aspectRatio) {
  return aspectRatio >= 1.13 && aspectRatio <= 1.53;
}

const catalogCardAspectRatio = 4 / 3;

/// Beige stand-in used while a network image loads or fails.
class AppImagePlaceholder extends StatelessWidget {
  const AppImagePlaceholder({super.key, this.icon = Icons.landscape});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BrandColors.beige,
      child: Center(child: Icon(icon, size: 48, color: BrandColors.forest)),
    );
  }
}

/// BlurHash alphabet. Same 83 characters the decoder accepts.
const _blurHashAlphabet =
    r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~';

/// A BlurHash the decoder will accept, or null when [raw] is missing or
/// malformed. Callers then keep the beige skeleton instead of an empty box.
String? usableBlurHash(String? raw) {
  final hash = raw?.trim() ?? '';
  if (hash.length < 6) return null;
  final digits = _blurHashAlphabet.codeUnits;
  for (final code in hash.codeUnits) {
    if (!digits.contains(code)) return null;
  }
  final sizeFlag = _decode83(hash[0]);
  final numY = (sizeFlag / 9).floor() + 1;
  final numX = (sizeFlag % 9) + 1;
  if (hash.length != 4 + 2 * numX * numY) return null;
  return hash;
}

int _decode83(String text) {
  final digits = _blurHashAlphabet.codeUnits;
  var value = 0;
  for (final code in text.codeUnits) {
    value = value * 83 + digits.indexOf(code);
  }
  return value;
}

/// What a cover shows until the photo's first frame: BlurHash when [blurHash]
/// decodes, otherwise a beige skeleton with a landscape mark. Never an empty
/// grey or cream rectangle.
class AppCoverUnderlay extends StatelessWidget {
  const AppCoverUnderlay({super.key, this.blurHash});

  final String? blurHash;

  @override
  Widget build(BuildContext context) {
    final hash = usableBlurHash(blurHash);
    final shape = const _CoverShape();
    if (hash == null) return shape;
    return Stack(
      fit: StackFit.expand,
      children: [
        shape,
        BlurHash(
          hash: hash,
          color: const Color(0x00000000),
          imageFit: BoxFit.cover,
        ),
      ],
    );
  }
}

class _CoverShape extends StatelessWidget {
  const _CoverShape();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        AppSkeleton(radius: 0),
        Center(
          child: Icon(Icons.landscape, size: 48, color: BrandColors.forest),
        ),
      ],
    );
  }
}

/// Photo with a BlurHash or skeleton underneath until the first frame.
class AppCoverImage extends StatelessWidget {
  const AppCoverImage({
    super.key,
    required this.image,
    this.blurHash,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.imageKey,
  });

  final ImageProvider image;
  final String? blurHash;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppCoverUnderlay(blurHash: blurHash),
        Image(
          key: imageKey,
          image: image,
          fit: fit,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          semanticLabel: semanticLabel,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return const SizedBox.shrink();
          },
          errorBuilder: (_, _, _) => const AppImagePlaceholder(),
        ),
      ],
    );
  }
}

/// Network image with a decode cap. A BlurHash sits under the photo when
/// [blurHash] is set; otherwise a beige skeleton does. Errors keep a shape.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.blurHash,
    this.logicalWidth,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.image,
  });

  final String? url;
  final String? blurHash;
  final double? logicalWidth;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;

  /// Overrides [url] when tests supply a provider that must not hit the network.
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final override = image;
    if (override != null) {
      return AppCoverImage(
        image: override,
        blurHash: blurHash,
        fit: fit,
        alignment: alignment,
        semanticLabel: semanticLabel,
      );
    }
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return const AppImagePlaceholder();
    return LayoutBuilder(
      builder: (context, constraints) {
        final logical =
            logicalWidth ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
        final cacheWidth = logical == null
            ? null
            : cachePixelsFor(logical, MediaQuery.devicePixelRatioOf(context));
        final rendered = supabaseRenderUrl(raw, cacheWidth);
        final ImageProvider provider = cacheWidth == null
            ? NetworkImage(rendered)
            : ResizeImage(NetworkImage(rendered), width: cacheWidth);
        final bounded =
            constraints.maxWidth.isFinite && constraints.maxHeight.isFinite;
        if (!bounded) {
          return Image(
            image: provider,
            fit: fit,
            alignment: alignment,
            semanticLabel: semanticLabel,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const AppImagePlaceholder(),
          );
        }
        return AppCoverImage(
          image: provider,
          blurHash: blurHash,
          fit: fit,
          alignment: alignment,
          semanticLabel: semanticLabel,
        );
      },
    );
  }
}
