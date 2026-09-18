import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_services.dart';
import '../../domain/catalog_query.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../navigation.dart';
import '../widgets/app_shell.dart';
import '../widgets/catalog_cards.dart';
import '../widgets/catalog_filters.dart';
import '../widgets/catalog_welcome_header.dart';
import '../widgets/empty_state.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  Future<_CatalogData>? _future;
  final _search = TextEditingController();
  CatalogFilter _filter = const CatalogFilter();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_CatalogData> _load() async {
    final services = context.read<AppServices>();
    final details = await services.catalog.fetchPublishedDetails();
    final promos = await services.catalog.fetchPublishedPromos();
    return _CatalogData(details: details, promos: promos);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  void _applyFilter(CatalogFilter next) {
    if (_search.text != next.query) {
      _search.value = TextEditingValue(
        text: next.query,
        selection: TextSelection.collapsed(offset: next.query.length),
      );
    }
    setState(() => _filter = next);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return Scaffold(
      body: Column(
        children: [
          const CatalogWelcomeHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppShell.horizontalInset,
              0,
              AppShell.horizontalInset,
              8,
            ),
            child: CatalogSearchField(
              controller: _search,
              hintText: strings.catalogSearchHint,
              onChanged: (value) =>
                  _applyFilter(_filter.copyWith(query: value)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppShell.horizontalInset,
              0,
              AppShell.horizontalInset,
              8,
            ),
            child: CatalogFilterChipRow(
              filter: _filter,
              strings: strings,
              onChanged: _applyFilter,
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
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
                          TextButton(
                            onPressed: _reload,
                            child: Text(strings.retry),
                          ),
                        ],
                      ),
                    );
                  }
                  final data = snapshot.data!;
                  final challenges = [
                    for (final detail in data.details) detail.challenge,
                  ];
                  final routeStats = catalogRouteStatsByChallenge(data.details);
                  final visible = filterCatalogChallenges(
                    challenges,
                    _filter,
                    routeStats: routeStats,
                  );
                  final noMatches =
                      challenges.isNotEmpty &&
                      visible.isEmpty &&
                      _filter.isActive;
                  final cmsEmpty = challenges.isEmpty && data.promos.isEmpty;
                  final promos = !noMatches && _filter.showPromos
                      ? data.promos
                      : const <PromoStripe>[];
                  final showDuration = routeStats.isNotEmpty;

                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: cmsEmpty
                        ? ListView(
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
                              Text(
                                strings.catalogEmptyHint,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : noMatches
                        ? EmptyState(
                            key: const Key('catalog-no-matches'),
                            title: strings.catalogNoMatches,
                            hint: strings.catalogNoMatchesHint,
                            actionLabel: strings.catalogClearFilters,
                            outlinedAction: true,
                            onAction: () => _applyFilter(const CatalogFilter()),
                          )
                        : ListView(
                            key: const Key('catalog-results'),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            children: [
                              for (final promo in promos) ...[
                                PromoStripeCard(
                                  promo: promo,
                                  onTap: () => _openPromo(promo),
                                ),
                                const SizedBox(height: 16),
                              ],
                              CatalogHeroCarousel(
                                challenges: visible,
                                routeStats: routeStats,
                                onOpen: (challenge) =>
                                    openChallenge(context, challenge.id),
                              ),
                              if (showDuration) ...[
                                const SizedBox(height: 16),
                                CatalogDurationChipRow(
                                  filter: _filter,
                                  strings: strings,
                                  onChanged: _applyFilter,
                                ),
                              ],
                              const SizedBox(height: 16),
                              CatalogFeaturedSection(
                                challenges: visible,
                                routeStats: routeStats,
                                onOpen: (challenge) =>
                                    openChallenge(context, challenge.id),
                              ),
                              const SizedBox(height: 16),
                              CatalogRegionsSection(
                                filter: _filter,
                                strings: strings,
                                onChanged: _applyFilter,
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ),
        ],
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
  const _CatalogData({required this.details, required this.promos});

  final List<ChallengeDetail> details;
  final List<PromoStripe> promos;
}
