import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/brand_assets.dart';
import '../../theme/brand_colors.dart';

/// Portrait 9:16 diploma with medals. Confetti is shown on first complete.
class DiplomaView extends StatelessWidget {
  const DiplomaView({
    super.key,
    required this.challengeTitle,
    required this.explorerName,
    required this.completedAt,
    required this.medalCount,
    required this.strings,
    this.headline,
    this.body,
    this.showConfetti = true,
  });

  static const aspectRatio = 9 / 16;

  final String challengeTitle;
  final String explorerName;
  final DateTime completedAt;
  final int medalCount;
  final AppStrings strings;
  final String? headline;
  final String? body;
  final bool showConfetti;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: _DiplomaCanvas(
        challengeTitle: challengeTitle,
        explorerName: explorerName,
        completedAt: completedAt,
        medalCount: medalCount,
        strings: strings,
        headline: headline,
        body: body,
        showConfetti: showConfetti,
      ),
    );
  }
}

class _DiplomaCanvas extends StatefulWidget {
  const _DiplomaCanvas({
    required this.challengeTitle,
    required this.explorerName,
    required this.completedAt,
    required this.medalCount,
    required this.strings,
    required this.showConfetti,
    this.headline,
    this.body,
  });

  final String challengeTitle;
  final String explorerName;
  final DateTime completedAt;
  final int medalCount;
  final AppStrings strings;
  final String? headline;
  final String? body;
  final bool showConfetti;

  @override
  State<_DiplomaCanvas> createState() => _DiplomaCanvasState();
}

class _DiplomaCanvasState extends State<_DiplomaCanvas> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    if (widget.showConfetti) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confetti.play();
      });
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date =
        '${widget.completedAt.year}-${widget.completedAt.month.toString().padLeft(2, '0')}-${widget.completedAt.day.toString().padLeft(2, '0')}';
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: BrandColors.cream,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: BrandColors.beige, width: 6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 360,
                height: 640,
                child: Column(
                  children: [
                    const BrandMark(size: 48),
                    const SizedBox(height: 16),
                    Text(
                      widget.headline ?? widget.strings.diplomaHeadlineDefault,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BrandColors.forest,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.explorerName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BrandColors.sage,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.body ?? widget.strings.congratulations,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BrandColors.ink,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.challengeTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BrandColors.forest,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        for (var i = 0; i < widget.medalCount.clamp(1, 8); i++)
                          const Icon(
                            Icons.military_tech,
                            color: BrandColors.sage,
                            size: 36,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      date,
                      style: const TextStyle(color: BrandColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.strings.appName,
                      style: const TextStyle(
                        color: BrandColors.forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.showConfetti)
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              BrandColors.forest,
              BrandColors.sage,
              BrandColors.beige,
              BrandColors.cream,
            ],
          ),
      ],
    );
  }
}
