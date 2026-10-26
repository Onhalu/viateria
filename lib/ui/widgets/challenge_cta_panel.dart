import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'app_shell.dart';

/// How the nav fill should pair with the payment buttons.
enum NavFillTone { light, mid, dark }

/// Relative luminance threshold. Forest sits under [darkAt]; cream sits over
/// [lightAt]. Olive `#7D8B6A` and sage fall in the middle.
const navFillDarkLuminance = 0.15;
const navFillLightLuminance = 0.55;

NavFillTone navFillTone(Color color) {
  final luminance = color.computeLuminance();
  if (luminance >= navFillLightLuminance) return NavFillTone.light;
  if (luminance <= navFillDarkLuminance) return NavFillTone.dark;
  return NavFillTone.mid;
}

/// WCAG contrast ratio. 1 is identical, 21 is black on white.
double contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance();
  final darker = background.computeLuminance();
  final hi = lighter > darker ? lighter : darker;
  final lo = lighter > darker ? darker : lighter;
  return (hi + 0.05) / (lo + 0.05);
}

/// Button and heading colours for one nav fill.
///
/// Labels are forest-on-cream or cream-on-forest. Sage is never a fill or a
/// label. The heading is the on-nav colour that clears 3:1.
@immutable
class ChallengeCtaChrome {
  const ChallengeCtaChrome({
    required this.fill,
    required this.tone,
    required this.heading,
    required this.hairline,
    required this.medalFill,
    required this.medalLabel,
    required this.medalSide,
    required this.diplomaFill,
    required this.diplomaLabel,
    required this.diplomaSide,
  });

  final Color fill;
  final NavFillTone tone;
  final Color heading;
  final Color hairline;
  final Color medalFill;
  final Color medalLabel;
  final BorderSide medalSide;
  final Color diplomaFill;
  final Color diplomaLabel;
  final BorderSide diplomaSide;

  static const medalOutlineAlpha = 0.30;
  static const hairlineAlpha = 0.18;

  factory ChallengeCtaChrome.resolve(Color nav) {
    final fill = _opaqueFill(nav);
    final tone = navFillTone(fill);
    final heading = _heading(fill);
    final hairline = heading.withValues(alpha: hairlineAlpha);
    final forestSide = const BorderSide(color: BrandColors.forest, width: 1.5);
    final creamSide = BorderSide(
      color: BrandColors.cream.withValues(alpha: medalOutlineAlpha),
      width: 1,
    );
    final creamOutline = const BorderSide(color: BrandColors.cream, width: 1.5);
    return switch (tone) {
      NavFillTone.mid => ChallengeCtaChrome(
        fill: fill,
        tone: tone,
        heading: heading,
        hairline: hairline,
        medalFill: BrandColors.forest,
        medalLabel: BrandColors.cream,
        medalSide: creamSide,
        diplomaFill: BrandColors.cream,
        diplomaLabel: BrandColors.forest,
        diplomaSide: forestSide,
      ),
      NavFillTone.light => ChallengeCtaChrome(
        fill: fill,
        tone: tone,
        heading: heading,
        hairline: hairline,
        medalFill: BrandColors.forest,
        medalLabel: BrandColors.cream,
        medalSide: BorderSide.none,
        diplomaFill: BrandColors.cream,
        diplomaLabel: BrandColors.forest,
        diplomaSide: forestSide,
      ),
      NavFillTone.dark => ChallengeCtaChrome(
        fill: fill,
        tone: tone,
        heading: heading,
        hairline: hairline,
        medalFill: BrandColors.cream,
        medalLabel: BrandColors.forest,
        medalSide: BorderSide.none,
        diplomaFill: Colors.transparent,
        diplomaLabel: BrandColors.cream,
        diplomaSide: creamOutline,
      ),
    };
  }

  static Color _opaqueFill(Color nav) {
    if (nav.a >= 0.96) return nav;
    return nav.withValues(alpha: 0.96);
  }

  static Color _heading(Color fill) {
    final cream = contrastRatio(BrandColors.cream, fill);
    final forest = contrastRatio(BrandColors.forest, fill);
    final tone = navFillTone(fill);
    if (tone == NavFillTone.light && forest >= 3) return BrandColors.forest;
    if (tone != NavFillTone.light && cream >= 3) return BrandColors.cream;
    if (forest >= 3 && forest >= cream) return BrandColors.forest;
    if (cream >= 3) return BrandColors.cream;
    return forest >= cream ? BrandColors.forest : BrandColors.cream;
  }
}

/// Payment actions that grow out of the bottom nav.
///
/// The shell paints the shared fill, radius, and shadow. This widget is only
/// the heading, the buttons, and the hairline above the nav items.
class ChallengeCtaPanel extends StatelessWidget {
  const ChallengeCtaPanel({
    super.key,
    required this.heading,
    required this.diplomaLabel,
    required this.medalLabel,
    required this.onDiploma,
    required this.onMedal,
    this.loadingLabel = 'Načítání',
    this.navFill = BrandColors.shellFill,
  });

  final String heading;
  final String diplomaLabel;
  final String medalLabel;
  final VoidCallback? onDiploma;
  final VoidCallback? onMedal;
  final String loadingLabel;
  final Color navFill;

  static const topRadius = 24.0;
  static const padHorizontal = kNavSideInset;
  static const padTop = 16.0;
  static const padAboveHairline = 12.0;
  static const headingGap = 12.0;
  static const headingSize = 20.0;
  static const headingLineHeight = 26.0;
  static const rowGap = 12.0;
  static const stackGap = 8.0;
  static const stackBelow = 340.0;
  static const contentMaxWidth = 560.0;
  static const buttonHeight = 48.0;
  static const hairlineInset = 20.0;
  static const hairlineThickness = 1.0;
  static const showDuration = Duration(milliseconds: 240);
  static const hideDuration = Duration(milliseconds: 180);
  static const headingLines = 2;

  /// One upward shadow for the whole nav container. Forest at about 12%.
  static const mergedShadow = BoxShadow(
    color: Color(0x1F35483C),
    blurRadius: 24,
    offset: Offset(0, -4),
  );

  static bool buttonsStack(double windowWidth) => windowWidth < stackBelow;

  static double _buttonsHeight(double windowWidth) => buttonsStack(windowWidth)
      ? buttonHeight + stackGap + buttonHeight
      : buttonHeight;

  /// Laid-out height of the panel body, including the hairline.
  static double bodyHeight(double windowWidth, {int headingLines = 1}) =>
      padTop +
      headingLineHeight * headingLines +
      headingGap +
      _buttonsHeight(windowWidth) +
      padAboveHairline +
      hairlineThickness;

  @override
  Widget build(BuildContext context) {
    final chrome = ChallengeCtaChrome.resolve(navFill);
    final width = MediaQuery.sizeOf(context).width;
    final stack = buttonsStack(width);
    final diploma = AppButton(
      key: const Key('challenge-floating-pay-diploma'),
      label: diplomaLabel,
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.m,
      loadingLabel: loadingLabel,
      onPressed: onDiploma,
      background: chrome.diplomaFill,
      foreground: chrome.diplomaLabel,
      side: chrome.diplomaSide,
    );
    final medal = AppButton(
      key: const Key('challenge-floating-pay-medal'),
      label: medalLabel,
      variant: AppButtonVariant.primary,
      size: AppButtonSize.m,
      loadingLabel: loadingLabel,
      onPressed: onMedal,
      background: chrome.medalFill,
      foreground: chrome.medalLabel,
      side: chrome.medalSide,
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
    return Column(
      key: const Key('challenge-cta-panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          key: const Key('challenge-cta-padding'),
          padding: const EdgeInsets.fromLTRB(
            padHorizontal,
            padTop,
            padHorizontal,
            padAboveHairline,
          ),
          child: Center(
            child: ConstrainedBox(
              key: const Key('challenge-cta-content'),
              constraints: const BoxConstraints(maxWidth: contentMaxWidth),
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
                      color: chrome.heading,
                    ),
                  ),
                  const SizedBox(height: headingGap),
                  buttons,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: hairlineInset),
          child: ColoredBox(
            key: const Key('challenge-cta-hairline'),
            color: chrome.hairline,
            child: const SizedBox(height: hairlineThickness, width: double.infinity),
          ),
        ),
      ],
    );
  }
}

/// Desktop payment card. Used from 840 dp, where the shell is a rail.
class ChallengeStickyCta extends StatelessWidget {
  const ChallengeStickyCta({
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

  static const width = 340.0;
  static const buttonGap = 12.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('challenge-sticky-cta'),
      color: BrandColors.cream,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BrandColors.beige),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              heading,
              key: const Key('challenge-sticky-heading'),
              textAlign: TextAlign.center,
              style: BrandTypography.display(
                fontSize: ChallengeCtaPanel.headingSize,
                height:
                    ChallengeCtaPanel.headingLineHeight /
                    ChallengeCtaPanel.headingSize,
                color: BrandColors.forest,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              key: const Key('challenge-sticky-pay-medal'),
              label: medalLabel,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.l,
              loadingLabel: loadingLabel,
              onPressed: onMedal,
            ),
            const SizedBox(height: buttonGap),
            AppButton(
              key: const Key('challenge-sticky-pay-diploma'),
              label: diplomaLabel,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.l,
              loadingLabel: loadingLabel,
              onPressed: onDiploma,
            ),
          ],
        ),
      ),
    );
  }
}

/// Grows the panel upward from the nav and fades its contents.
///
/// Show is 240 ms ease-out cubic. Hide is 180 ms ease-in cubic. Reduced
/// motion and a disabled ticker snap. The radius is not animated here.
class ChallengeCtaPanelMotion extends StatefulWidget {
  const ChallengeCtaPanelMotion({
    super.key,
    required this.shown,
    required this.child,
    this.onExtent,
  });

  final bool shown;
  final Widget child;

  /// Current size factor, 0 when closed and 1 when open.
  final ValueChanged<double>? onExtent;

  @override
  State<ChallengeCtaPanelMotion> createState() => _ChallengeCtaPanelMotionState();
}

class _ChallengeCtaPanelMotionState extends State<ChallengeCtaPanelMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: widget.shown ? 1 : 0,
      duration: ChallengeCtaPanel.showDuration,
      reverseDuration: ChallengeCtaPanel.hideDuration,
    );
    _controller.addListener(_notifyExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyExtent();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion && _controller.value != _target) {
      _controller.value = _target;
    }
  }

  @override
  void didUpdateWidget(ChallengeCtaPanelMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shown != widget.shown) _animate();
  }

  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      !TickerMode.valuesOf(context).enabled;

  double get _target => widget.shown ? 1 : 0;

  void _notifyExtent() => widget.onExtent?.call(_controller.value);

  void _animate() {
    if (_reduceMotion) {
      _controller.value = _target;
      return;
    }
    if (widget.shown) {
      _controller.animateTo(
        1,
        duration: ChallengeCtaPanel.showDuration,
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.animateTo(
        0,
        duration: ChallengeCtaPanel.hideDuration,
        curve: Curves.easeInCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_notifyExtent);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      key: const Key('challenge-cta-motion'),
      ignoring: !widget.shown,
      child: ExcludeSemantics(
        excluding: !widget.shown,
        child: ExcludeFocus(
          excluding: !widget.shown,
          child: SizeTransition(
            key: const Key('challenge-cta-size'),
            alignment: Alignment.bottomCenter,
            sizeFactor: _controller,
            child: FadeTransition(opacity: _controller, child: widget.child),
          ),
        ),
      ),
    );
  }
}
