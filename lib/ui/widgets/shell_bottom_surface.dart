import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/brand_colors.dart';
import 'app_shell.dart';
import 'challenge_cta_panel.dart';

/// One painted surface for the bottom nav and the optional payment panel.
///
/// Closed, the pill matches the resting nav: radius 28, elevation 3. Open,
/// the top corners are 24, the bottom corners stay 28, and a single upward
/// shadow replaces the elevation. The radius snaps; only the height animates.
class ShellBottomSurface extends StatefulWidget {
  const ShellBottomSurface({
    super.key,
    required this.nav,
    this.panel,
    this.shown = false,
  });

  final Widget nav;
  final Widget? panel;
  final bool shown;

  @override
  State<ShellBottomSurface> createState() => _ShellBottomSurfaceState();
}

class _ShellBottomSurfaceState extends State<ShellBottomSurface> {
  var _open = false;

  void _onExtent(double factor) {
    final open = factor > 0;
    if (open == _open) return;
    // Reduced motion sets the controller value during build. Defer the
    // radius snap until the frame finishes.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || open == _open) return;
        setState(() => _open = open);
      });
      return;
    }
    setState(() => _open = open);
  }

  @override
  Widget build(BuildContext context) {
    final open = _open && widget.panel != null;
    final radius = open
        ? const BorderRadius.only(
            topLeft: Radius.circular(ChallengeCtaPanel.topRadius),
            topRight: Radius.circular(ChallengeCtaPanel.topRadius),
            bottomLeft: Radius.circular(AppShell.barRadius),
            bottomRight: Radius.circular(AppShell.barRadius),
          )
        : BorderRadius.circular(AppShell.barRadius);
    final material = Material(
      key: const Key('app-bottom-nav-shell'),
      elevation: open ? 0 : 3,
      color: BrandColors.shellFill,
      shadowColor: BrandColors.shellShadow,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.panel != null)
            ChallengeCtaPanelMotion(
              shown: widget.shown,
              onExtent: _onExtent,
              child: widget.panel!,
            ),
          widget.nav,
        ],
      ),
    );
    // The decorated box stays in the tree so opening the panel does not
    // recreate the motion. A closed bar has no shadow.
    final surface = DecoratedBox(
      key: const Key('shell-bottom-shadow'),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: open ? const [ChallengeCtaPanel.mergedShadow] : const [],
      ),
      child: material,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kNavSideInset,
          AppShell.topInset,
          kNavSideInset,
          AppShell.bottomInset,
        ),
        child: surface,
      ),
    );
  }
}
