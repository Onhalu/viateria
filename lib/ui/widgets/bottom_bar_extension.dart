import 'package:flutter/widgets.dart';

/// Shared slot the challenge detail uses to extend the shell bottom bar.
///
/// [visible] is a [ValueNotifier] so a scroll tick rebuilds only the bar.
/// [content] changes are rare (labels, paid, route) and go through
/// [ChangeNotifier.notifyListeners].
class BottomBarExtensionController extends ChangeNotifier {
  final ValueNotifier<bool> visible = ValueNotifier<bool>(false);

  String? _owner;
  Widget? _content;
  var _disposed = false;

  String? get owner => _owner;
  Widget? get content => _content;

  void publish({required String path, required Widget content}) {
    final changed = _owner != path || !identical(_content, content);
    _owner = path;
    _content = content;
    if (changed) notifyListeners();
  }

  void release(String path) {
    if (_owner != path) return;
    _owner = null;
    _content = null;
    // dispose() runs while the tree is locked. Notify on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (visible.value) visible.value = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    visible.dispose();
    super.dispose();
  }
}

/// Provides [controller] without rebuilding dependents when the slot changes.
///
/// The controller instance is stable. The bottom bar listens to it directly.
class BottomBarExtension extends InheritedWidget {
  const BottomBarExtension({
    super.key,
    required this.controller,
    required super.child,
  });

  final BottomBarExtensionController controller;

  /// Does not subscribe. Scroll updates must not rebuild the detail route.
  static BottomBarExtensionController? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<BottomBarExtension>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(BottomBarExtension oldWidget) =>
      controller != oldWidget.controller;
}
