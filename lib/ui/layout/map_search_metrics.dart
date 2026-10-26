import 'dart:math' as math;

/// Resting and focused width of the map search field.
double mapSearchFieldWidth({
  required double viewportWidth,
  required double slotWidth,
  required double margin,
  required double controlsWidth,
  required bool focused,
}) {
  if (focused) return math.max(0, slotWidth);
  if (viewportWidth >= 600) {
    return math.min(slotWidth, math.min(viewportWidth * 0.5, 360));
  }
  final cap = viewportWidth - 2 * margin - controlsWidth;
  if (cap <= 0) return 0;
  if (cap < 200) return cap;
  return math.min(slotWidth, cap);
}

/// Show the pay bar after half a viewport. Hide only once the offset falls
/// below 0.4 × viewport, so a small reverse scroll does not flicker.
bool paymentBarShouldShow({
  required bool currentlyVisible,
  required double offset,
  required double viewport,
}) {
  if (viewport <= 0) return currentlyVisible;
  final showAt = viewport * 0.5;
  final hideAt = viewport * 0.4;
  return currentlyVisible ? offset >= hideAt : offset >= showAt;
}
