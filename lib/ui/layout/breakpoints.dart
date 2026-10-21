import 'package:flutter/widgets.dart';

/// Window size classes from the UX audit.
///
/// compact &lt; 600, medium 600–839, expanded 840–1199, large ≥ 1200.
enum WindowClass { compact, medium, expanded, large }

abstract final class Breakpoints {
  static const compactMax = 600.0;
  static const mediumMax = 840.0;
  static const expandedMax = 1200.0;

  static const catalogMaxWidth = 1200.0;
  static const profileMaxWidth = 640.0;
  static const authMaxWidth = 440.0;
  static const detailTextMaxWidth = 720.0;

  static WindowClass ofWidth(double width) {
    if (width < compactMax) return WindowClass.compact;
    if (width < mediumMax) return WindowClass.medium;
    if (width < expandedMax) return WindowClass.expanded;
    return WindowClass.large;
  }

  /// Floating bottom nav only on a compact (phone portrait) window.
  static bool usesNavigationRail(double width) => width >= compactMax;

  /// Challenge detail from 840 dp: the map stays in a side column, and the
  /// description plus the payment block sit under that map.
  static bool challengeTwoColumn(double width) => width >= mediumMax;

  /// Catalog result grid: 1 / 2 / 3 columns.
  static int catalogColumns(double width) {
    if (width >= 1024) return 3;
    if (width >= compactMax) return 2;
    return 1;
  }
}

/// Centers [child] and caps its width. Wider windows keep the side gutters.
class AppContentWidth extends StatelessWidget {
  const AppContentWidth({
    super.key,
    required this.maxWidth,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final double maxWidth;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
