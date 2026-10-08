import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
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
    var phase = resolveDiplomaPhase(
      completed: completed,
      entitled: entitled,
      hasDisplayName: hasDiplomaDisplayName(name),
      remoteState: access.state == 'unavailable' ? null : access.state,
    );
    String? imageUrl;
    var failed = false;
    if (shouldRequestDiplomaFile(phase)) {
      final image = await services.diplomas.fetchImage(widget.challengeId);
      if (image.error == 'not_entitled') {
        phase = DiplomaPhase.blurred;
      } else if (image.error == 'need_name') {
        phase = DiplomaPhase.needName;
      } else if (!image.ok) {
        failed = true;
      } else {
        imageUrl = image.url;
      }
    }
    return _DiplomaViewData(
      detail: detail,
      phase: phase,
      imageUrl: imageUrl,
      failed: failed,
      completionLine: diplomaCompletionLine(
        remoteLabel: access.completionLabel,
        completedAt: progress?.completedAt,
      ),
      diplomaId: access.diplomaId,
      recipientNameDisplay: access.recipientNameDisplay,
      nameEditable: access.nameEditable,
      nameSource: access.nameSource,
    );
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
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

  Future<void> _saveFile(String url, String filename) async {
    await downloadOrShareDiploma(url: url, filename: filename);
  }

  Future<void> _shareTarget({
    required DiplomaShareTarget target,
    required String url,
    required String filename,
    required String title,
  }) async {
    final strings = context.read<LocaleController>().strings;
    final bytes = await diplomaBytesLoader(url);
    if (!mounted) return;
    final outcome = await runDiplomaShare(
      target: target,
      bytes: bytes,
      filename: filename,
      caption: strings.diplomaShareCaption(title),
    );
    if (!mounted || !outcome.showUploadHint) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          strings.diplomaShareDownloadedHint,
          key: const Key('diploma-share-hint'),
        ),
      ),
    );
  }

  Future<void> _editName(String diplomaId, String current) async {
    final strings = context.read<LocaleController>().strings;
    final controller = TextEditingController(text: current);
    var invalid = false;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              key: const Key('diploma-name-dialog'),
              backgroundColor: BrandColors.cream,
              title: Text(strings.diplomaEditName),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('diploma-name-field'),
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  if (invalid) ...[
                    const SizedBox(height: 8),
                    Text(
                      strings.diplomaNameInvalid,
                      key: const Key('diploma-name-invalid'),
                      style: const TextStyle(color: BrandColors.forest),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  key: const Key('diploma-name-cancel'),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(strings.diplomaNameCancel),
                ),
                FilledButton(
                  key: const Key('diploma-name-save'),
                  onPressed: () {
                    final normalized = normalizeDiplomaEditedName(
                      controller.text,
                    );
                    if (normalized == null) {
                      setDialogState(() => invalid = true);
                      return;
                    }
                    Navigator.pop(ctx, normalized);
                  },
                  child: Text(strings.diplomaNameSave),
                ),
              ],
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (!mounted || name == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          key: const Key('diploma-name-confirm-dialog'),
          backgroundColor: BrandColors.cream,
          title: Text(strings.diplomaEditName),
          content: Text(
            strings.diplomaNameConfirm,
            key: const Key('diploma-name-confirm'),
          ),
          actions: [
            TextButton(
              key: const Key('diploma-name-confirm-cancel'),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.diplomaNameCancel),
            ),
            FilledButton(
              key: const Key('diploma-name-confirm-save'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(strings.diplomaNameSave),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<AppServices>().diplomas.editName(diplomaId, name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.diplomaError)));
      return;
    }
    if (!mounted) return;
    _retry();
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
            onSave: _saveFile,
            onShare: _shareTarget,
            onEditName: _editName,
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
    required this.onSave,
    required this.onShare,
    required this.onEditName,
  });

  final _DiplomaViewData data;
  final AppStrings strings;
  final VoidCallback onRetry;
  final Future<void> Function(RewardVariant variant) onBuy;
  final Future<void> Function(String url, String filename) onSave;
  final Future<void> Function({
    required DiplomaShareTarget target,
    required String url,
    required String filename,
    required String title,
  })
  onShare;
  final Future<void> Function(String diplomaId, String currentName) onEditName;

  @override
  Widget build(BuildContext context) {
    final challenge = data.detail.challenge;
    final filename = diplomaFileName(challenge.slug);
    final nameSection = _nameSection();
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
              if (nameSection != null) ...[
                const SizedBox(height: 16),
                nameSection,
              ],
              const SizedBox(height: 16),
              _actions(context, challenge, filename),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _nameSection() {
    if (data.nameEditable && data.diplomaId != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.diplomaNameFromProfile,
            key: const Key('diploma-name-info'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.bark),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('diploma-edit-name'),
            onPressed: () =>
                onEditName(data.diplomaId!, data.recipientNameDisplay ?? ''),
            child: Text(strings.diplomaEditName),
          ),
        ],
      );
    }
    if (data.nameSource == 'edited') {
      return Text(
        strings.diplomaNameEdited,
        key: const Key('diploma-name-edited'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: BrandColors.bark),
      );
    }
    return null;
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
        final title = challenge.copyFor(strings.locale).title;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              key: const Key('diploma-download'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: () => onSave(url, filename),
              child: Text(strings.diplomaDownload),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ShareOption(
                  buttonKey: const Key('diploma-share'),
                  label: strings.diplomaShare,
                  icon: Icons.share_outlined,
                  onPressed: () => onShare(
                    target: DiplomaShareTarget.generic,
                    url: url,
                    filename: filename,
                    title: title,
                  ),
                ),
                const SizedBox(width: 8),
                _ShareOption(
                  buttonKey: const Key('diploma-share-instagram'),
                  label: strings.diplomaShareInstagram,
                  icon: Icons.photo_camera_outlined,
                  onPressed: () => onShare(
                    target: DiplomaShareTarget.instagram,
                    url: url,
                    filename: filename,
                    title: title,
                  ),
                ),
                const SizedBox(width: 8),
                _ShareOption(
                  buttonKey: const Key('diploma-share-facebook'),
                  label: strings.diplomaShareFacebook,
                  icon: Icons.facebook_outlined,
                  onPressed: () => onShare(
                    target: DiplomaShareTarget.facebook,
                    url: url,
                    filename: filename,
                    title: title,
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        key: buttonKey,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          foregroundColor: BrandColors.forest,
          side: const BorderSide(color: BrandColors.beige),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: BrandColors.forest),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: BrandColors.forest),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiplomaViewData {
  const _DiplomaViewData({
    required this.detail,
    required this.phase,
    this.imageUrl,
    this.completionLine,
    this.failed = false,
    this.diplomaId,
    this.recipientNameDisplay,
    this.nameEditable = false,
    this.nameSource = 'profile',
  });

  final ChallengeDetail detail;
  final DiplomaPhase phase;
  final String? imageUrl;
  final String? completionLine;
  final bool failed;
  final String? diplomaId;
  final String? recipientNameDisplay;
  final bool nameEditable;
  final String nameSource;
}
