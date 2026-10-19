import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/last_opened_challenge.dart';
import '../../data/repositories.dart';
import '../../data/route_services.dart';
import '../../domain/challenge_photos.dart';
import '../../domain/challenge_reward.dart';
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
import '../challenge_route_controller.dart';
import '../layout/breakpoints.dart';
import '../layout/map_search_metrics.dart';
import '../widgets/app_shell.dart';
import '../widgets/challenge_hero.dart';
import '../widgets/challenge_map.dart';
import '../widgets/error_state.dart';
import '../widgets/challenge_photos_section.dart';
import '../widgets/challenge_reward_section.dart';
import '../widgets/empty_state.dart';
import '../widgets/place_presentation.dart';
import '../widgets/route_planner_panel.dart';
import '../widgets/story_chapter_card.dart';
import '../fapi_checkout_window.dart';
import 'diploma_screen.dart';

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
  final _startController = TextEditingController();
  final _feedScroll = ScrollController();
  final _route = ChallengeRouteController();
  final _payBarShown = ValueNotifier<bool>(false);

  int _routeToken = 0;
  String? _pendingRevealId;
  var _revealScheduled = false;
  var _payScroll = false;
  var _paySuppressed = false;
  final _inlinePayKey = GlobalKey();
  double? _inlinePayTop;
  double? _inlinePayBottom;
  final _chapterKeys = <String, GlobalKey>{};
  final _revealIndexes = <String, int>{};
  var _feedItemCount = 0;

  @override
  void initState() {
    super.initState();
    _feedScroll.addListener(_onFeedOffset);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
    context.read<LastOpenedChallengeStore>().remember(widget.challengeId);
  }

  @override
  void didUpdateWidget(ChallengeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challengeId == widget.challengeId) return;
    _future = _load();
  }

  void _onFeedOffset() {
    if (!_feedScroll.hasClients) return;
    final position = _feedScroll.position;
    if (!position.hasViewportDimension) return;
    _payScroll = paymentBarShouldShow(
      currentlyVisible: _payScroll,
      offset: position.pixels,
      viewport: position.viewportDimension,
    );
    _publishPayBar();
  }

  void _publishPayBar() {
    final visible = floatingPayBarShouldShow(
      scrolledEnough: _payScroll,
      inlineVisibleFraction: _inlinePayVisibleFraction(),
      suppressed: _paySuppressed,
      paid: _payPaid,
    );
    if (visible != _payBarShown.value) _payBarShown.value = visible;
  }

  var _payPaid = false;

  double _inlinePayVisibleFraction() {
    if (!_feedScroll.hasClients) return 1;
    final position = _feedScroll.position;
    if (!position.hasViewportDimension) return 1;
    final targetContext = _inlinePayKey.currentContext;
    final target = targetContext?.findRenderObject();
    if (target is RenderBox && target.attached && target.hasSize) {
      final viewport = RenderAbstractViewport.maybeOf(target);
      if (viewport != null) {
        final reveal = viewport.getOffsetToReveal(target, 0);
        _inlinePayTop = reveal.offset;
        _inlinePayBottom = reveal.offset + target.size.height;
      }
    }
    final top = _inlinePayTop;
    final bottom = _inlinePayBottom;
    if (top == null || bottom == null) return 1;
    return inlinePayVisibleFraction(
      blockTop: top,
      blockBottom: bottom,
      scrollOffset: position.pixels,
      viewport: position.viewportDimension,
    );
  }

  @override
  void dispose() {
    _feedScroll.removeListener(_onFeedOffset);
    _startController.dispose();
    _feedScroll.dispose();
    _payBarShown.dispose();
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
    });
    await _future;
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
    _paySuppressed = true;
    _publishPayBar();
    try {
      await showInAppFapiCheckout(
        context,
        challengeId: widget.challengeId,
        checkoutUrl: checkoutUrl,
      );
    } finally {
      _paySuppressed = false;
      _publishPayBar();
    }
    if (!mounted) return;
    await _reload();
  }

  Widget _payCtas(
    Challenge challenge,
    AppStrings strings, {
    bool bar = false,
  }) {
    return _ChallengePayCtas(
      strings: strings,
      challenge: challenge,
      onPay: _unlockPaid,
      bar: bar,
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

  Widget _feedSliver(List<Widget> children) {
    _feedItemCount = children.length;
    for (var i = 0; i < children.length; i++) {
      final key = children[i].key;
      if (key == null) continue;
      for (final entry in _chapterKeys.entries) {
        if (identical(entry.value, key)) {
          _revealIndexes[entry.key] = i;
        }
      }
    }
    return SliverList.builder(
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

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

  /// Lazy sliver children are built near the viewport. One post-frame
  /// [Scrollable.ensureVisible] brings the revealed chapter in. If it is not
  /// mounted yet, nudge once toward its index and try again.
  Future<void> _revealChapter(String id) async {
    await _ensureChapter(id, nudged: false);
  }

  Future<void> _ensureChapter(String id, {required bool nudged}) async {
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 400);
    final target = _chapterKeys[id]?.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.1,
        duration: duration,
        curve: Curves.easeOut,
      );
      return;
    }
    if (nudged || !_feedScroll.hasClients) return;
    final index = _revealIndexes[id];
    final position = _feedScroll.position;
    if (!position.hasContentDimensions) return;
    final targetOffset = index == null
        ? position.pixels + position.viewportDimension * 0.75
        : position.maxScrollExtent *
              (index / (_feedItemCount <= 1 ? 1 : _feedItemCount - 1));
    position.jumpTo(targetOffset.clamp(0.0, position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_ensureChapter(id, nudged: true));
    });
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
            _payPaid = purchasePaid;
            final cover = challenge.coverImageUrl;
            final hasCover = cover != null && cover.isNotEmpty;
            _revealIndexes.clear();
            final scroll = CustomScrollView(
              key: const Key('challenge-feed-scroll'),
              controller: _feedScroll,
              scrollCacheExtent: const ScrollCacheExtent.pixels(1200),
              slivers: [
                if (hasCover)
                  ChallengeCollapsingHero(
                    url: cover,
                    title: copy.title,
                    location: challengeLocationLine(challenge, locale),
                    layoutWidth: twoColumn
                        ? constraints.maxWidth / 2
                        : constraints.maxWidth,
                    focalY: challenge.heroFocalY,
                    backLabel: strings.back,
                    onBack: widget.embedded ? null : () => context.pop(),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: _feedSliver([
                    if (!hasCover) ...[
                      Text(
                        copy.title,
                        key: const Key('challenge-title'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ChallengeProgress(
                      done: completed.length,
                      total: waypoints.length,
                      label: strings.challengeProgress(
                        completed.length,
                        waypoints.length,
                      ),
                    ),
                    if (copy.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _ChallengeDescriptionCard(text: copy.description),
                    ],
                    const SizedBox(height: 40),
                    KeyedSubtree(
                      key: _inlinePayKey,
                      child: purchasePaid && completeBy != null
                          ? _PayDeadlineRow(
                              key: const Key('challenge-pay-deadline'),
                              label: strings.rewardDeadlineLabel(
                                formatLocalDate(completeBy, locale),
                              ),
                            )
                          : _payCtas(challenge, strings),
                    ),
                    if (data.purchase?.status == PurchaseStatus.pending)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(strings.purchasePending),
                      ),
                    const SizedBox(height: 16),
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
                      onVerifyWaypoint: (waypoint, place) =>
                          _openVerify(challenge.id, waypoint.id, place: place),
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
                            selected: item.waypoint.id == _route.destinationId,
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
                      locale: locale,
                      completeBy: completeBy,
                      showDeadline: purchasePaid,
                      challengeId: challenge.id,
                      diplomas: context.read<AppServices>().diplomas,
                      hasDisplayName:
                          diplomaName != null && diplomaName.trim().isNotEmpty,
                      onSaveDiploma: diplomaEntitled
                          ? () => showDiplomaWindow(context, challenge.id)
                          : null,
                      onUnlock: rewardLocked
                          ? () => _unlockPaid(RewardVariant.diploma)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    ChallengePhotosHeader(title: strings.challengePhotosTitle),
                    if (gallery.isEmpty) ...[
                      const SizedBox(height: 10),
                      ChallengePhotosEmpty(
                        message: strings.challengePhotosEmpty,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!purchasePaid)
                      SizedBox(
                        key: const Key('challenge-payment-spacer'),
                        height: ChallengePaymentBarMetrics.occupiedHeight(
                          MediaQuery.sizeOf(context).width,
                          MediaQuery.paddingOf(context).bottom,
                        ),
                      ),
                  ]),
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
            final column = Column(
              children: [
                if (!hasCover && !widget.embedded)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      key: const Key('challenge-back'),
                      tooltip: strings.back,
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      color: BrandColors.forest,
                    ),
                  ),
                Expanded(child: page),
              ],
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _publishPayBar();
            });
            if (purchasePaid) return column;
            return Stack(
              children: [
                column,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _payBarShown,
                    builder: (context, shown, child) {
                      final reduce = MediaQuery.disableAnimationsOf(context);
                      return IgnorePointer(
                        ignoring: !shown,
                        child: ExcludeSemantics(
                          excluding: !shown,
                          child: AnimatedSlide(
                            offset: shown ? Offset.zero : const Offset(0, 1),
                            duration: reduce
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _ChallengePaymentBar(
                      strings: strings,
                      pay: _payCtas(challenge, strings, bar: true),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    return Scaffold(
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
        final viewport = MediaQuery.sizeOf(context).height;
        final width = MediaQuery.sizeOf(context).width;
        final mobileHeight = (viewport * 0.55).clamp(320.0, 480.0);
        final height = mapOnly ? mapHeight : mobileHeight;
        final mobile = width < Breakpoints.compactMax;
        final map = ChallengeMap(
          height: height,
          cooperativeGestures: mobile && !kIsWeb,
          zoomGesturesEnabled: !kIsWeb,
          expandLabel: mobile ? strings.expandMap : null,
          onExpand: mobile
              ? () => _openExpandedMap(
                  context,
                  height: viewport,
                  waypoints: waypoints,
                  hidden: hidden,
                  fog: fog,
                  destinationId: destination?.id,
                  start: route.start?.latLng,
                  hikeLine: route.routes?.hikeLine ?? const <LatLng>[],
                  bikeLine: route.routes?.bikeLine ?? const <LatLng>[],
                  onWaypointTap: onWaypointTap,
                  onVerifyWaypoint: onVerifyWaypoint,
                  onFogTap: onFogTap,
                  navigating: navigating,
                  strings: strings,
                  onEndNavigation: onEndNavigation,
                )
              : null,
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
            if (includeMap) _LazyChallengeMap(child: map),
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

void _openExpandedMap(
  BuildContext context, {
  required double height,
  required List<Waypoint> waypoints,
  required Set<String> hidden,
  required List<StoryFogPin> fog,
  required String? destinationId,
  required LatLng? start,
  required List<LatLng> hikeLine,
  required List<LatLng> bikeLine,
  required ValueChanged<Waypoint> onWaypointTap,
  required Future<void> Function(Waypoint waypoint, Place place)
  onVerifyWaypoint,
  required VoidCallback onFogTap,
  required TravelMode? navigating,
  required AppStrings strings,
  required VoidCallback onEndNavigation,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog.fullscreen(
        backgroundColor: BrandColors.neutral,
        child: Stack(
          children: [
            ChallengeMap(
              height: height,
              waypoints: waypoints,
              hiddenWaypointIds: hidden,
              fogPins: fog,
              selectedWaypointId: destinationId,
              start: start,
              hikeLine: hikeLine,
              bikeLine: bikeLine,
              onWaypointTap: onWaypointTap,
              onVerifyWaypoint: onVerifyWaypoint,
              onFogTap: (_) => onFogTap(),
              navigating: navigating,
              cooperativeGestures: false,
              zoomGesturesEnabled: true,
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                key: const Key('challenge-expand-map-close'),
                tooltip: strings.closeCta,
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: BrandColors.forest),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _LazyChallengeMap extends StatefulWidget {
  const _LazyChallengeMap({required this.child});

  final Widget child;

  @override
  State<_LazyChallengeMap> createState() => _LazyChallengeMapState();
}

class _LazyChallengeMapState extends State<_LazyChallengeMap> {
  final _key = GlobalKey();
  var _show = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted || _show) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final view = MediaQuery.sizeOf(context).height;
    if (bottom > 0 && top < view) setState(() => _show = true);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _check();
        return false;
      },
      child: KeyedSubtree(
        key: _key,
        child: _show
            ? widget.child
            : const ColoredBox(
                key: Key('challenge-map-skeleton'),
                color: Color(0x66D8CDB8),
                child: SizedBox(height: 320),
              ),
      ),
    );
  }
}

class _ChallengeDescriptionCard extends StatelessWidget {
  const _ChallengeDescriptionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('challenge-description'),
      color: BrandColors.cream,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: BrandColors.beige),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          key: const Key('challenge-info'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: BrandColors.forest,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _PayDeadlineRow extends StatelessWidget {
  const _PayDeadlineRow({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.event, color: BrandColors.forest, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BrandColors.forest,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// The floating pair waits until about half a viewport has scrolled, then
/// stays hidden while the in-page block is still 30% on screen, while FAPI
/// is open, and after the challenge is paid.
bool floatingPayBarShouldShow({
  required bool scrolledEnough,
  required double inlineVisibleFraction,
  required bool suppressed,
  required bool paid,
}) {
  return scrolledEnough &&
      inlineVisibleFraction < inlinePayHideFraction &&
      !suppressed &&
      !paid;
}

/// Share of the in-page block that intersects the viewport. Unmeasured
/// blocks count as fully visible so the floating pair cannot double up.
const inlinePayHideFraction = 0.30;

double inlinePayVisibleFraction({
  required double blockTop,
  required double blockBottom,
  required double scrollOffset,
  required double viewport,
}) {
  final height = blockBottom - blockTop;
  if (height <= 0 || viewport <= 0) return 1;
  final viewTop = blockTop - scrollOffset;
  final viewBottom = blockBottom - scrollOffset;
  final visibleTop = math.max(0.0, viewTop);
  final visibleBottom = math.min(viewport, viewBottom);
  final visible = math.max(0.0, visibleBottom - visibleTop);
  return (visible / height).clamp(0.0, 1.0);
}

/// Floating payment buttons. No panel behind them.
abstract final class ChallengePaymentBarMetrics {
  static const headingSize = 20.0;
  static const headingHeight = 24.0;
  static const topPadding = 0.0;
  static const headingGap = 8.0;
  static const phoneBottom = 4.0;
  static const desktopBottom = 12.0;
  static const visualHeight = 44.0;
  static const tapTarget = 48.0;
  static const labelSize = 15.0;
  static const minLabelSize = 14.0;
  static const letterSpacing = 0.1;
  static const rowGap = 32.0;
  static const wideGap = 40.0;
  static const narrowGap = 16.0;
  static const buttonMaxWidth = 168.0;
  static const wideButtonWidth = 176.0;
  static const wideBreakpoint = 600.0;
  static const narrowBreakpoint = 340.0;
  static const inlineMaxWidth = 440.0;
  static const inlineHeadingGap = 20.0;
  static const inlineNarrowGap = 8.0;
  static const spinner = 18.0;

  static double bottomPadding(double width) =>
      width >= wideBreakpoint ? desktopBottom : phoneBottom;

  static double bodyHeight(double width) =>
      headingHeight + headingGap + tapTarget + bottomPadding(width);

  static double occupiedHeight(double width, double safeBottom) =>
      bodyHeight(width) + safeBottom;
}

/// Each floating button's width. Under 340 dp the row uses [Expanded].
double floatingPayButtonWidth(double windowWidth) {
  if (windowWidth >= ChallengePaymentBarMetrics.wideBreakpoint) {
    return ChallengePaymentBarMetrics.wideButtonWidth;
  }
  final room =
      (windowWidth - 2 * kNavSideInset - ChallengePaymentBarMetrics.rowGap) /
      2;
  return math.min(ChallengePaymentBarMetrics.buttonMaxWidth, math.max(0, room));
}

double floatingPayGap(double windowWidth) {
  if (windowWidth < ChallengePaymentBarMetrics.narrowBreakpoint) {
    return ChallengePaymentBarMetrics.narrowGap;
  }
  if (windowWidth >= ChallengePaymentBarMetrics.wideBreakpoint) {
    return ChallengePaymentBarMetrics.wideGap;
  }
  return ChallengePaymentBarMetrics.rowGap;
}

/// Font size for a payment label. Starts at 15 and may scale down to 14.
double paymentBarLabelFontSize({
  required double textWidth,
  required double maxWidth,
}) {
  const base = ChallengePaymentBarMetrics.labelSize;
  const floor = ChallengePaymentBarMetrics.minLabelSize;
  if (!maxWidth.isFinite || maxWidth <= 0 || textWidth <= 0) return base;
  if (textWidth <= maxWidth) return base;
  return (base * maxWidth / textWidth).clamp(floor, base);
}

class _ChallengePaymentBar extends StatelessWidget {
  const _ChallengePaymentBar({
    required this.strings,
    required this.pay,
  });

  final AppStrings strings;
  final Widget pay;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      key: const Key('challenge-payment-bar'),
      padding: EdgeInsets.fromLTRB(
        media.left + kNavSideInset,
        0,
        media.right + kNavSideInset,
        ChallengePaymentBarMetrics.bottomPadding(width) + media.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.joinChallenge,
            key: const Key('challenge-paybar-heading'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              color: BrandColors.forest,
              fontSize: ChallengePaymentBarMetrics.headingSize,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: ChallengePaymentBarMetrics.headingGap),
          pay,
        ],
      ),
    );
  }
}

class _ChallengePayCtas extends StatelessWidget {
  const _ChallengePayCtas({
    required this.strings,
    required this.challenge,
    required this.onPay,
    this.bar = false,
  });

  final AppStrings strings;
  final Challenge challenge;
  final ValueChanged<RewardVariant> onPay;
  final bool bar;

  Key _key(String name) =>
      Key('${bar ? 'challenge-floating-pay' : 'challenge-pay'}-$name');

  @override
  Widget build(BuildContext context) {
    final sizes =
        Theme.of(context).extension<AppButtonSizes>() ?? AppButtonSizes.standard;
    final diploma = AppButton(
      key: _key('diploma'),
      label: strings.payDigitalDiploma,
      variant: AppButtonVariant.secondary,
      size: bar ? AppButtonSize.m : AppButtonSize.l,
      elevated: bar,
      loadingLabel: strings.buttonLoading,
      onPressed: challenge.fapiFormUrlFor(RewardVariant.diploma) == null
          ? null
          : () => onPay(RewardVariant.diploma),
    );
    final medal = AppButton(
      key: _key('medal'),
      label: strings.payMedalAndDiploma,
      variant: AppButtonVariant.primary,
      size: bar ? AppButtonSize.m : AppButtonSize.l,
      elevated: bar,
      loadingLabel: strings.buttonLoading,
      onPressed: challenge.fapiFormUrlFor(RewardVariant.medalAndDiploma) == null
          ? null
          : () => onPay(RewardVariant.medalAndDiploma),
    );
    if (bar) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = MediaQuery.sizeOf(context).width;
          final gap = floatingPayGap(width);
          if (width < ChallengePaymentBarMetrics.narrowBreakpoint) {
            return Row(
              key: _key('ctas'),
              children: [
                Expanded(child: diploma),
                SizedBox(width: gap),
                Expanded(child: medal),
              ],
            );
          }
          final buttonWidth = floatingPayButtonWidth(width);
          return Row(
            key: _key('ctas'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: buttonWidth, child: diploma),
              SizedBox(width: gap),
              SizedBox(width: buttonWidth, child: medal),
            ],
          );
        },
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ChallengePaymentBarMetrics.inlineMaxWidth,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow =
                constraints.maxWidth <
                ChallengePaymentBarMetrics.narrowBreakpoint;
            final heading = Text(
              strings.joinChallenge,
              key: const Key('challenge-pay-heading'),
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w600,
                fontSize: MediaQuery.sizeOf(context).width >=
                        ChallengePaymentBarMetrics.wideBreakpoint
                    ? 32
                    : 28,
                height: 1.2,
                color: BrandColors.forest,
              ),
            );
            final buttons = narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      medal,
                      const SizedBox(
                        height: ChallengePaymentBarMetrics.inlineNarrowGap,
                      ),
                      diploma,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: diploma),
                      SizedBox(width: sizes.gapPair),
                      Expanded(child: medal),
                    ],
                  );
            return Column(
              key: _key('ctas'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(
                  height: ChallengePaymentBarMetrics.inlineHeadingGap,
                ),
                buttons,
              ],
            );
          },
        ),
      ),
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
