import 'dart:ui';

import 'package:flutter/material.dart';

import '../../data/diploma_client.dart';
import '../../domain/challenge_reward.dart';
import '../../l10n/app_strings.dart';
import '../../theme/brand_colors.dart';
import '../diploma_share.dart';

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
    required this.completed,
    required this.entitled,
    required this.locked,
    this.challengeId,
    this.diplomas,
    this.hasDisplayName = true,
    this.onSaveDiploma,
  });

  static const double panelRadius = 16;

  final AppStrings strings;
  final bool completed;
  final bool entitled;

  /// Paywall over the whole card. Free, zero-price, and paid purchases
  /// leave this false — the same payment rule as [ChallengeReward.isRewardAccessible].
  final bool locked;
  final String? challengeId;
  final DiplomaClient? diplomas;
  final bool hasDisplayName;
  final VoidCallback? onSaveDiploma;

  bool get _blurPreview => completed && !entitled;

  /// Generated diploma when the server file is not on screen: locked,
  /// completed but unpaid, and every other not-yet-entitled card (free
  /// challenges and unlocked challenges that are not finished).
  bool get _texturedDiploma => locked || !entitled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(panelRadius);
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
        ClipRRect(
          key: const Key('challenge-reward-clip'),
          borderRadius: radius,
          child: Stack(
            children: [
              ExcludeSemantics(
                excluding: locked,
                child: IgnorePointer(
                  key: const Key('challenge-reward-guard'),
                  ignoring: locked,
                  child: DecoratedBox(
                    decoration: challengeBrandPanel(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: _body(),
                    ),
                  ),
                ),
              ),
              if (locked)
                Positioned.fill(
                  child: _RewardLockOverlay(label: strings.rewardLockedLabel),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body() {
    final showFile = entitled && hasDisplayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DiplomaPlaceholder(
          label: strings.diplomaLabel,
          // Locked cards are smeared by the overlay's BackdropFilter.
          // Every other textured card (free, unlocked-but-incomplete,
          // completed-but-unpaid without the paywall) blurs itself and
          // shows no lock.
          blur: _texturedDiploma && !locked,
          textured: _texturedDiploma,
          image:
              entitled &&
                  hasDisplayName &&
                  diplomas != null &&
                  challengeId != null
              ? _ServerDiplomaPreview(
                  client: diplomas!,
                  challengeId: challengeId!,
                )
              : null,
        ),
        if (!completed) ...[
          const SizedBox(height: 12),
          Text(
            strings.rewardUnlocksAfterComplete,
            key: const Key('challenge-reward-incomplete'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.bark, fontSize: 13),
          ),
        ],
        if (_blurPreview && !locked) ...[
          const SizedBox(height: 12),
          Text(
            strings.diplomaBlurred,
            key: const Key('challenge-reward-blurred-hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.bark, fontSize: 13),
          ),
        ],
        if (completed && entitled && !hasDisplayName) ...[
          const SizedBox(height: 12),
          Text(
            strings.diplomaNeedName,
            key: const Key('challenge-reward-need-name'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.bark, fontSize: 13),
          ),
        ],
        if (showFile) ...[
          const SizedBox(height: 14),
          FilledButton(
            key: const Key('challenge-save-diploma'),
            onPressed: locked ? null : onSaveDiploma,
            style: FilledButton.styleFrom(
              backgroundColor: BrandColors.forest,
              foregroundColor: BrandColors.cream,
            ),
            child: Text(strings.saveDiploma),
          ),
        ],
      ],
    );
  }
}

/// Frosted cover until the challenge is paid. The lock absorbs taps.
class _RewardLockOverlay extends StatelessWidget {
  const _RewardLockOverlay({required this.label});

  final String label;

  static const double _sigma = _diplomaBlurSigma;
  static const double _lockSize = 48;
  static const double _iconSize = 32;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      container: true,
      excludeSemantics: true,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            ChallengeRewardSection.panelRadius,
          ),
          child: BackdropFilter(
            key: const Key('challenge-reward-lock-overlay'),
            filter: ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
            child: ColoredBox(
              key: const Key('challenge-reward-lock-scrim'),
              color: BrandColors.cream.withValues(alpha: 0.35),
              child: Center(
                child: SizedBox(
                  key: const Key('challenge-reward-lock'),
                  width: _lockSize,
                  height: _lockSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: BrandColors.cream.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(
                          color: BrandColors.forest.withValues(alpha: 0.85),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock_outline,
                        size: _iconSize,
                        color: BrandColors.forest,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared by the lock overlay and the no-lock texture blur.
/// High enough to smear detail, low enough that the diploma still reads
/// on web and mobile (the cream scrim sits on top of this blur).
const _diplomaBlurSigma = 6.0;

class _DiplomaPlaceholder extends StatelessWidget {
  const _DiplomaPlaceholder({
    this.label,
    this.blur = false,
    this.textured = false,
    this.image,
  });

  final String? label;
  final bool blur;

  /// Paint [_DiplomaTexture] instead of the plain doc-icon schematic.
  final bool textured;
  final Widget? image;

  @override
  Widget build(BuildContext context) {
    final schematic = DecoratedBox(
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
    );
    final fallback = textured ? const _DiplomaTexture() : schematic;
    Widget art = AspectRatio(aspectRatio: 1, child: image ?? fallback);
    if (blur) {
      art = ImageFiltered(
        key: const Key('challenge-reward-diploma-blur'),
        imageFilter: ImageFilter.blur(
          sigmaX: _diplomaBlurSigma,
          sigmaY: _diplomaBlurSigma,
        ),
        child: art,
      );
    }
    return Column(
      key: const Key('challenge-reward-diploma'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        art,
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

class _ServerDiplomaPreview extends StatefulWidget {
  const _ServerDiplomaPreview({
    required this.client,
    required this.challengeId,
  });

  final DiplomaClient client;
  final String challengeId;

  @override
  State<_ServerDiplomaPreview> createState() => _ServerDiplomaPreviewState();
}

class _ServerDiplomaPreviewState extends State<_ServerDiplomaPreview> {
  DiplomaImageResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await widget.client.fetchImage(widget.challengeId);
    if (!mounted) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final url = _result?.url;
    if (url == null || url.isEmpty) {
      return const ColoredBox(color: BrandColors.cream);
    }
    return Image(
      key: const Key('challenge-reward-diploma-image'),
      image: diplomaImageProvider(url),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(color: BrandColors.cream),
    );
  }
}

/// Generated faux-diploma (frame, mark, title, name, text lines, date).
/// Shown blurred behind the paywall and on cards with no server preview.
/// Needs no asset and no network.
class _DiplomaTexture extends StatelessWidget {
  const _DiplomaTexture();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      key: Key('challenge-reward-diploma-texture'),
      painter: _DiplomaTexturePainter(),
      child: SizedBox.expand(),
    );
  }
}

class _DiplomaTexturePainter extends CustomPainter {
  const _DiplomaTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final forest = Paint()..color = BrandColors.forest;
    // Filled border, not a hairline. A thin stroke vanishes under sigma ~6
    // plus the cream scrim and the card reads as blank cream.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      forest,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.07, h * 0.07, w * 0.93, h * 0.93),
        const Radius.circular(8),
      ),
      Paint()..color = BrandColors.beige,
    );

    void bar(double cy, double width, double thick) {
      final rect = Rect.fromCenter(
        center: Offset(w / 2, h * cy),
        width: w * width,
        height: h * thick,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(h * thick / 2)),
        forest,
      );
    }

    final seal = Offset(w / 2, h * 0.19);
    canvas.drawCircle(seal, w * 0.078, forest);
    canvas.drawCircle(seal, w * 0.042, Paint()..color = BrandColors.beige);
    canvas.drawCircle(seal, w * 0.020, forest);
    bar(0.32, 0.40, 0.046); // DIPLOM label
    bar(0.40, 0.62, 0.016); // rule
    bar(0.51, 0.76, 0.085); // recipient name
    bar(0.61, 0.62, 0.016); // rule
    bar(0.70, 0.72, 0.040); // body
    bar(0.78, 0.62, 0.040);
    bar(0.86, 0.36, 0.034); // date
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
