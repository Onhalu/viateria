import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.onTap,
    this.completed = false,
  });

  final Challenge challenge;
  final VoidCallback onTap;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = context.watch<LocaleController>().strings;
    final copy = challenge.copyFor(locale);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: challenge.coverImageUrl == null
                  ? Container(
                      color: BrandColors.beige,
                      child: Icon(
                        Icons.landscape,
                        size: 48,
                        color: scheme.onPrimaryContainer,
                      ),
                    )
                  : Image.network(
                      challenge.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: BrandColors.beige,
                        child: const Icon(Icons.landscape, size: 48),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(
                        label: challenge.accessMode == AccessMode.story
                            ? strings.storyChallenge
                            : strings.openChallenge,
                      ),
                      _Chip(
                        label: challenge.isPaid ? strings.paid : strings.free,
                        active: challenge.isPaid,
                      ),
                      if (completed)
                        _Chip(label: strings.completed, active: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (copy.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      copy.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PromoStripeCard extends StatelessWidget {
  const PromoStripeCard({
    super.key,
    required this.promo,
    required this.onTap,
  });

  final PromoStripe promo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = context.watch<LocaleController>().strings;
    final copy = promo.copyFor(locale);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: promo.imageUrl == null
                  ? Container(
                      color: BrandColors.beige,
                      child: const Icon(
                        Icons.campaign,
                        size: 48,
                        color: BrandColors.forest,
                      ),
                    )
                  : Image.network(
                      promo.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: BrandColors.beige,
                        child: Icon(Icons.campaign, size: 48),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Chip(label: 'Promo', active: true),
                  const SizedBox(height: 8),
                  Text(
                    copy.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((copy.subtitle ?? copy.description).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      copy.subtitle ?? copy.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: onTap,
                      child: Text(copy.ctaLabel ?? strings.promoFallbackCta),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? BrandColors.forest : BrandColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? BrandColors.forest : BrandColors.beige,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: active ? BrandColors.onPrimary : BrandColors.bark,
        ),
      ),
    );
  }
}
