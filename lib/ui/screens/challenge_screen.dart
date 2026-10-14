import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/last_opened_challenge.dart';
import '../../data/repositories.dart';
import '../../data/route_services.dart';
import '../../domain/challenge_photos.dart';
import '../../domain/challenge_reward.dart';
import '../../domain/fapi_offer.dart';
import '../../domain/route_planner.dart';
import '../../domain/story_feed.dart';
import '../../domain/story_fog.dart';
import '../../map/place.dart';
import '../../map/place_query.dart';
import '../../domain/unlock_rules.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/brand_assets.dart';
import '../challenge_route_controller.dart';
import '../layout/breakpoints.dart';
import '../widgets/app_network_image.dart';
import '../widgets/challenge_map.dart';
import '../widgets/error_state.dart';
import '../widgets/challenge_photos_section.dart';
import '../widgets/challenge_reward_section.dart';
import '../widgets/empty_state.dart';
import '../widgets/place_presentation.dart';
import '../widgets/route_planner_panel.dart';
import '../widgets/story_chapter_card.dart';
import '../fapi_checkout_window.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.challengeId,
    this.embedded = false,
  });

  final String challengeId;
  final bool embedded;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  List<Place>? _catalogPlaces;
  static const _rules = UnlockRules();

  Future<_ChallengePageData>? _future;
  Future<FapiOffer?>? _offerFuture;
  final _startController = TextEditingController();
  final _feedScroll = ScrollController();
  final _route = ChallengeRouteController();

  int _routeToken = 0;
  String? _pendingRevealId;
  var _revealScheduled = false;
  final _chapterKeys = <String, GlobalKey>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
    _offerFuture ??= _loadOffer();
    context.read<LastOpenedChallengeStore>().remember(widget.challengeId);
  }

  @override
  void didUpdateWidget(ChallengeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challengeId == widget.challengeId) return;
    _future = _load();
    _offerFuture = _loadOffer();
  }

  @override
  void dispose() {
    _startController.dispose();
    _feedScroll.dispose();
    _route.dispose();
    super.dispose();
  }

  Future<_ChallengePageData> _load() async {
    final services = context.read<AppServices>();
    // Catalog elevation is optional. Do not block the page or the route
    // request on it: a slow fetch must not leave the planner stuck loading.
    _rememberCatalog(services.places.fetchAll());
    final detail = await services.catalog.fetchChallenge(widget.challengeId);
    final progress = await services.progress.fetchProgress(widget.challengeId);
    final purchase = await services.purchases.fetchPurchase(widget.challengeId);
    final photos = await _loadGallery(services);
    return _ChallengePageData(
      detail: detail,
      progress: progress,
      purchase: purchase,
      photos: photos,
    );
  }

  void _rememberCatalog(Future<List<Place>> placesFuture) {
    placesFuture.then(
      (places) {
        if (!mounted) return;
        setState(() => _catalogPlaces = places);
        if (_route.start != null) _refreshRoutes();
      },
      onError: (_, _) {
        if (!mounted) return;
        if (_catalogPlaces != null) return;
        setState(() => _catalogPlaces = const []);
      },
    );
  }

  Future<List<ChallengeGalleryPhoto>> _loadGallery(AppServices services) async {
    final rows = await services.progress.fetchChallengePhotos(
      widget.challengeId,
    );
    if (rows.isEmpty) return const [];
    final urls = await services.photos.signedUrlsForPhotos([
      for (final row in rows) row.photoPath,
    ]);
    return resolveChallengePhotoGallery(rows: rows, urls: urls);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
      _offerFuture = _loadOffer();
    });
    await _future;
  }

  Future<FapiOffer?> _loadOffer() async {
    final services = context.read<AppServices>();
    final locale = context.read<LocaleController>().locale;
    try {
      return await services.purchases.fetchOffer(
        widget.challengeId,
        locale: locale,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _unlockPaid(RewardVariant variant) async {
    final data = await _future;
    if (!mounted) return;
    final formUrl = data?.detail.challenge.fapiFormUrlFor(variant);
    if (formUrl == null) return;
    final services = context.read<AppServices>();
    final session = await services.purchases.startCheckout(
      widget.challengeId,
      rewardVariant: variant,
    );
    if (!mounted) return;
    final checkoutUrl = httpUrlOrNull(session.url) ?? formUrl;
    await showInAppFapiCheckout(
      context,
      challengeId: widget.challengeId,
      checkoutUrl: checkoutUrl,
    );
    if (!mounted) return;
    await _reload();
  }

  Widget _offerPayCtas(Challenge challenge, AppStrings strings) {
    return FutureBuilder<FapiOffer?>(
      future: _offerFuture,
      builder: (context, offerSnapshot) {
        final loading =
            _offerFuture == null ||
            offerSnapshot.connectionState != ConnectionState.done;
        return _ChallengePayCtas(
          strings: strings,
          challenge: challenge,
          offer: offerSnapshot.data,
          loading: loading,
          failed:
              offerSnapshot.hasError ||
              (!loading && offerSnapshot.data == null),
          onPay: _unlockPaid,
        );
      },
    );
  }

  List<Waypoint> _plannerStops(_ChallengePageData? data) {
    if (data == null) return const [];
    final waypoints = data.detail.orderedWaypoints;
    if (data.detail.challenge.accessMode != AccessMode.story) {
      return waypoints;
    }
    final hidden = storyHiddenWaypointIds(
      mode: AccessMode.story,
      hasAccess: _rules.hasAccess(
        pricing: data.detail.challenge.pricingType,
        purchased: data.purchase?.isPaid ?? false,
      ),
      ordered: waypoints,
      completedIds: data.progress?.completedWaypointIds ?? const {},
    );
    return [
      for (final waypoint in waypoints)
        if (!hidden.contains(waypoint.id)) waypoint,
    ];
  }

  Waypoint? _destinationOf(List<Waypoint> waypoints) {
    if (waypoints.isEmpty) return null;
    for (final waypoint in waypoints) {
      if (waypoint.id == _route.destinationId) return waypoint;
    }
    return waypoints.first;
  }

  double? _catalogElevationAt(double lat, double lng) {
    final places = _catalogPlaces;
    if (places == null) return null;
    return catalogPlaceAt(places, lat, lng)?.elevationM;
  }

  /// Uses `places.elevation_m` when a catalog row shares this coordinate.
  /// A missing height leaves the endpoint unchanged.
  RouteEndpoint _withCatalogElevation(
    RouteEndpoint endpoint,
    List<Place> places,
  ) {
    return endpoint.withCatalogElevation(
      catalogPlaceAt(places, endpoint.lat, endpoint.lng)?.elevationM,
    );
  }

  Future<void> _refreshRoutes([List<Waypoint>? waypoints]) async {
    final services = context.read<AppServices>();
    final localeController = context.read<LocaleController>();
    final strings = localeController.strings;
    final locale = localeController.locale;
    final places = waypoints ?? _plannerStops(await _future);
    if (!mounted) return;
    final start = _route.start;
    final destination = _destinationOf(places);
    if (start == null || destination == null) {
      _route.apply((route) {
        route.routes = null;
        route.routing = false;
        route.routeError = null;
        route.navigating = null;
      });
      return;
    }
    if ((start.lat - destination.lat).abs() < 0.00001 &&
        (start.lng - destination.lng).abs() < 0.00001) {
      _route.apply((route) {
        route.routes = null;
        route.routing = false;
        route.routeError = strings.routeSamePoint;
        route.navigating = null;
      });
      return;
    }
    final token = ++_routeToken;
    _route.apply((route) {
      route.routing = true;
      route.routeError = null;
    });
    try {
      final catalogPlaces = _catalogPlaces ?? const <Place>[];
      final plan =
          await DualRoutePlanner(
            routing: services.routing,
            elevation: services.elevation,
          ).plan(
            start: _withCatalogElevation(start, catalogPlaces),
            end: _withCatalogElevation(
              RouteEndpoint.fromWaypoint(destination, locale),
              catalogPlaces,
            ),
          );
      if (!mounted || token != _routeToken) return;
      _route.apply((route) {
        route.routing = false;
        route.routes = plan;
        route.routeError = plan.isEmpty ? strings.routeLoadFailed : null;
        if (plan.hike == null && route.navigating == TravelMode.hike) {
          route.navigating = null;
        }
        if (plan.bike == null && route.navigating == TravelMode.bike) {
          route.navigating = null;
        }
        if (plan.isEmpty) route.navigating = null;
      });
    } catch (_) {
      if (!mounted || token != _routeToken) return;
      _route.apply((route) {
        route.routing = false;
        route.routes = null;
        route.routeError = strings.routeLoadFailed;
        route.navigating = null;
      });
    }
  }

  Future<void> _submitStartText(String raw) async {
    final strings = context.read<LocaleController>().strings;
    final services = context.read<AppServices>();
    final query = raw.trim();
    if (query.isEmpty) return;
    try {
      final data = await _future;
      final near = _destinationOf(_plannerStops(data))?.latLng;
      final found = await services.geocoder.findPlace(query, near: near);
      if (!mounted) return;
      if (found == null) {
        _route.apply((route) {
          route.start = null;
          route.routes = null;
          route.routeError = strings.routePlaceNotFound;
          route.navigating = null;
        });
        return;
      }
      _route.apply((route) {
        route.start = found;
        route.enteringCustomStart = true;
      });
      _startController.text = found.label;
      await _refreshRoutes();
    } catch (_) {
      if (!mounted) return;
      _route.apply((route) {
        route.routeError = strings.routePlaceNotFound;
        route.routes = null;
        route.navigating = null;
      });
    }
  }

  Future<void> _useGps() async {
    final strings = context.read<LocaleController>().strings;
    final services = context.read<AppServices>();
    try {
      final here = await services.deviceLocation.current();
      if (!mounted) return;
      _route.apply((route) {
        route.start = RouteEndpoint(
          lat: here.lat,
          lng: here.lng,
          label: strings.routeUseGps,
        );
        route.enteringCustomStart = false;
      });
      _startController.text = strings.routeUseGps;
      await _refreshRoutes();
    } on LocationFailure catch (error) {
      if (!mounted) return;
      _route.apply((route) {
        route.routeError = error.message == 'denied'
            ? strings.routeGpsDenied
            : strings.routeGpsFailed;
      });
    } catch (_) {
      if (!mounted) return;
      _route.apply((route) => route.routeError = strings.routeGpsFailed);
    }
  }

  void _chooseCustomStart() {
    _route.apply((route) => route.enteringCustomStart = true);
  }

  void _pickStartPlace(Waypoint waypoint, String locale) {
    final start = RouteEndpoint.fromWaypoint(waypoint, locale);
    _route.apply((route) {
      route.start = start;
      route.enteringCustomStart = false;
    });
    _startController.text = start.label;
    _refreshRoutes();
  }

  void _setDestination(Waypoint waypoint) {
    _route.apply((route) => route.destinationId = waypoint.id);
    _refreshRoutes();
  }

  void _startNavigation(TravelMode mode) {
    _route.apply((route) => route.navigating = mode);
  }

  void _endNavigation() {
    if (_route.navigating == null) return;
    _route.apply((route) => route.navigating = null);
  }

  GlobalKey _chapterKey(String id) =>
      _chapterKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _openVerify(
    String challengeId,
    String waypointId, {
    Place? place,
  }) async {
    final revealed = await context.push<String?>(
      '/verify/$challengeId/$waypointId',
      extra: place,
    );
    if (!mounted) return;
    if (revealed != null && revealed.isNotEmpty) {
      setState(() {
        _pendingRevealId = revealed;
        _revealScheduled = false;
      });
    }
    await _reload();
  }

  void _rejectLockedPlace() {
    final strings = context.read<LocaleController>().strings;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            strings.storyFogLocked,
            key: const Key('story-fog-locked'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: BrandColors.forest,
        ),
      );
  }

  void _scheduleStoryReveal(List<ChallengeFeedItem> feed) {
    final id = _pendingRevealId;
    if (id == null || _revealScheduled) return;
    final shown = feed.any(
      (item) => item is StoryFeedChapter && item.step.id == id,
    );
    if (!shown) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_revealChapter(id));
    });
  }

  /// The next chapter sits below the map and planner, so a sliver may not
  /// have built it yet. Walk the feed until the key exists, then expand it
  /// into view.
  Future<void> _revealChapter(String id) async {
    for (var attempt = 0; attempt < 24; attempt++) {
      if (!mounted) return;
      final target = _chapterKeys[id]?.currentContext;
      if (target != null && target.mounted && mounted) {
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final duration = reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 350);
        if (!target.mounted) return;
        await Scrollable.ensureVisible(
          target,
          alignment: 0.12,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (!_feedScroll.hasClients) {
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      final position = _feedScroll.position;
      if (!position.hasContentDimensions || !position.hasPixels) {
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      final next = position.pixels + position.viewportDimension * 0.8;
      if (next >= position.maxScrollExtent - 0.5) {
        if (position.pixels < position.maxScrollExtent) {
          position.jumpTo(position.maxScrollExtent);
          await WidgetsBinding.instance.endOfFrame;
          continue;
        }
        return;
      }
      position.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = context.watch<LocaleController>().strings;
    final body = FutureBuilder<_ChallengePageData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          if (widget.embedded && snapshot.error is ChallengeMissing) {
            return EmptyState(
              key: const Key('last-challenge-missing'),
              title: strings.lastChallengeMissing,
              hint: strings.lastChallengeEmptyHint,
              actionLabel: strings.lastChallengeBrowse,
              onAction: () => context.go('/'),
            );
          }
          return ErrorState(
            title: strings.errorGeneric,
            titleKey: const Key('challenge-load-error'),
            hint: strings.errorOfflineHint,
            retryLabel: strings.retry,
            onRetry: _reload,
          );
        }
        final data = snapshot.data!;
        final challenge = data.detail.challenge;
        final copy = challenge.copyFor(locale);
        final waypoints = data.detail.orderedWaypoints;
        final completed = data.progress?.completedWaypointIds ?? {};
        final hasAccess = _rules.hasAccess(
          pricing: challenge.pricingType,
          purchased: data.purchase?.isPaid ?? false,
        );
        final hidden = storyHiddenWaypointIds(
          mode: challenge.accessMode,
          hasAccess: hasAccess,
          ordered: waypoints,
          completedIds: completed,
        );
        final fog = storyFogPins(ordered: waypoints, hiddenIds: hidden);
        final plannerWaypoints = [
          for (final waypoint in waypoints)
            if (!hidden.contains(waypoint.id)) waypoint,
        ];
        final feed = buildChallengeFeed(
          mode: challenge.accessMode,
          hasAccess: hasAccess,
          ordered: waypoints,
          steps: data.detail.orderedStorySteps,
          completedIds: completed,
        );
        _scheduleStoryReveal(feed);
        final isComplete = _rules.isChallengeComplete(
          waypoints: waypoints,
          completedWaypointIds: completed,
        );
        final purchasePaid = data.purchase?.isPaid ?? false;
        final completeBy = ChallengeCompletionWindow.completeBy(
          data.purchase?.paidAt,
        );
        final diplomaEntitled = ChallengeReward.isDiplomaEntitled(
          challengeCompleted: isComplete,
          purchasePaid: purchasePaid,
        );
        final diplomaName = context
            .read<AppServices>()
            .auth
            .currentUser
            ?.displayName;
        final rewardLocked = !ChallengeReward.isRewardAccessible(
          purchasePaid: purchasePaid,
        );
        final gallery = data.photos;
        return LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = Breakpoints.challengeTwoColumn(
              constraints.maxWidth,
            );
            final compact = constraints.maxWidth < Breakpoints.compactMax;
            final scroll = CustomScrollView(
              key: const Key('challenge-feed-scroll'),
              controller: _feedScroll,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (challenge.coverImageUrl != null &&
                          challenge.coverImageUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusCard,
                          ),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: AppNetworkImage(
                              url: challenge.coverImageUrl,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        copy.title,
                        key: const Key('challenge-title'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _ChallengeProgress(
                        done: completed.length,
                        total: waypoints.length,
                        label: strings.challengeProgress(
                          completed.length,
                          waypoints.length,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ChallengeRouteBlock(
                        includeMap: !twoColumn,
                        route: _route,
                        waypoints: waypoints,
                        plannerWaypoints: plannerWaypoints,
                        hidden: hidden,
                        fog: fog,
                        strings: strings,
                        locale: locale,
                        startController: _startController,
                        destinationOf: _destinationOf,
                        elevationAt: _catalogElevationAt,
                        onWaypointTap: _setDestination,
                        onVerifyWaypoint: (waypoint, place) => _openVerify(
                          challenge.id,
                          waypoint.id,
                          place: place,
                        ),
                        onFogTap: () => _rejectLockedPlace(),
                        onStartNavigation: _startNavigation,
                        onEndNavigation: _endNavigation,
                        onStartSubmitted: _submitStartText,
                        onUseGps: _useGps,
                        onStartPlacePicked: (place) =>
                            _pickStartPlace(place, locale),
                        onCustomPlaceChosen: _chooseCustomStart,
                        onRetry: _refreshRoutes,
                      ),
                      if (copy.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          copy.description,
                          key: const Key('challenge-info'),
                        ),
                      ],
                      if (!hasAccess) ...[
                        const SizedBox(height: 16),
                        Text(
                          strings.challengeLockedPaid,
                          key: const Key('challenge-unlock-cta'),
                        ),
                      ],
                      if (!compact) ...[
                        const SizedBox(height: 16),
                        _offerPayCtas(challenge, strings),
                      ],
                      if (data.purchase?.status == PurchaseStatus.pending)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(strings.purchasePending),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        strings.waypoints,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final item in feed)
                        if (item is StoryFeedChapter)
                          KeyedSubtree(
                            key: _chapterKey(item.step.id),
                            child: StoryChapterCard(
                              step: item.step,
                              locale: locale,
                              initiallyExpanded:
                                  item.step.kind == StoryStepKind.opening,
                              expandOnce: _pendingRevealId == item.step.id,
                            ),
                          )
                        else if (item is StoryFeedPlace)
                          ListenableBuilder(
                            listenable: _route,
                            builder: (context, _) => _WaypointTile(
                              waypoint: item.waypoint,
                              locale: locale,
                              selected:
                                  item.waypoint.id == _route.destinationId,
                              unlocked: item.unlocked,
                              completed: item.completed,
                              mystery:
                                  challenge.accessMode == AccessMode.story &&
                                  !item.unlocked &&
                                  !item.completed,
                              displayTitle: storyPlaceTitle(
                                mode: challenge.accessMode,
                                unlocked: item.unlocked,
                                completed: item.completed,
                                waypoint: item.waypoint,
                                locale: locale,
                                lockedTitle: strings.storyNextStop,
                              ),
                              strings: strings,
                              onSelect: item.unlocked || item.completed
                                  ? () => _setDestination(item.waypoint)
                                  : _rejectLockedPlace,
                              onVerify: () =>
                                  _openVerify(challenge.id, item.waypoint.id),
                            ),
                          ),
                      const SizedBox(height: 16),
                      ChallengeDeadlineBanner(
                        strings: strings,
                        locale: locale,
                        paid: purchasePaid,
                        completeBy: completeBy,
                      ),
                      const SizedBox(height: 16),
                      ChallengeRewardSection(
                        strings: strings,
                        completed: isComplete,
                        entitled: diplomaEntitled,
                        locked: rewardLocked,
                        challengeId: challenge.id,
                        diplomas: context.read<AppServices>().diplomas,
                        hasDisplayName:
                            diplomaName != null &&
                            diplomaName.trim().isNotEmpty,
                        onSaveDiploma: diplomaEntitled
                            ? () => context.push(
                                '/diploma/${challenge.id}',
                                extra: data,
                              )
                            : null,
                        onUnlock: rewardLocked
                            ? () => _unlockPaid(RewardVariant.diploma)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      ChallengePhotosHeader(
                        title: strings.challengePhotosTitle,
                      ),
                      if (gallery.isEmpty) ...[
                        const SizedBox(height: 10),
                        ChallengePhotosEmpty(
                          message: strings.challengePhotosEmpty,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ]),
                  ),
                ),
                if (gallery.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    sliver: ChallengePhotoMosaicSliver(
                      photos: gallery,
                      waypoints: waypoints,
                    ),
                  ),
              ],
            );
            final page = twoColumn
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ChallengeRouteBlock(
                          includeMap: true,
                          mapOnly: true,
                          mapHeight: constraints.maxHeight,
                          route: _route,
                          waypoints: waypoints,
                          plannerWaypoints: plannerWaypoints,
                          hidden: hidden,
                          fog: fog,
                          strings: strings,
                          locale: locale,
                          startController: _startController,
                          destinationOf: _destinationOf,
                          elevationAt: _catalogElevationAt,
                          onWaypointTap: _setDestination,
                          onVerifyWaypoint: (waypoint, place) => _openVerify(
                            challenge.id,
                            waypoint.id,
                            place: place,
                          ),
                          onFogTap: () => _rejectLockedPlace(),
                          onStartNavigation: _startNavigation,
                          onEndNavigation: _endNavigation,
                          onStartSubmitted: _submitStartText,
                          onUseGps: _useGps,
                          onStartPlacePicked: (place) =>
                              _pickStartPlace(place, locale),
                          onCustomPlaceChosen: _chooseCustomStart,
                          onRetry: _refreshRoutes,
                        ),
                      ),
                      Expanded(child: scroll),
                    ],
                  )
                : scroll;
            return Column(
              children: [
                Expanded(child: page),
                if (compact)
                  _ChallengeStickyBar(
                    strings: strings,
                    hasAccess: hasAccess,
                    feed: feed,
                    pay: _offerPayCtas(challenge, strings),
                    onVerify: (id) => _openVerify(challenge.id, id),
                  ),
              ],
            );
          },
        );
      },
    );
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(strings.appName),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Center(child: BrandMark(size: 24)),
                ),
              ],
            ),
      body: widget.embedded ? SafeArea(bottom: false, child: body) : body,
    );
  }
}

class _ChallengeProgress extends StatelessWidget {
  const _ChallengeProgress({
    required this.done,
    required this.total,
    required this.label,
  });

  final int done;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Column(
      key: const Key('challenge-progress'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: BrandColors.forest,
            fontSize: AppTheme.labelSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: SizedBox(
            height: 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: BrandColors.sage),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: const ColoredBox(color: BrandColors.forest),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChallengeRouteBlock extends StatelessWidget {
  const _ChallengeRouteBlock({
    required this.route,
    required this.waypoints,
    required this.plannerWaypoints,
    required this.hidden,
    required this.fog,
    required this.strings,
    required this.locale,
    required this.startController,
    required this.destinationOf,
    required this.elevationAt,
    required this.onWaypointTap,
    required this.onVerifyWaypoint,
    required this.onFogTap,
    required this.onStartNavigation,
    required this.onEndNavigation,
    required this.onStartSubmitted,
    required this.onUseGps,
    required this.onStartPlacePicked,
    required this.onCustomPlaceChosen,
    required this.onRetry,
    this.includeMap = true,
    this.mapOnly = false,
    this.mapHeight = 280,
  });

  final ChallengeRouteController route;
  final List<Waypoint> waypoints;
  final List<Waypoint> plannerWaypoints;
  final Set<String> hidden;
  final List<StoryFogPin> fog;
  final AppStrings strings;
  final String locale;
  final TextEditingController startController;
  final Waypoint? Function(List<Waypoint> waypoints) destinationOf;
  final double? Function(double lat, double lng) elevationAt;
  final ValueChanged<Waypoint> onWaypointTap;
  final Future<void> Function(Waypoint waypoint, Place place) onVerifyWaypoint;
  final VoidCallback onFogTap;
  final ValueChanged<TravelMode> onStartNavigation;
  final VoidCallback onEndNavigation;
  final ValueChanged<String> onStartSubmitted;
  final VoidCallback onUseGps;
  final ValueChanged<Waypoint> onStartPlacePicked;
  final VoidCallback onCustomPlaceChosen;
  final VoidCallback onRetry;
  final bool includeMap;
  final bool mapOnly;
  final double mapHeight;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: route,
      builder: (context, _) {
        final destination = destinationOf(plannerWaypoints);
        final navigating = route.navigating;
        final map = ChallengeMap(
          height: mapHeight,
          waypoints: waypoints,
          hiddenWaypointIds: hidden,
          fogPins: fog,
          selectedWaypointId: destination?.id,
          start: route.start?.latLng,
          hikeLine: route.routes?.hikeLine ?? const <LatLng>[],
          bikeLine: route.routes?.bikeLine ?? const <LatLng>[],
          onWaypointTap: onWaypointTap,
          onVerifyWaypoint: onVerifyWaypoint,
          onFogTap: (_) => onFogTap(),
          navigating: navigating,
          navigationBanner: navigating == null
              ? null
              : _NavigationBanner(
                  title: navigating == TravelMode.bike
                      ? strings.routeNavigatingBike
                      : strings.routeNavigatingWalk,
                  endLabel: strings.routeEndNavigation,
                  onEnd: onEndNavigation,
                ),
          actions: [
            if (navigating == null && route.routes?.hike != null)
              _MapOsmAction(
                key: const Key('route-map-navigate-hike'),
                icon: Icons.hiking,
                label: strings.routeNavigate,
                tooltip: strings.routeWalking,
                onPressed: () => onStartNavigation(TravelMode.hike),
              ),
            if (navigating == null && route.routes?.bike != null)
              _MapOsmAction(
                key: const Key('route-map-navigate-bike'),
                icon: Icons.directions_bike,
                label: strings.routeNavigate,
                tooltip: strings.routeCycling,
                onPressed: () => onStartNavigation(TravelMode.bike),
              ),
          ],
        );
        if (mapOnly) return map;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (includeMap) map,
            if (includeMap) const SizedBox(height: 12),
            RoutePlannerPanel(
              strings: strings,
              locale: locale,
              waypoints: plannerWaypoints,
              startController: startController,
              onStartSubmitted: onStartSubmitted,
              onUseGps: onUseGps,
              onStartPlacePicked: onStartPlacePicked,
              onCustomPlaceChosen: onCustomPlaceChosen,
              showCustomStartField: route.enteringCustomStart,
              destination: destination,
              onDestinationChanged: onWaypointTap,
              loading: route.routing,
              startLabel: route.start?.label,
              startElevationM: route.start == null
                  ? null
                  : elevationAt(route.start!.lat, route.start!.lng),
              destinationElevationM: destination == null
                  ? null
                  : elevationAt(destination.lat, destination.lng),
              errorMessage: route.routeError,
              hike: route.routes?.hike,
              bike: route.routes?.bike,
              onRetry: onRetry,
              navigating: navigating,
              onStartNavigation: onStartNavigation,
              onEndNavigation: onEndNavigation,
            ),
          ],
        );
      },
    );
  }
}

class _ChallengeStickyBar extends StatelessWidget {
  const _ChallengeStickyBar({
    required this.strings,
    required this.hasAccess,
    required this.feed,
    required this.pay,
    required this.onVerify,
  });

  final AppStrings strings;
  final bool hasAccess;
  final List<ChallengeFeedItem> feed;
  final Widget pay;
  final ValueChanged<String> onVerify;

  @override
  Widget build(BuildContext context) {
    StoryFeedPlace? next;
    for (final item in feed) {
      if (item is StoryFeedPlace && item.unlocked && !item.completed) {
        next = item;
        break;
      }
    }
    return Material(
      color: BrandColors.cream,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasAccess && next != null) ...[
                FilledButton(
                  key: const Key('challenge-sticky-verify'),
                  onPressed: () => onVerify(next!.waypoint.id),
                  child: Text(strings.verify),
                ),
                const SizedBox(height: 8),
              ],
              pay,
            ],
          ),
        ),
      ),
    );
  }
}

class _ChallengePayCtas extends StatelessWidget {
  const _ChallengePayCtas({
    required this.strings,
    required this.challenge,
    required this.offer,
    required this.loading,
    required this.failed,
    required this.onPay,
  });

  static const gap = 10.0;
  static const minHeight = 52.0;
  static const narrowBreakpoint = 320.0;
  static const radius = 16.0;
  static const borderWidth = 1.5;
  static const labelSize = 15.5;
  static const priceSize = 16.5;
  static const priceGap = 5.0;
  static const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 11);

  final AppStrings strings;
  final Challenge challenge;
  final FapiOffer? offer;
  final bool loading;
  final bool failed;
  final ValueChanged<RewardVariant> onPay;

  /// Disabled variant stays a solid beige button with bark type so the
  /// label stays readable when that reward has no sale form.
  static ({Color background, Color foreground, Color border}) _colors({
    required bool outlined,
    required Set<WidgetState> states,
  }) {
    if (states.contains(WidgetState.disabled)) {
      return (
        background: outlined ? BrandColors.cream : BrandColors.beige,
        foreground: BrandColors.bark,
        border: BrandColors.bark,
      );
    }
    final pressed = states.contains(WidgetState.pressed);
    Color tone(Color color) => pressed ? color.withValues(alpha: 0.85) : color;
    return (
      background: tone(outlined ? BrandColors.cream : BrandColors.forest),
      foreground: tone(outlined ? BrandColors.forest : BrandColors.cream),
      border: tone(BrandColors.forest),
    );
  }

  ButtonStyle _ctaStyle({required bool outlined}) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, minHeight)),
      padding: const WidgetStatePropertyAll(padding),
      alignment: Alignment.center,
      visualDensity: VisualDensity.standard,
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => _colors(outlined: outlined, states: states).background,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => _colors(outlined: outlined, states: states).foreground,
      ),
      side: WidgetStateProperty.resolveWith((states) {
        if (!outlined) return BorderSide.none;
        return BorderSide(
          color: _colors(outlined: outlined, states: states).border,
          width: borderWidth,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stack = MediaQuery.sizeOf(context).width < narrowBreakpoint;
    final diploma = _payButton(
      key: const Key('challenge-pay-diploma'),
      priceKey: const Key('challenge-pay-diploma-price'),
      loadingKey: const Key('challenge-pay-diploma-price-loading'),
      fallbackKey: const Key('challenge-pay-diploma-price-fallback'),
      outlined: true,
      label: strings.payDigitalDiploma,
      variant: offer?.diploma,
      onPressed: challenge.fapiFormUrlFor(RewardVariant.diploma) == null
          ? null
          : () => onPay(RewardVariant.diploma),
    );
    final medal = _payButton(
      key: const Key('challenge-pay-medal'),
      priceKey: const Key('challenge-pay-medal-price'),
      loadingKey: const Key('challenge-pay-medal-price-loading'),
      fallbackKey: const Key('challenge-pay-medal-price-fallback'),
      outlined: false,
      label: strings.payMedalAndDiploma,
      variant: offer?.medal,
      onPressed: challenge.fapiFormUrlFor(RewardVariant.medalAndDiploma) == null
          ? null
          : () => onPay(RewardVariant.medalAndDiploma),
    );
    final buttons = stack
        ? Column(
            key: const Key('challenge-pay-ctas'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              diploma,
              const SizedBox(height: gap),
              medal,
            ],
          )
        : IntrinsicHeight(
            child: Row(
              key: const Key('challenge-pay-ctas'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 1, child: diploma),
                const SizedBox(width: gap),
                Expanded(flex: 1, child: medal),
              ],
            ),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buttons,
        const SizedBox(height: 8),
        Text(
          strings.paymentTrust,
          key: const Key('challenge-pay-trust'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: BrandColors.bark,
            fontSize: AppTheme.labelSize,
          ),
        ),
      ],
    );
  }

  Widget _payButton({
    required Key key,
    required Key priceKey,
    required Key loadingKey,
    required Key fallbackKey,
    required bool outlined,
    required String label,
    required FapiOfferVariant? variant,
    required VoidCallback? onPressed,
  }) {
    final states = <WidgetState>{if (onPressed == null) WidgetState.disabled};
    final ink = _colors(outlined: outlined, states: states).foreground;
    final price = loading || failed
        ? null
        : formatPayButtonPrice(
            cents: variant?.priceCents,
            currency: variant?.currency ?? '',
            locale: strings.locale,
            freeLabel: strings.payPriceFree,
          );
    final showFallback = !loading && failed;
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: labelSize,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: ink,
          ),
        ),
        if (loading) ...[
          const SizedBox(height: priceGap),
          Semantics(
            label: strings.payPriceLoading,
            child: SizedBox(
              key: loadingKey,
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: ink),
            ),
          ),
        ] else if (showFallback) ...[
          const SizedBox(height: priceGap),
          Text(
            strings.payPriceUnavailable,
            key: fallbackKey,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: ink,
            ),
          ),
        ] else if (price != null) ...[
          const SizedBox(height: priceGap),
          Text(
            price,
            key: priceKey,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: priceSize,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: ink,
            ),
          ),
        ],
      ],
    );
    final style = _ctaStyle(outlined: outlined);
    if (outlined) {
      return OutlinedButton(
        key: key,
        onPressed: onPressed,
        style: style,
        child: child,
      );
    }
    return FilledButton(
      key: key,
      onPressed: onPressed,
      style: style,
      child: child,
    );
  }
}

class _WaypointTile extends StatelessWidget {
  const _WaypointTile({
    required this.waypoint,
    required this.locale,
    required this.selected,
    required this.unlocked,
    required this.completed,
    required this.mystery,
    required this.displayTitle,
    required this.strings,
    required this.onSelect,
    required this.onVerify,
  });

  final Waypoint waypoint;
  final String locale;
  final bool selected;
  final bool unlocked;
  final bool completed;
  final bool mystery;
  final String displayTitle;
  final AppStrings strings;
  final VoidCallback onSelect;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final copy = waypoint.copyFor(locale);
    final subtitle = completed
        ? strings.verified
        : unlocked
        ? (copy.hint ?? copy.description)
        : strings.storyLockedHint;
    return Card(
      key: Key('waypoint-tile-${waypoint.id}'),
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mystery)
                StoryQuestionMark(key: Key('waypoint-mystery-${waypoint.id}'))
              else
                PlaceCategoryIcon(
                  iconName: waypoint.category.iconName,
                  iconKey: Key('waypoint-category-${waypoint.id}'),
                  semanticLabel: strings.t(waypoint.category.l10nKey),
                ),
              const SizedBox(width: PlaceRowMetrics.titleGap),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: PlaceRowMetrics.titleNudge,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        key: Key('waypoint-title-${waypoint.id}'),
                        style: PlaceRowMetrics.titleStyle,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BrandColors.bark,
                            fontSize: AppTheme.labelSize,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: PlaceRowMetrics.titleNudge),
                child: completed
                    ? const Icon(Icons.check_circle, color: BrandColors.success)
                    : unlocked
                    ? FilledButton(
                        onPressed: onVerify,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, AppTheme.minTap),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(strings.verify),
                      )
                    : const Icon(Icons.lock_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChallengePageData {
  const ChallengePageData({
    required this.detail,
    required this.progress,
    required this.purchase,
    this.photos = const [],
  });

  final ChallengeDetail detail;
  final ChallengeProgress? progress;
  final Purchase? purchase;
  final List<ChallengeGalleryPhoto> photos;
}

typedef _ChallengePageData = ChallengePageData;

class _NavigationBanner extends StatelessWidget {
  const _NavigationBanner({
    required this.title,
    required this.endLabel,
    required this.onEnd,
  });

  final String title;
  final String endLabel;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('route-navigation-active'),
      elevation: 2,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.navigation, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              key: const Key('route-end-navigation'),
              onPressed: onEnd,
              child: Text(endLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapOsmAction extends StatelessWidget {
  const _MapOsmAction({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}
