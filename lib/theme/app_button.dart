import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'brand_colors.dart';

/// L 52 / M 44 / S 36, plus the gaps shared by button pairs.
class AppButtonSizes extends ThemeExtension<AppButtonSizes> {
  const AppButtonSizes({
    this.lHeight = 52,
    this.lLabel = 16,
    this.lPadH = 24,
    this.mHeight = 44,
    this.mLabel = 15,
    this.mPadH = 20,
    this.sHeight = 36,
    this.sLabel = 14,
    this.sPadH = 16,
    this.iconSize = 18,
    this.iconGap = 8,
    this.gapPair = 12,
    this.gapFloating = 32,
  });

  final double lHeight;
  final double lLabel;
  final double lPadH;
  final double mHeight;
  final double mLabel;
  final double mPadH;
  final double sHeight;
  final double sLabel;
  final double sPadH;
  final double iconSize;
  final double iconGap;
  final double gapPair;
  final double gapFloating;

  static const standard = AppButtonSizes();

  ({double height, double label, double padH}) resolve(AppButtonSize size) {
    return switch (size) {
      AppButtonSize.l => (height: lHeight, label: lLabel, padH: lPadH),
      AppButtonSize.m => (height: mHeight, label: mLabel, padH: mPadH),
      AppButtonSize.s => (height: sHeight, label: sLabel, padH: sPadH),
    };
  }

  @override
  AppButtonSizes copyWith({
    double? lHeight,
    double? lLabel,
    double? lPadH,
    double? mHeight,
    double? mLabel,
    double? mPadH,
    double? sHeight,
    double? sLabel,
    double? sPadH,
    double? iconSize,
    double? iconGap,
    double? gapPair,
    double? gapFloating,
  }) {
    return AppButtonSizes(
      lHeight: lHeight ?? this.lHeight,
      lLabel: lLabel ?? this.lLabel,
      lPadH: lPadH ?? this.lPadH,
      mHeight: mHeight ?? this.mHeight,
      mLabel: mLabel ?? this.mLabel,
      mPadH: mPadH ?? this.mPadH,
      sHeight: sHeight ?? this.sHeight,
      sLabel: sLabel ?? this.sLabel,
      sPadH: sPadH ?? this.sPadH,
      iconSize: iconSize ?? this.iconSize,
      iconGap: iconGap ?? this.iconGap,
      gapPair: gapPair ?? this.gapPair,
      gapFloating: gapFloating ?? this.gapFloating,
    );
  }

  @override
  AppButtonSizes lerp(AppButtonSizes? other, double t) {
    if (other == null) return this;
    double mix(double a, double b) => a + (b - a) * t;
    return AppButtonSizes(
      lHeight: mix(lHeight, other.lHeight),
      lLabel: mix(lLabel, other.lLabel),
      lPadH: mix(lPadH, other.lPadH),
      mHeight: mix(mHeight, other.mHeight),
      mLabel: mix(mLabel, other.mLabel),
      mPadH: mix(mPadH, other.mPadH),
      sHeight: mix(sHeight, other.sHeight),
      sLabel: mix(sLabel, other.sLabel),
      sPadH: mix(sPadH, other.sPadH),
      iconSize: mix(iconSize, other.iconSize),
      iconGap: mix(iconGap, other.iconGap),
      gapPair: mix(gapPair, other.gapPair),
      gapFloating: mix(gapFloating, other.gapFloating),
    );
  }
}

enum AppButtonVariant { primary, secondary, tertiary, tonal }

enum AppButtonSize { l, m, s }

/// Contact shadow (forest at 20%) plus, when [floating], the 12 dp lift.
List<BoxShadow> appButtonShadows({required bool floating}) {
  final contact = BoxShadow(
    color: BrandColors.forest.withValues(alpha: 0x33 / 255),
    blurRadius: 2,
    offset: const Offset(0, 1),
  );
  if (!floating) return [contact];
  return [
    BoxShadow(
      color: BrandColors.forest.withValues(alpha: 0x29 / 255),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    contact,
  ];
}

ButtonStyle appButtonStyle({
  required AppButtonVariant variant,
  required AppButtonSize size,
  AppButtonSizes sizes = AppButtonSizes.standard,
  bool selected = false,
  bool loading = false,
}) {
  final metrics = sizes.resolve(size);
  final padH = variant == AppButtonVariant.tertiary ? 12.0 : metrics.padH;
  final label = metrics.label < 14 ? 14.0 : metrics.label;
  return ButtonStyle(
    animationDuration: const Duration(milliseconds: 120),
    minimumSize: WidgetStatePropertyAll(Size(64, metrics.height)),
    tapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: padH),
    ),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    splashFactory: NoSplash.splashFactory,
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    textStyle: WidgetStatePropertyAll(
      TextStyle(
        fontSize: label,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.1,
      ),
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => _background(
        variant,
        states,
        selected: selected,
        loading: loading,
      ),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => _foreground(
        variant,
        states,
        selected: selected,
        loading: loading,
      ),
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) => _overlay(
        variant,
        states,
        loading: loading,
        selected: selected,
      ),
    ),
    side: WidgetStateProperty.resolveWith((states) {
      if (variant != AppButtonVariant.secondary) return BorderSide.none;
      final disabled = !loading && states.contains(WidgetState.disabled);
      return BorderSide(
        color: BrandColors.forest.withValues(alpha: disabled ? 0.4 : 1),
        width: 1.5,
      );
    }),
    iconSize: WidgetStatePropertyAll(sizes.iconSize),
  );
}

Color _background(
  AppButtonVariant variant,
  Set<WidgetState> states, {
  required bool selected,
  required bool loading,
}) {
  final disabled = !loading && states.contains(WidgetState.disabled);
  switch (variant) {
    case AppButtonVariant.primary:
      final fill = disabled
          ? BrandColors.forest.withValues(alpha: 0.4)
          : BrandColors.forest;
      return fill;
    case AppButtonVariant.secondary:
      return disabled
          ? BrandColors.cream.withValues(alpha: 0.4)
          : BrandColors.cream;
    case AppButtonVariant.tertiary:
      return Colors.transparent;
    case AppButtonVariant.tonal:
      if (selected) return BrandColors.forest;
      return disabled
          ? BrandColors.beige.withValues(alpha: 0.4)
          : BrandColors.beige;
  }
}

Color _foreground(
  AppButtonVariant variant,
  Set<WidgetState> states, {
  required bool selected,
  required bool loading,
}) {
  final disabled = !loading && states.contains(WidgetState.disabled);
  final hot =
      states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.pressed);
  switch (variant) {
    case AppButtonVariant.primary:
      return disabled
          ? BrandColors.cream.withValues(alpha: 0.7)
          : BrandColors.cream;
    case AppButtonVariant.secondary:
      return BrandColors.forest.withValues(alpha: disabled ? 0.4 : 1);
    case AppButtonVariant.tertiary:
      if (disabled) return BrandColors.bark.withValues(alpha: 0.4);
      return hot ? BrandColors.forest : BrandColors.bark;
    case AppButtonVariant.tonal:
      if (selected) return BrandColors.cream;
      return BrandColors.forest.withValues(alpha: disabled ? 0.4 : 1);
  }
}

Color? _overlay(
  AppButtonVariant variant,
  Set<WidgetState> states, {
  required bool loading,
  required bool selected,
}) {
  if (loading || states.contains(WidgetState.disabled)) {
    return Colors.transparent;
  }
  final pressed = states.contains(WidgetState.pressed);
  final hovered = states.contains(WidgetState.hovered);
  switch (variant) {
    case AppButtonVariant.primary:
      if (pressed) return BrandColors.cream.withValues(alpha: 0.12);
      if (hovered) return BrandColors.cream.withValues(alpha: 0.08);
      return Colors.transparent;
    case AppButtonVariant.secondary:
      if (pressed) return BrandColors.forest.withValues(alpha: 0.10);
      return Colors.transparent;
    case AppButtonVariant.tertiary:
      if (pressed || hovered) return BrandColors.forest.withValues(alpha: 0.08);
      return Colors.transparent;
    case AppButtonVariant.tonal:
      if (pressed || hovered) {
        return (selected ? BrandColors.cream : BrandColors.forest).withValues(
          alpha: 0.08,
        );
      }
      return Colors.transparent;
  }
}

/// Forest fill, cream label, or one of the quieter variants.
///
/// The label is sans, weight 600, one line, and scales down inside the
/// button. It is never set below 14 sp. Playfair is not used.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.m,
    this.loading = false,
    this.icon,
    this.selected = false,
    this.elevated = false,
    this.loadingLabel = 'Načítání',
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final IconData? icon;
  final bool selected;

  /// Floating pair: both variants get the lift shadow plus the contact shadow.
  final bool elevated;
  final String loadingLabel;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  final _states = WidgetStatesController();
  var _deferring = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_onStates);
  }

  /// The inner button writes this controller during its own build. Rebuilding
  /// this state in that moment dirties the element that is already mounting.
  void _onStates() {
    final phase = WidgetsBinding.instance.schedulerPhase;
    final inBuild =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!inBuild) {
      if (mounted) setState(() {});
      return;
    }
    if (_deferring) return;
    _deferring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deferring = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _states.removeListener(_onStates);
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizes =
        Theme.of(context).extension<AppButtonSizes>() ?? AppButtonSizes.standard;
    final metrics = sizes.resolve(widget.size);
    final labelSize = metrics.label < 14 ? 14.0 : metrics.label;
    final style = appButtonStyle(
      variant: widget.variant,
      size: widget.size,
      sizes: sizes,
      selected: widget.selected,
      loading: widget.loading,
    );
    final enabled = widget.onPressed != null && !widget.loading;
    final spinnerColor = _foreground(
      widget.variant,
      const {},
      selected: widget.selected,
      loading: true,
    );
    final caption = Text(
      widget.label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: labelSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.1,
      ),
    );
    final Widget content = FittedBox(
      fit: BoxFit.scaleDown,
      child: widget.icon == null
          ? caption
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: sizes.iconSize),
                SizedBox(width: sizes.iconGap),
                caption,
              ],
            ),
    );
    final Widget child = widget.loading
        ? Stack(
            alignment: Alignment.center,
            children: [
              ExcludeSemantics(child: Opacity(opacity: 0, child: content)),
              Semantics(
                label: widget.loadingLabel,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: spinnerColor,
                  ),
                ),
              ),
            ],
          )
        : content;
    final Widget button = switch (widget.variant) {
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: enabled ? widget.onPressed : null,
        style: style,
        statesController: _states,
        child: child,
      ),
      AppButtonVariant.tertiary => TextButton(
        onPressed: enabled ? widget.onPressed : null,
        style: style,
        statesController: _states,
        child: child,
      ),
      AppButtonVariant.primary || AppButtonVariant.tonal => FilledButton(
        onPressed: enabled ? widget.onPressed : null,
        style: style,
        statesController: _states,
        child: child,
      ),
    };
    final states = _states.value;
    final pressed = states.contains(WidgetState.pressed);
    final focused = states.contains(WidgetState.focused);
    final showShadow =
        !pressed &&
        enabled &&
        (widget.elevated || widget.variant == AppButtonVariant.primary);
    Widget current = button;
    if (showShadow) {
      current = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: appButtonShadows(floating: widget.elevated),
        ),
        child: current,
      );
    }
    if (focused && enabled) {
      current = _FocusRing(child: current);
    }
    if (pressed && enabled && widget.variant == AppButtonVariant.primary) {
      current = Transform.translate(
        offset: const Offset(0, 1),
        child: current,
      );
    }
    return current;
  }
}

class _FocusRing extends StatelessWidget {
  const _FocusRing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -4,
          top: -4,
          right: -4,
          bottom: -4,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: StadiumBorder(
                  side: BorderSide(color: BrandColors.sage, width: 2),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Theme styles for the Material buttons that are not [AppButton].
abstract final class AppButtonThemes {
  static const _duration = Duration(milliseconds: 120);

  static ButtonStyle filled(AppButtonSizes sizes) {
    return appButtonStyle(
      variant: AppButtonVariant.primary,
      size: AppButtonSize.m,
      sizes: sizes,
    );
  }

  static ButtonStyle outlined(AppButtonSizes sizes) {
    return appButtonStyle(
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.m,
      sizes: sizes,
    );
  }

  static ButtonStyle text(AppButtonSizes sizes) {
    return appButtonStyle(
      variant: AppButtonVariant.tertiary,
      size: AppButtonSize.m,
      sizes: sizes,
    );
  }

  static ButtonStyle icon() {
    return ButtonStyle(
      animationDuration: _duration,
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      fixedSize: const WidgetStatePropertyAll(Size(48, 48)),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconSize: const WidgetStatePropertyAll(24),
      elevation: const WidgetStatePropertyAll(0),
      shape: const WidgetStatePropertyAll(CircleBorder()),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BrandColors.forest.withValues(alpha: 0.4);
        }
        return BrandColors.forest;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered)) {
          return BrandColors.forest.withValues(alpha: 0.08);
        }
        return Colors.transparent;
      }),
    );
  }
}
