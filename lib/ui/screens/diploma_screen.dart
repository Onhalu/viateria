import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/diploma_client.dart';
import '../../domain/challenge_reward.dart';
import '../../domain/diploma_phase.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';
import '../diploma_share.dart';

class DiplomaScreen extends StatefulWidget {
  const DiplomaScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  State<DiplomaScreen> createState() => _DiplomaScreenState();
}

class _DiplomaScreenState extends State<DiplomaScreen> {
  Future<_DiplomaViewData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_DiplomaViewData> _load() async {
    final services = context.read<AppServices>();
    final detail = await services.catalog.fetchChallenge(widget.challengeId);
    final progress = await services.progress.fetchProgress(widget.challengeId);
    final purchase = await services.purchases.fetchPurchase(widget.challengeId);
    final access = await services.diplomas.access(widget.challengeId);
    final completed = progress?.isCompleted ?? false;
    final entitled = ChallengeReward.isDiplomaEntitled(
      challengeCompleted: completed,
      purchasePaid: purchase?.isPaid ?? false,
      diplomaPriceCents: detail.challenge.diplomaPriceCents,
      requiresPurchase: detail.challenge.isPaid,
    );
    final name = services.auth.currentUser?.displayName;
    final phase = resolveDiplomaPhase(
      completed: completed,
      entitled: entitled,
      hasDisplayName: hasDiplomaDisplayName(name),
      remoteState: access.state == 'unavailable' ? null : access.state,
    );
    DiplomaImageResult? image;
    if (shouldRequestDiplomaFile(phase)) {
      image = await services.diplomas.fetchImage(widget.challengeId);
      if (image.error == 'not_entitled') {
        return _DiplomaViewData(
          detail: detail,
          phase: DiplomaPhase.blurred,
          completionLine: diplomaCompletionLine(
            remoteLabel: access.completionLabel,
            completedAt: progress?.completedAt,
          ),
        );
      }
      if (image.error == 'need_name') {
        return _DiplomaViewData(
          detail: detail,
          phase: DiplomaPhase.needName,
          completionLine: diplomaCompletionLine(
            remoteLabel: access.completionLabel,
            completedAt: progress?.completedAt,
          ),
        );
      }
      if (!image.ok) {
        return _DiplomaViewData(
          detail: detail,
          phase: DiplomaPhase.ready,
          failed: true,
          completionLine: diplomaCompletionLine(
            remoteLabel: access.completionLabel,
            completedAt: progress?.completedAt,
          ),
        );
      }
    }
    return _DiplomaViewData(
      detail: detail,
      phase: phase,
      imageUrl: image?.url,
      completionLine: diplomaCompletionLine(
        remoteLabel: access.completionLabel,
        completedAt: progress?.completedAt,
      ),
    );
  }

  void _retry() {
    setState(() => _future = _load());
  }

  Future<void> _buy(RewardVariant variant) async {
    final services = context.read<AppServices>();
    final session = await services.purchases.startCheckout(
      widget.challengeId,
      rewardVariant: variant,
    );
    if (!mounted) return;
    await services.openUrl(Uri.parse(session.url));
  }

  Future<void> _share(String url, String filename) async {
    await downloadOrShareDiploma(url: url, filename: filename);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.viewDiploma)),
      body: FutureBuilder<_DiplomaViewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(strings.diplomaGenerating),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(child: Text(strings.errorGeneric));
          }
          return _DiplomaBody(
            data: snapshot.data!,
            strings: strings,
            onRetry: _retry,
            onBuy: _buy,
            onShare: _share,
          );
        },
      ),
    );
  }
}

class _DiplomaBody extends StatelessWidget {
  const _DiplomaBody({
    required this.data,
    required this.strings,
    required this.onRetry,
    required this.onBuy,
    required this.onShare,
  });

  final _DiplomaViewData data;
  final AppStrings strings;
  final VoidCallback onRetry;
  final Future<void> Function(RewardVariant variant) onBuy;
  final Future<void> Function(String url, String filename) onShare;

  @override
  Widget build(BuildContext context) {
    final challenge = data.detail.challenge;
    final filename = diplomaFileName(challenge.slug);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _preview(),
              if (data.completionLine != null &&
                  data.phase != DiplomaPhase.incomplete) ...[
                const SizedBox(height: 12),
                Text(
                  data.completionLine!,
                  key: const Key('diploma-completed-on'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BrandColors.bark),
                ),
              ],
              const SizedBox(height: 16),
              _actions(context, challenge, filename),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    final blurred = data.phase == DiplomaPhase.blurred;
    final schematic = AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BrandColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrandColors.beige),
        ),
        child: const Center(
          child: Icon(
            Icons.description_outlined,
            size: 48,
            color: BrandColors.forest,
          ),
        ),
      ),
    );
    if (data.imageUrl != null) {
      return AspectRatio(
        aspectRatio: 1,
        child: Image(
          key: const Key('diploma-image'),
          image: diplomaImageProvider(data.imageUrl!),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
        ),
      );
    }
    if (blurred) {
      return ImageFiltered(
        key: const Key('diploma-blur'),
        imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: schematic,
      );
    }
    return schematic;
  }

  Widget _actions(BuildContext context, Challenge challenge, String filename) {
    switch (data.phase) {
      case DiplomaPhase.incomplete:
        return Text(
          strings.diplomaIncomplete,
          key: const Key('diploma-incomplete'),
          textAlign: TextAlign.center,
        );
      case DiplomaPhase.revoked:
        return Text(
          strings.diplomaRevoked,
          key: const Key('diploma-revoked'),
          textAlign: TextAlign.center,
        );
      case DiplomaPhase.needName:
        return Text(
          strings.diplomaNeedName,
          key: const Key('diploma-need-name'),
          textAlign: TextAlign.center,
        );
      case DiplomaPhase.blurred:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.diplomaBlurred,
              key: const Key('diploma-blurred-hint'),
              textAlign: TextAlign.center,
            ),
            if (challenge.isPaid) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('diploma-buy'),
                onPressed: () => onBuy(RewardVariant.diploma),
                child: Text(strings.payDigitalDiploma),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('diploma-buy-medal'),
                onPressed: () => onBuy(RewardVariant.medalAndDiploma),
                child: Text(strings.payMedalAndDiploma),
              ),
            ],
          ],
        );
      case DiplomaPhase.ready:
        if (data.failed || data.imageUrl == null) {
          return Column(
            children: [
              Text(
                strings.diplomaError,
                key: const Key('diploma-error'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('diploma-retry'),
                onPressed: onRetry,
                child: Text(strings.paymentRetry),
              ),
            ],
          );
        }
        final url = data.imageUrl!;
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('diploma-download'),
                onPressed: () => onShare(url, filename),
                child: Text(strings.diplomaDownload),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const Key('diploma-share'),
                onPressed: () => onShare(url, filename),
                child: Text(strings.diplomaShare),
              ),
            ),
          ],
        );
    }
  }
}

class _DiplomaViewData {
  const _DiplomaViewData({
    required this.detail,
    required this.phase,
    this.imageUrl,
    this.completionLine,
    this.failed = false,
  });

  final ChallengeDetail detail;
  final DiplomaPhase phase;
  final String? imageUrl;
  final String? completionLine;
  final bool failed;
}
