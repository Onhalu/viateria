import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'app_shell.dart';

/// Sage glass panel behind the floating challenge payment actions.
///
/// The in-page block does not use this chrome. Only the slide-up pair does.
class ChallengeCtaPanel extends StatelessWidget {
  const ChallengeCtaPanel({
    super.key,
    required this.heading,
    required this.diplomaLabel,
    required this.medalLabel,
    required this.onDiploma,
    required this.onMedal,
    this.loadingLabel = 'Načítání',
  });

  final String heading;
  final String diplomaLabel;
  final String medalLabel;
  final VoidCallback? onDiploma;
  final VoidCallback? onMedal;
  final String loadingLabel;

  /// Sage `#9C9A7B` at 0.90 opacity.
  static const fill = Color(0xE69C9A7B);

  /// Same fill at 0.96, if 0.90 leaves the heading unreadable over a photo.
  static const fillFallback = Color(0xF59C9A7B);

  static const radius = 24.0;
  static const blurSigma = 20.0;
  static const borderWidth = 1.0;
  static const padHorizontal = 20.0;
  static const padTop = 16.0;
  static const padBottom = 20.0;
  static const headingGap = 12.0;
  static const headingSize = 20.0;
  static const headingLineHeight = 26.0;
  static const rowGap = 32.0;
  static const stackGap = 12.0;
  static const stackBelow = 360.0;
  static const wideFrom = 600.0;
  static const maxWidth = 560.0;
  static const aboveNav = 12.0;
  static const restingBottom = 16.0;
  static const buttonHeight = 48.0;
  static const motionDuration = Duration(milliseconds: 220);

  /// Forest `#35483C` at about 18% opacity. The panel's only shadow.
  static const shadow = BoxShadow(
    color: Color(0x2E35483C),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  static Color get borderColor => BrandColors.cream.withValues(alpha: 0.40);

  static bool buttonsStack(double windowWidth) => windowWidth < stackBelow;

  /// Gap under the panel. Phone width sits 12 dp above the bottom nav, which
  /// already includes the safe area. From 600 dp the rail replaces that nav.
  static double bottomMargin(double windowWidth) =>
      windowWidth >= wideFrom ? restingBottom : aboveNav;

  static double _buttonsHeight(double windowWidth) => buttonsStack(windowWidth)
      ? buttonHeight + stackGap + buttonHeight
      : buttonHeight;

  /// Lines reserved so a wrapped localized heading still clears the feed.
  /// Czech fits on one line; English and German can take two at phone width.
  static const headingLines = 2;

  /// Laid-out height of the bar, including the margin under the glass.
  /// Safe area is added by the caller.
  static double bodyHeight(double windowWidth) =>
      padTop +
      headingLineHeight * headingLines +
      headingGap +
      _buttonsHeight(windowWidth) +
      padBottom +
      bottomMargin(windowWidth);

  static double occupiedHeight(double windowWidth, double safeBottom) =>
      bodyHeight(windowWidth) + safeBottom;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final stack = buttonsStack(width);
    final diploma = AppButton(
      key: const Key('challenge-floating-pay-diploma'),
      label: diplomaLabel,
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.m,
      loadingLabel: loadingLabel,
      onPressed: onDiploma,
    );
    final medal = AppButton(
      key: const Key('challenge-floating-pay-medal'),
      label: medalLabel,
      variant: AppButtonVariant.primary,
      size: AppButtonSize.m,
      loadingLabel: loadingLabel,
      onPressed: onMedal,
    );
    final buttons = stack
        ? Column(
            key: const Key('challenge-floating-pay-ctas'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              diploma,
              const SizedBox(height: stackGap),
              medal,
            ],
          )
        : Row(
            key: const Key('challenge-floating-pay-ctas'),
            children: [
              Expanded(child: diploma),
              const SizedBox(width: rowGap),
              Expanded(child: medal),
            ],
          );
    return DecoratedBox(
      key: const Key('challenge-cta-shadow'),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        boxShadow: [shadow],
      ),
      child: ClipRRect(
        key: const Key('challenge-cta-clip'),
        borderRadius: const BorderRadius.all(Radius.circular(radius)),
        child: BackdropFilter(
          key: const Key('challenge-cta-blur'),
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            key: const Key('challenge-cta-fill'),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: const BorderRadius.all(Radius.circular(radius)),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Padding(
              key: const Key('challenge-cta-padding'),
              padding: const EdgeInsets.fromLTRB(
                padHorizontal,
                padTop,
                padHorizontal,
                padBottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    heading,
                    key: const Key('challenge-paybar-heading'),
                    textAlign: TextAlign.center,
                    maxLines: headingLines,
                    overflow: TextOverflow.ellipsis,
                    style: BrandTypography.display(
                      fontSize: headingSize,
                      height: headingLineHeight / headingSize,
                      color: BrandColors.forest,
                    ),
                  ),
                  const SizedBox(height: headingGap),
                  buttons,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Insets and centres [ChallengeCtaPanel] for the challenge detail stack.
///
/// Place it in a bottom [Positioned] with a tight width. On a phone the panel
/// is the full width minus [kNavSideInset] on each side. From 600 dp it is at
/// most 560 dp and centred, 16 dp above the bottom safe area.
class ChallengeCtaPanelBar extends StatelessWidget {
  const ChallengeCtaPanelBar({
    super.key,
    required this.heading,
    required this.diplomaLabel,
    required this.medalLabel,
    required this.onDiploma,
    required this.onMedal,
    this.loadingLabel = 'Načítání',
  });

  final String heading;
  final String diplomaLabel;
  final String medalLabel;
  final VoidCallback? onDiploma;
  final VoidCallback? onMedal;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= ChallengeCtaPanel.wideFrom;
    return Padding(
      key: const Key('challenge-payment-bar'),
      padding: EdgeInsets.fromLTRB(
        media.left + (wide ? 0 : kNavSideInset),
        0,
        media.right + (wide ? 0 : kNavSideInset),
        ChallengeCtaPanel.bottomMargin(width) + media.bottom,
      ),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          key: const Key('challenge-cta-panel'),
          constraints: BoxConstraints(
            maxWidth: wide ? ChallengeCtaPanel.maxWidth : double.infinity,
          ),
          child: ChallengeCtaPanel(
            heading: heading,
            diplomaLabel: diplomaLabel,
            medalLabel: medalLabel,
            loadingLabel: loadingLabel,
            onDiploma: onDiploma,
            onMedal: onMedal,
          ),
        ),
      ),
    );
  }
}

/// Slide and fade for the floating panel. 220 ms, ease-out cubic.
/// Reduced motion snaps. Hidden panels are not hit-testable.
class ChallengeCtaPanelMotion extends StatelessWidget {
  const ChallengeCtaPanelMotion({
    super.key,
    required this.shown,
    required this.child,
  });

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final ticking = TickerMode.valuesOf(context).enabled;
    final duration = reduce || !ticking
        ? Duration.zero
        : ChallengeCtaPanel.motionDuration;
    return IgnorePointer(
      key: const Key('challenge-cta-motion'),
      ignoring: !shown,
      child: ExcludeSemantics(
        excluding: !shown,
        child: AnimatedSlide(
          offset: shown ? Offset.zero : const Offset(0, 1),
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: child,
          ),
        ),
      ),
    );
  }
}
