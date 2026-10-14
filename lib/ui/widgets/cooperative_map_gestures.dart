import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// One finger scrolls the parent. Two fingers reach the map.
///
/// Only [PointerDeviceKind.touch] is counted. Mouse, trackpad, and taps
/// pass through so markers stay clickable.
class CooperativeMapGestures extends StatefulWidget {
  const CooperativeMapGestures({super.key, required this.child});

  final Widget child;

  @override
  State<CooperativeMapGestures> createState() => CooperativeMapGesturesState();
}

class CooperativeMapGesturesState extends State<CooperativeMapGestures> {
  var _touchPointers = 0;

  void _down(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    setState(() => _touchPointers++);
  }

  void _up(PointerEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    setState(() => _touchPointers = (_touchPointers - 1).clamp(0, 16));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: IgnorePointer(
        ignoring: cooperativeMapIgnoresChild(_touchPointers),
        child: widget.child,
      ),
    );
  }
}

/// Ignore the map only while a single touch finger is down.
bool cooperativeMapIgnoresChild(int touchPointers) =>
    touchPointers > 0 && touchPointers < 2;

/// Wheel zoom is always on for touch devices. On the web it needs Ctrl.
bool mapWheelZoomEnabled({
  required bool isWeb,
  required bool controlPressed,
  bool enabled = true,
}) {
  if (!enabled) return false;
  if (!isWeb) return true;
  return controlPressed;
}
