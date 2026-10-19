import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';

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

/// Network image with a decode cap, beige placeholder, and beige error.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.logicalWidth,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
  });

  final String? url;
  final double? logicalWidth;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
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
        return Image.network(
          supabaseRenderUrl(raw, cacheWidth),
          fit: fit,
          alignment: alignment,
          cacheWidth: cacheWidth,
          semanticLabel: semanticLabel,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const AppImagePlaceholder();
          },
          errorBuilder: (_, _, _) => const AppImagePlaceholder(),
        );
      },
    );
  }
}
