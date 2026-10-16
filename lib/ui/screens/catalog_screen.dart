import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_services.dart';
import '../../domain/catalog_query.dart';
import '../../domain/promo.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../layout/breakpoints.dart';
import '../navigation.dart';
import '../widgets/catalog_cards.dart';
import '../widgets/catalog_filters.dart';
import '../widgets/catalog_welcome_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/promo_widget.dart';

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
    final detailsFuture = services.catalog.fetchPublishedDetails();
    final promosFuture = _loadPromos(services);
    return _CatalogData(
      details: await detailsFuture,
      promos: await promosFuture,
    );
  }

  /// A promo failure leaves the catalog up. The slot collapses.
  Future<List<PromoStripe>> _loadPromos(AppServices services) async {
    try {
      return await services.catalog.fetchPublishedPromos();
    } catch (_) {
      return const [];
    }
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
          CatalogWelcomeHeader(
            search: _search,
            filter: _filter,
            onFilterChanged: _applyFilter,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: FutureBuilder<_CatalogData>(
                future: _future,
                builder: (context, snapshot) =>
                    _catalogBody(context, snapshot, strings),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _catalogBody(
    BuildContext context,
    AsyncSnapshot<_CatalogData> snapshot,
    AppStrings strings,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const CatalogLoadingSkeleton();
    }
    if (snapshot.hasError) {
      return ErrorState(
        title: strings.errorGeneric,
        hint: strings.errorOfflineHint,
        retryLabel: strings.retry,
        onRetry: _reload,
      );
    }
    final data = snapshot.data!;
    final challenges = [for (final detail in data.details) detail.challenge];
    final routeStats = catalogRouteStatsByChallenge(data.details);
    final visible = filterCatalogChallenges(challenges, _filter);
    final noMatches =
        challenges.isNotEmpty && visible.isEmpty && _filter.isActive;
    final cmsEmpty = challenges.isEmpty && data.promos.isEmpty;
    final now = DateTime.now();
    final promos = visiblePromos(
      !noMatches && _filter.showPromos ? data.promos : const <PromoStripe>[],
      now,
    );

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
                Text(strings.catalogEmptyHint, textAlign: TextAlign.center),
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
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final content = width > Breakpoints.catalogMaxWidth
                    ? Breakpoints.catalogMaxWidth
                    : width;
                final side = 16 + (width - content) / 2;
                final columns = Breakpoints.catalogColumns(content - 32);
                return CustomScrollView(
                  key: const Key('catalog-results'),
                  slivers: [
                    SliverPadding(
                      key: const Key('catalog-results-padding'),
                      padding: EdgeInsets.fromLTRB(side, 8, side, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          CatalogHeroCarousel(
                            challenges: visible,
                            routeStats: routeStats,
                            onOpen: (challenge) =>
                                openChallenge(context, challenge.id),
                          ),
                          const SizedBox(height: 16),
                          CatalogFeaturedSection(
                            challenges: visible,
                            routeStats: routeStats,
                            onOpen: (challenge) =>
                                openChallenge(context, challenge.id),
                          ),
                          if (promos.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            PromoWidget(
                              key: const Key('promo-widget'),
                              promos: promos,
                              now: now,
                              onOpen: _openPromo,
                            ),
                          ],
                          const SizedBox(height: 16),
                          CatalogRegionsSection(
                            filter: _filter,
                            onChanged: _applyFilter,
                          ),
                          const SizedBox(height: 16),
                        ]),
                      ),
                    ),
                    if (visible.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(side, 0, side, 16),
                        sliver: SliverMainAxisGroup(
                          slivers: CatalogCountryResults(
                            challenges: visible,
                            routeStats: routeStats,
                            onOpen: (challenge) =>
                                openChallenge(context, challenge.id),
                          ).slivers(columns: columns, width: content - 32),
                        ),
                      ),
                  ],
                );
              },
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
