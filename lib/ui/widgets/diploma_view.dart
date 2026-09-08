import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

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
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF40916C)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4A017), width: 6),
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
                    const Icon(
                      Icons.emoji_events,
                      color: Color(0xFFD4A017),
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.headline ?? widget.strings.diplomaHeadlineDefault,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.explorerName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD4A017),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.body ?? widget.strings.congratulations,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.challengeTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
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
                            color: Color(0xFFD4A017),
                            size: 36,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(date, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(
                      widget.strings.appName,
                      style: const TextStyle(
                        color: Colors.white70,
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
              Color(0xFFD4A017),
              Color(0xFF95D5B2),
              Color(0xFFFFFFFF),
              Color(0xFF40916C),
            ],
          ),
      ],
    );
  }
}
