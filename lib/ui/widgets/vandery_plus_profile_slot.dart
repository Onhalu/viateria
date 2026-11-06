import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/brand_colors.dart';

/// LOCK A: directly under `profile-leaderboard`.
class VanderyPlusProfileSlot extends StatelessWidget {
  const VanderyPlusProfileSlot({
    super.key,
    required this.strings,
    required this.active,
    required this.onJoin,
  });

  final AppStrings strings;
  final bool active;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: active
          ? _MemberBadge(strings: strings)
          : _JoinButton(label: strings.vanderyPlusJoinCta, onPressed: onJoin),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        key: const Key('vandery-plus-cta'),
        width: double.infinity,
        height: 52,
        child: Material(
          color: BrandColors.forest,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BrandColors.cream,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: BrandColors.sage,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '+',
                      style: TextStyle(
                        color: BrandColors.cream,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberBadge extends StatelessWidget {
  const _MemberBadge({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            key: const Key('vandery-plus-badge'),
            decoration: const BoxDecoration(
              color: BrandColors.forest,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 28,
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(
                    strings.vanderyPlusBadge,
                    style: const TextStyle(
                      color: BrandColors.cream,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.vanderyPlusActiveLine,
            key: const Key('vandery-plus-active-line'),
            style: const TextStyle(color: BrandColors.bark, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

