import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../layout/breakpoints.dart';
import 'app_network_image.dart';

/// Full-bleed challenge cover. Aspect comes from the loaded image.
class ChallengeHero extends StatefulWidget {
  const ChallengeHero({
    super.key,
    required this.url,
    required this.title,
    this.lengthLabel,
    this.difficultyLabel,
  });

  final String url;
  final String title;
  final String? lengthLabel;
  final String? difficultyLabel;

  @override
  State<ChallengeHero> createState() => _ChallengeHeroState();
}

class _ChallengeHeroState extends State<ChallengeHero> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _intrinsic;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ChallengeHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve();
  }

  void _resolve() {
    final provider = NetworkImage(widget.url);
    final next = provider.resolve(createLocalImageConfiguration(context));
    if (identical(next, _stream)) return;
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _listener = ImageStreamListener((info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (!mounted || _intrinsic == size) return;
      setState(() => _intrinsic = size);
    }, onError: (_, _) {});
    _stream = next;
    next.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final viewport = MediaQuery.sizeOf(context).height;
        final wide = width >= Breakpoints.mediumMax;
        final minHeight = wide ? 280.0 : 220.0;
        final maxHeight = wide ? 520.0 : viewport * 0.56;
        final intrinsic = _intrinsic;
        final aspect = intrinsic == null || intrinsic.height == 0
            ? 16 / 9
            : intrinsic.width / intrinsic.height;
        final natural = width / aspect;
        final crop = natural > maxHeight;
        final height = natural.clamp(minHeight, maxHeight);
        final chips = [
          if (widget.lengthLabel != null) widget.lengthLabel!,
          if (widget.difficultyLabel != null) widget.difficultyLabel!,
        ];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (intrinsic == null)
                const ColoredBox(
                  key: Key('challenge-hero-skeleton'),
                  color: Color(0x66D8CDB8),
                )
              else
                AppNetworkImage(
                  url: widget.url,
                  logicalWidth: width,
                  fit: crop ? BoxFit.cover : BoxFit.fitWidth,
                  alignment: crop ? const Alignment(0, -0.2) : Alignment.center,
                ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.55,
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x0035483C), Color(0xB835483C)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: wide ? 24 : 16,
                right: wide ? 24 : 16,
                bottom: wide ? 24 : 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      key: const Key('challenge-title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w600,
                        color: BrandColors.cream,
                        fontSize: wide ? 36 : 28,
                        height: 1.15,
                        shadows: [
                          Shadow(
                            color: Color(0x4D000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final label in chips) _HeroChip(label: label),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BrandColors.cream.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          height: 28,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: BrandColors.forest,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
