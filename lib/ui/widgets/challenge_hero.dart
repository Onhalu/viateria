import 'package:flutter/material.dart';

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
                  child: const _HeroBackButton(),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 40 dp cream circle, 48 dp tap target, forest arrow.
class _HeroBackButton extends StatelessWidget {
  const _HeroBackButton();

  @override
  Widget build(BuildContext context) {
    final hero = context.findAncestorWidgetOfExactType<ChallengeHero>()!;
    return Tooltip(
      message: hero.backLabel,
      child: Semantics(
        button: true,
        label: hero.backLabel,
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
                onTap: hero.onBack,
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

/// Width / 4, at least 160 dp. Desktop (width ≥ 840) also caps at 240 dp.
double challengeHeroHeight(double width) {
  final ratio = width / 4;
  if (width >= Breakpoints.mediumMax) {
    return ratio.clamp(160.0, 240.0);
  }
  return ratio < 160 ? 160.0 : ratio;
}
