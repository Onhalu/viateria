import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_services.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../navigation.dart';
import '../widgets/catalog_cards.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  Future<_CatalogData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_CatalogData> _load() async {
    final services = context.read<AppServices>();
    final challenges = await services.catalog.fetchPublishedChallenges();
    final promos = await services.catalog.fetchPublishedPromos();
    return _CatalogData(challenges: challenges, promos: promos);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_CatalogData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(strings.errorGeneric),
                    TextButton(onPressed: _reload, child: Text(strings.retry)),
                  ],
                ),
              );
            }
            final data = snapshot.data!;
            if (data.challenges.isEmpty && data.promos.isEmpty) {
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 80),
                    Text(
                      strings.catalogEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(strings.catalogEmptyHint, textAlign: TextAlign.center),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final promo in data.promos) ...[
                    PromoStripeCard(
                      promo: promo,
                      onTap: () => _openPromo(promo),
                    ),
                    const SizedBox(height: 16),
                  ],
                  for (final challenge in data.challenges) ...[
                    ChallengeCard(
                      challenge: challenge,
                      onTap: () => openChallenge(context, challenge.id),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openPromo(PromoStripe promo) async {
    final challengeId = promo.challengeId;
    if (challengeId != null) {
      if (mounted) await openChallenge(context, challengeId);
      return;
    }
    final url = promo.linkUrl;
    if (url != null && url.isNotEmpty) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

class _CatalogData {
  const _CatalogData({required this.challenges, required this.promos});

  final List<Challenge> challenges;
  final List<PromoStripe> promos;
}
