import 'package:flutter/material.dart';

import 'map_chrome.dart';

/// Shared metrics for place rows, detail sheets, and planner ends.
///
/// Category glyphs stay one size. The 32px well is an 8pt slot; the title
/// line is nudged so its center lines up with that well.
abstract final class PlaceRowMetrics {
  static const iconBox = 32.0;
  static const iconGlyph = MapChromeSizes.listRowIcon;
  static const titleGap = 12.0;
  static const titleNudge = 4.0;

  static const titleStyle = TextStyle(
    color: BrandColors.forest,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  static const descriptionStyle = TextStyle(
    color: BrandColors.bark,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );
}

/// Category silhouette in a fixed box so every type shares one optical size.
class PlaceCategoryIcon extends StatelessWidget {
  const PlaceCategoryIcon({
    super.key,
    required this.iconName,
    this.iconKey,
    this.semanticLabel,
  });

  final String iconName;
  final Key? iconKey;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: PlaceRowMetrics.iconBox,
      height: PlaceRowMetrics.iconBox,
      child: Center(
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            BrandColors.forest,
            BlendMode.srcIn,
          ),
          child: Image.asset(
            'assets/map/icons/$iconName@2x.png',
            key: iconKey,
            width: PlaceRowMetrics.iconGlyph,
            height: PlaceRowMetrics.iconGlyph,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            semanticLabel: semanticLabel,
            excludeFromSemantics: semanticLabel == null,
          ),
        ),
      ),
    );
  }
}

/// Stadium meta chip. Same cream / beige / bark treatment as catalog chips.
class PlaceMetaChip extends StatelessWidget {
  const PlaceMetaChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BrandColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BrandColors.beige),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: BrandColors.bark,
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Secondary place copy. Blank text stays hidden. Long copy ellipsizes,
/// and can expand when [moreLabel] is set.
class PlaceDescriptionText extends StatefulWidget {
  const PlaceDescriptionText({
    super.key,
    required this.text,
    this.textKey,
    this.toggleKey,
    this.maxLines = 4,
    this.moreLabel,
    this.lessLabel,
  });

  final String text;
  final Key? textKey;
  final Key? toggleKey;
  final int maxLines;
  final String? moreLabel;
  final String? lessLabel;

  @override
  State<PlaceDescriptionText> createState() => _PlaceDescriptionTextState();
}

class _PlaceDescriptionTextState extends State<PlaceDescriptionText> {
  var _expanded = false;

  bool _exceeds(double maxWidth, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(
        text: widget.text.trim(),
        style: PlaceRowMetrics.descriptionStyle,
      ),
      maxLines: widget.maxLines,
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
    final exceeds = painter.didExceedMaxLines;
    painter.dispose();
    return exceeds;
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final scaler = MediaQuery.textScalerOf(context);
    final canToggle =
        widget.moreLabel != null &&
        widget.lessLabel != null &&
        widget.moreLabel!.isNotEmpty &&
        widget.lessLabel!.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final overflows =
            canToggle && width.isFinite && _exceeds(width, scaler);
        final expanded = _expanded && overflows;
        final body = Text(
          trimmed,
          key: widget.textKey,
          style: PlaceRowMetrics.descriptionStyle,
          maxLines: expanded ? null : widget.maxLines,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expanded)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(child: body),
              )
            else
              body,
            if (overflows) ...[
              const SizedBox(height: 4),
              TextButton(
                key: widget.toggleKey,
                style: TextButton.styleFrom(
                  foregroundColor: BrandColors.forest,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(expanded ? widget.lessLabel! : widget.moreLabel!),
              ),
            ],
          ],
        );
      },
    );
  }
}
