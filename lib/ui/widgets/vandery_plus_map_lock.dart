import 'package:flutter/material.dart';

import '../../data/vandery_plus_session.dart';
import '../../domain/unlock_trigger.dart';
import '../../domain/vandery_plus.dart';
import '../../l10n/app_strings.dart';
import '../../theme/app_button.dart';
import '../../theme/brand_colors.dart';
import 'padlock_unlock.dart';

/// Replaces the map verify chip for a map-only pin.
/// Challenge waypoints do not use this widget (A2).
class MapPlaceVerifyGate extends StatefulWidget {
  const MapPlaceVerifyGate({
    super.key,
    required this.session,
    required this.placeId,
    required this.strings,
    required this.onVerify,
    required this.onLockedTap,
  });

  final VanderyPlusSession session;
  final String placeId;
  final AppStrings strings;
  final VoidCallback onVerify;
  final VoidCallback onLockedTap;

  @override
  State<MapPlaceVerifyGate> createState() => _MapPlaceVerifyGateState();
}

class _MapPlaceVerifyGateState extends State<MapPlaceVerifyGate> {
  var _baseline = false;
  var _sawInactive = false;
  var _animating = false;
  var _unlocked = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _sync(notify: false);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    _sync(notify: true);
  }

  /// The first resolved snapshot is the baseline. Login that is already
  /// active opens the verify chip with no padlock animation. A later change
  /// from inactive to active is the only play.
  void _sync({required bool notify}) {
    void apply(VoidCallback change) {
      if (notify) {
        setState(change);
      } else {
        change();
      }
    }

    if (!widget.session.resolved) {
      if (notify) setState(() {});
      return;
    }
    final active = widget.session.isActive;
    if (!_baseline) {
      apply(() {
        _baseline = true;
        if (active) {
          _unlocked = true;
        } else {
          _sawInactive = true;
        }
      });
      return;
    }
    if (!active) {
      apply(() {
        _sawInactive = true;
        _animating = false;
        _unlocked = false;
      });
      return;
    }
    if (!_sawInactive || _unlocked || _animating) {
      if (notify) setState(() {});
      return;
    }
    if (!playsUnlockAnimation(UnlockTrigger.serverMembershipActive)) return;
    if (widget.session.phase == VanderyPlusPhase.verifying) {
      if (notify) setState(() {});
      return;
    }
    if (!unlockReplayMemory.claim(membershipUnlockEntity)) {
      apply(() => _unlocked = true);
      return;
    }
    apply(() => _animating = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked && widget.session.isActive) {
      return AppButton(
        key: const Key('map-poi-verify'),
        label: widget.strings.verify,
        size: AppButtonSize.m,
        onPressed: widget.onVerify,
      );
    }
    if (_animating) {
      return SizedBox(
        height: 44,
        child: Center(
          child: PadlockUnlock(
            key: const Key('map-place-unlock'),
            play: true,
            glyph: 20,
            lockedLabel: widget.strings.vanderyPlusLocked,
            unlockedLabel: widget.strings.vanderyPlusUnlocked,
            onCompleted: () {
              if (!mounted) return;
              setState(() {
                _animating = false;
                _unlocked = true;
              });
              widget.onVerify();
            },
          ),
        ),
      );
    }
    final verifying = widget.session.phase == VanderyPlusPhase.verifying;
    return Semantics(
      button: true,
      label: widget.strings.vanderyPlusMapLock,
      child: SizedBox(
        key: const Key('map-place-lock'),
        height: 44,
        width: double.infinity,
        child: Material(
          color: BrandColors.neutral,
          shape: const StadiumBorder(
            side: BorderSide(color: BrandColors.forest, width: 2),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: verifying ? null : widget.onLockedTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                  width: 32,
                  height: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: BrandColors.cream,
                      shape: BoxShape.circle,
                      border: Border.all(color: BrandColors.forest, width: 2),
                    ),
                    child: Center(
                      child: PadlockUnlock(
                        play: false,
                        glyph: 18,
                        lockedLabel: widget.strings.vanderyPlusLocked,
                        unlockedLabel: widget.strings.vanderyPlusUnlocked,
                      ),
                    ),
                  ),
                ),
                ),
                if (verifying) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.strings.vanderyPlusVerifying,
                      key: const Key('map-place-verifying'),
                      style: const TextStyle(color: BrandColors.forest),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
