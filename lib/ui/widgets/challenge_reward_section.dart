import 'package:flutter/material.dart';

import '../../domain/challenge_reward.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';

/// Cream panel with a 1pt beige stroke and 16pt corners.
BoxDecoration challengeBrandPanel() {
  return BoxDecoration(
    color: BrandColors.cream,
    borderRadius: BorderRadius.circular(16),
    border: const Border.fromBorderSide(
      BorderSide(color: BrandColors.beige, width: 1),
    ),
  );
}

class ChallengeDeadlineBanner extends StatelessWidget {
  const ChallengeDeadlineBanner({
    super.key,
    required this.strings,
    required this.locale,
    required this.paid,
    this.completeBy,
  });

  final AppStrings strings;
  final String locale;
  final bool paid;
  final DateTime? completeBy;

  @override
  Widget build(BuildContext context) {
    final showDate = paid && completeBy != null;
    final content = Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 20,
          color: BrandColors.forest,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: showDate
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.deadlineCompleteBy,
                      style: const TextStyle(
                        color: BrandColors.bark,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatLocalDate(completeBy!, locale),
                      key: const Key('challenge-deadline-date'),
                      style: const TextStyle(
                        color: BrandColors.forest,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Text(
                  strings.deadlineAfterPayment,
                  key: const Key('challenge-deadline-unpaid'),
                  style: const TextStyle(
                    color: BrandColors.bark,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ],
    );
    return DecoratedBox(
      key: const Key('challenge-deadline-banner'),
      decoration: challengeBrandPanel(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: showDate ? content : Opacity(opacity: 0.55, child: content),
      ),
    );
  }
}

class ChallengeRewardSection extends StatelessWidget {
  const ChallengeRewardSection({
    super.key,
    required this.strings,
    required this.unlocked,
    required this.paid,
    this.variant,
    this.onSaveDiploma,
  });

  final AppStrings strings;
  final bool unlocked;
  final bool paid;
  final RewardVariant? variant;
  final VoidCallback? onSaveDiploma;

  bool get _showMedalAndDiploma {
    if (variant == null) return true;
    return variant == RewardVariant.medalAndDiploma;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('challenge-reward-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.rewardTitle,
          style: const TextStyle(
            color: BrandColors.forest,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: challengeBrandPanel(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: unlocked ? _unlockedBody() : _lockedBody(),
          ),
        ),
        if (!paid) ...[
          const SizedBox(height: 8),
          Text(
            strings.rewardDependsOnPaidOption,
            key: const Key('challenge-reward-unpaid-hint'),
            style: TextStyle(
              color: BrandColors.bark.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _lockedBody() {
    return AbsorbPointer(
      child: Stack(
        children: [
          Opacity(
            opacity: 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _placeholders(includeLabels: true),
                const SizedBox(height: 12),
                Text(
                  strings.rewardUnlocksAfterComplete,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BrandColors.bark, fontSize: 13),
                ),
              ],
            ),
          ),
          const Positioned(
            top: 0,
            right: 0,
            child: Icon(
              Icons.lock,
              key: Key('challenge-reward-lock'),
              size: 24,
              color: BrandColors.bark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _unlockedBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _placeholders(includeLabels: true, woodenMedal: true),
        const SizedBox(height: 14),
        FilledButton(
          key: const Key('challenge-save-diploma'),
          onPressed: onSaveDiploma,
          style: FilledButton.styleFrom(
            backgroundColor: BrandColors.forest,
            foregroundColor: BrandColors.cream,
          ),
          child: Text(strings.saveDiploma),
        ),
      ],
    );
  }

  Widget _placeholders({
    required bool includeLabels,
    bool woodenMedal = false,
  }) {
    final diploma = _DiplomaPlaceholder(
      label: includeLabels ? strings.diplomaLabel : null,
    );
    if (!_showMedalAndDiploma) return diploma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MedalPlaceholder(
            label: includeLabels ? strings.woodenMedal : null,
            wooden: woodenMedal && unlocked,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: diploma),
      ],
    );
  }
}

class _DiplomaPlaceholder extends StatelessWidget {
  const _DiplomaPlaceholder({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('challenge-reward-diploma'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: BrandColors.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BrandColors.beige),
            ),
            child: const Center(
              child: Icon(
                Icons.description_outlined,
                size: 36,
                color: BrandColors.forest,
              ),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BrandColors.bark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _MedalPlaceholder extends StatelessWidget {
  const _MedalPlaceholder({this.label, this.wooden = false});

  final String? label;
  final bool wooden;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('challenge-reward-medal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: wooden ? BrandColors.beige : BrandColors.cream,
              shape: BoxShape.circle,
              border: Border.all(
                color: wooden ? BrandColors.bark : BrandColors.beige,
                width: wooden ? 3 : 1,
              ),
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              size: 36,
              color: wooden ? BrandColors.bark : BrandColors.forest,
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BrandColors.bark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
