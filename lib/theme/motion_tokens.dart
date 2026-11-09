import 'package:flutter/animation.dart';

/// Shared timings for the motion-polish brand lock.
///
/// Each spec band is pinned to one value so every surface agrees.
abstract final class MotionTokens {
  /// Tap feedback (like / save). Spec band 150–220 ms.
  static const fast = Duration(milliseconds: 200);

  /// Toggle spring. Spec band 200–280 ms.
  static const switchMotion = Duration(milliseconds: 240);

  /// Bottom-nav pill travel. Spec band 250–300 ms.
  static const tab = Duration(milliseconds: 280);

  /// Input-error shake.
  static const shake = Duration(milliseconds: 400);

  /// Row-dismiss size. Spec band 200–280 ms.
  /// No swipe-delete list exists yet; the token is here for that surface.
  static const list = Duration(milliseconds: 240);

  /// Overflow-menu enter. Spec band 180–220 ms.
  static const menu = Duration(milliseconds: 200);

  static const tabCurve = Curves.easeInOutCubic;

  /// Horizontal error shake, in px. Spec band ±6–8.
  static const shakeAmplitude = 7.0;

  /// Full sine cycles inside [shake]. Spec band 3–4.
  static const shakeOscillations = 3.5;

  static const likeScaleDown = 0.92;
  static const likeScaleUp = 1.08;

  /// Sage dots on a like. Spec band 6–8. Never used outside like / save.
  static const burstDots = 7;

  /// Burst radius as a multiple of the icon. Spec band 1.2–1.5.
  static const burstRadiusFactor = 1.35;

  /// Switch-thumb travel overshoot. Spec band 10–15%.
  static const switchOvershoot = 0.12;

  /// Horizontal thumb stretch while the spring is moving.
  static const stretchScale = 1.12;

  /// Menu scale at the first frame, before it reaches 1.
  static const menuScaleFrom = 0.96;

  /// Damping whose step response overshoots by about [switchOvershoot].
  static const switchDampingRatio = 0.56;

  /// Stiffness chosen so the switch spring settles near [switchMotion].
  static const switchStiffness = 900.0;
}
