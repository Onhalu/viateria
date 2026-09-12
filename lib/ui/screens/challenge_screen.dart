import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/last_opened_challenge.dart';
import '../../data/repositories.dart';
import '../../data/route_services.dart';
import '../../domain/challenge_reward.dart';
import '../../domain/route_planner.dart';
import '../../domain/unlock_rules.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../theme/brand_assets.dart';
import '../../theme/brand_colors.dart';
import '../widgets/challenge_map.dart';
import '../widgets/challenge_reward_section.dart';
import '../widgets/empty_state.dart';
import '../widgets/route_planner_panel.dart';

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
  static const _rules = UnlockRules();

  Future<_ChallengePageData>? _future;
  final _startController = TextEditingController();

  String? _destinationId;
  RouteEndpoint? _start;
  DualRoutePlan? _routes;
  var _routing = false;
  var _enteringCustomStart = false;
  String? _routeError;
  int _routeToken = 0;
  TravelMode? _navigating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
    context.read<LastOpenedChallengeStore>().remember(widget.challengeId);
  }

  @override
  void dispose() {
    _startController.dispose();
    super.dispose();
  }

  Future<_ChallengePageData> _load() async {
    final services = context.read<AppServices>();
    final detail = await services.catalog.fetchChallenge(widget.challengeId);
    final progress = await services.progress.fetchProgress(widget.challengeId);
    final purchase = await services.purchases.fetchPurchase(widget.challengeId);
    return _ChallengePageData(
      detail: detail,
      progress: progress,
      purchase: purchase,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _unlockPaid(RewardVariant variant) async {
    final services = context.read<AppServices>();
    final session = await services.purchases.startCheckout(
      widget.challengeId,
      rewardVariant: variant,
    );
    await services.openUrl(Uri.parse(session.url));
    await services.purchases.refreshPurchase(widget.challengeId);
    if (mounted) await _reload();
  }

  Waypoint? _destinationOf(List<Waypoint> waypoints) {
    if (waypoints.isEmpty) return null;
    for (final waypoint in waypoints) {
      if (waypoint.id == _destinationId) return waypoint;
    }
    return waypoints.first;
  }

  Future<void> _refreshRoutes([List<Waypoint>? waypoints]) async {
    final services = context.read<AppServices>();
    final localeController = context.read<LocaleController>();
    final strings = localeController.strings;
    final locale = localeController.locale;
    final places =
        waypoints ??
        (await _future)?.detail.orderedWaypoints ??
        const <Waypoint>[];
    if (!mounted) return;
    final start = _start;
    final destination = _destinationOf(places);
    if (start == null || destination == null) {
      setState(() {
        _routes = null;
        _routing = false;
        _routeError = null;
        _navigating = null;
      });
      return;
    }
    if ((start.lat - destination.lat).abs() < 0.00001 &&
        (start.lng - destination.lng).abs() < 0.00001) {
      setState(() {
        _routes = null;
        _routing = false;
        _routeError = strings.routeSamePoint;
        _navigating = null;
      });
      return;
    }
    final token = ++_routeToken;
    setState(() {
      _routing = true;
      _routeError = null;
    });
    try {
      final plan =
          await DualRoutePlanner(
            routing: services.routing,
            elevation: services.elevation,
          ).plan(
            start: start,
            end: RouteEndpoint.fromWaypoint(destination, locale),
          );
      if (!mounted || token != _routeToken) return;
      setState(() {
        _routing = false;
        _routes = plan;
        _routeError = plan.isEmpty ? strings.routeLoadFailed : null;
        if (plan.hike == null && _navigating == TravelMode.hike) {
          _navigating = null;
        }
        if (plan.bike == null && _navigating == TravelMode.bike) {
          _navigating = null;
        }
        if (plan.isEmpty) _navigating = null;
      });
    } catch (_) {
      if (!mounted || token != _routeToken) return;
      setState(() {
        _routing = false;
        _routes = null;
        _routeError = strings.routeLoadFailed;
        _navigating = null;
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
      final near = _destinationOf(data?.detail.orderedWaypoints ?? const [])
          ?.latLng;
      final found = await services.geocoder.findPlace(query, near: near);
      if (!mounted) return;
      if (found == null) {
        setState(() {
          _start = null;
          _routes = null;
          _routeError = strings.routePlaceNotFound;
          _navigating = null;
        });
        return;
      }
      setState(() {
        _start = found;
        _startController.text = found.label;
        _enteringCustomStart = true;
      });
      await _refreshRoutes();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routeError = strings.routePlaceNotFound;
        _routes = null;
        _navigating = null;
      });
    }
  }

  Future<void> _useGps() async {
    final strings = context.read<LocaleController>().strings;
    final services = context.read<AppServices>();
    try {
      final here = await services.deviceLocation.current();
      if (!mounted) return;
      setState(() {
        _start = RouteEndpoint(
          lat: here.lat,
          lng: here.lng,
          label: strings.routeUseGps,
        );
        _startController.text = strings.routeUseGps;
        _enteringCustomStart = false;
      });
      await _refreshRoutes();
    } on LocationFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _routeError = error.message == 'denied'
            ? strings.routeGpsDenied
            : strings.routeGpsFailed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _routeError = strings.routeGpsFailed);
    }
  }

  void _chooseCustomStart() {
    setState(() => _enteringCustomStart = true);
  }

  void _pickStartPlace(Waypoint waypoint, String locale) {
    setState(() {
      _start = RouteEndpoint.fromWaypoint(waypoint, locale);
      _startController.text = _start!.label;
      _enteringCustomStart = false;
    });
    _refreshRoutes();
  }

  void _setDestination(Waypoint waypoint) {
    setState(() => _destinationId = waypoint.id);
    _refreshRoutes();
  }

  void _startNavigation(TravelMode mode) {
    setState(() => _navigating = mode);
  }

  void _endNavigation() {
    if (_navigating == null) return;
    setState(() => _navigating = null);
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.errorGeneric,
                  key: const Key('challenge-load-error'),
                  textAlign: TextAlign.center,
                ),
                TextButton(onPressed: _reload, child: Text(strings.retry)),
              ],
            ),
          );
        }
        final data = snapshot.data!;
        final challenge = data.detail.challenge;
        final copy = challenge.copyFor(locale);
        final waypoints = data.detail.orderedWaypoints;
        final destination = _destinationOf(waypoints);
        final completed = data.progress?.completedWaypointIds ?? {};
        final hasAccess = _rules.hasAccess(
          pricing: challenge.pricingType,
          purchased: data.purchase?.isPaid ?? false,
        );
        final isComplete = _rules.isChallengeComplete(
          waypoints: waypoints,
          completedWaypointIds: completed,
        );
        final purchasePaid = data.purchase?.isPaid ?? false;
        final completeBy = ChallengeCompletionWindow.completeBy(
          data.purchase?.paidAt,
        );
        final rewardUnlocked = ChallengeReward.isUnlocked(
          challengeCompleted: isComplete,
          purchasePaid: purchasePaid,
          requiresPurchase: challenge.isPaid,
        );
        final rewardVariant = ChallengeReward.variant(
          purchase: data.purchase,
          productVariant: challenge.rewardVariant,
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              copy.title,
              key: const Key('challenge-title'),
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ChallengeMap(
              waypoints: waypoints,
              selectedWaypointId: destination?.id,
              start: _start?.latLng,
              hikeLine: _routes?.hikeLine ?? const <LatLng>[],
              bikeLine: _routes?.bikeLine ?? const <LatLng>[],
              onWaypointTap: _setDestination,
              navigating: _navigating,
              navigationBanner: _navigating == null
                  ? null
                  : _NavigationBanner(
                      title: _navigating == TravelMode.bike
                          ? strings.routeNavigatingBike
                          : strings.routeNavigatingWalk,
                      endLabel: strings.routeEndNavigation,
                      onEnd: _endNavigation,
                    ),
              actions: [
                if (_navigating == null && _routes?.hike != null)
                  _MapOsmAction(
                    key: const Key('route-map-navigate-hike'),
                    icon: Icons.hiking,
                    label: strings.routeNavigate,
                    tooltip: strings.routeWalking,
                    onPressed: () => _startNavigation(TravelMode.hike),
                  ),
                if (_navigating == null && _routes?.bike != null)
                  _MapOsmAction(
                    key: const Key('route-map-navigate-bike'),
                    icon: Icons.directions_bike,
                    label: strings.routeNavigate,
                    tooltip: strings.routeCycling,
                    onPressed: () => _startNavigation(TravelMode.bike),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            RoutePlannerPanel(
              strings: strings,
              locale: locale,
              waypoints: waypoints,
              startController: _startController,
              onStartSubmitted: _submitStartText,
              onUseGps: _useGps,
              onStartPlacePicked: (place) => _pickStartPlace(place, locale),
              onCustomPlaceChosen: _chooseCustomStart,
              showCustomStartField: _enteringCustomStart,
              destination: destination,
              onDestinationChanged: _setDestination,
              loading: _routing,
              startLabel: _start?.label,
              errorMessage: _routeError,
              hike: _routes?.hike,
              bike: _routes?.bike,
              onRetry: _refreshRoutes,
              navigating: _navigating,
              onStartNavigation: _startNavigation,
              onEndNavigation: _endNavigation,
            ),
            if (copy.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(copy.description, key: const Key('challenge-info')),
            ],
            if (!hasAccess) ...[
              const SizedBox(height: 16),
              Text(
                strings.challengeLockedPaid,
                key: const Key('challenge-unlock-cta'),
              ),
              const SizedBox(height: 8),
              _ChallengePayCtas(
                strings: strings,
                onPay: _unlockPaid,
              ),
              if (data.purchase?.status == PurchaseStatus.pending)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(strings.purchasePending),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              strings.waypoints,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < waypoints.length; i++)
              _WaypointTile(
                waypoint: waypoints[i],
                locale: locale,
                selected: waypoints[i].id == destination?.id,
                unlocked: _rules.isWaypointUnlocked(
                  mode: challenge.accessMode,
                  hasAccess: hasAccess,
                  waypointIndex: i,
                  completedIndexes: {
                    for (var j = 0; j < waypoints.length; j++)
                      if (completed.contains(waypoints[j].id)) j,
                  },
                ),
                completed: completed.contains(waypoints[i].id),
                strings: strings,
                onSelect: () => _setDestination(waypoints[i]),
                onVerify: () =>
                    context.push('/verify/${challenge.id}/${waypoints[i].id}'),
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
              unlocked: rewardUnlocked,
              paid: purchasePaid,
              variant: rewardVariant,
              onSaveDiploma: rewardUnlocked
                  ? () => context.push('/diploma/${challenge.id}', extra: data)
                  : null,
            ),
          ],
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

class _ChallengePayCtas extends StatelessWidget {
  const _ChallengePayCtas({required this.strings, required this.onPay});

  static const gap = 10.0;
  static const minHeight = 48.0;
  static const narrowBreakpoint = 320.0;

  final AppStrings strings;
  final ValueChanged<RewardVariant> onPay;

  @override
  Widget build(BuildContext context) {
    final stack = MediaQuery.sizeOf(context).width < narrowBreakpoint;
    final diploma = _payButton(
      key: const Key('challenge-pay-diploma'),
      outlined: true,
      label: strings.payDigitalDiploma,
      onPressed: () => onPay(RewardVariant.diploma),
    );
    final medal = _payButton(
      key: const Key('challenge-pay-medal'),
      outlined: false,
      label: strings.payMedalAndDiploma,
      onPressed: () => onPay(RewardVariant.medalAndDiploma),
    );
    if (stack) {
      return Column(
        key: const Key('challenge-pay-ctas'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          diploma,
          const SizedBox(height: gap),
          medal,
        ],
      );
    }
    return IntrinsicHeight(
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
  }

  Widget _payButton({
    required Key key,
    required bool outlined,
    required String label,
    required VoidCallback onPressed,
  }) {
    final child = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 12);
    if (outlined) {
      return OutlinedButton(
        key: key,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, minHeight),
          backgroundColor: BrandColors.cream,
          foregroundColor: BrandColors.forest,
          side: const BorderSide(color: BrandColors.forest),
          padding: padding,
          alignment: Alignment.center,
          visualDensity: VisualDensity.standard,
        ),
        child: child,
      );
    }
    return FilledButton(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, minHeight),
        backgroundColor: BrandColors.forest,
        foregroundColor: BrandColors.cream,
        padding: padding,
        alignment: Alignment.center,
        visualDensity: VisualDensity.standard,
      ),
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
    required this.strings,
    required this.onSelect,
    required this.onVerify,
  });

  final Waypoint waypoint;
  final String locale;
  final bool selected;
  final bool unlocked;
  final bool completed;
  final AppStrings strings;
  final VoidCallback onSelect;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final copy = waypoint.copyFor(locale);
    return Card(
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: onSelect,
        leading: CircleAvatar(child: Text('${waypoint.sortOrder + 1}')),
        title: Text(copy.title),
        subtitle: Text(
          completed
              ? strings.verified
              : unlocked
              ? (copy.hint ?? copy.description)
              : strings.storyLockedHint,
        ),
        trailing: completed
            ? const Icon(Icons.check_circle, color: BrandColors.success)
            : unlocked
            ? FilledButton(onPressed: onVerify, child: Text(strings.verify))
            : const Icon(Icons.lock_outline),
      ),
    );
  }
}

class ChallengePageData {
  const ChallengePageData({
    required this.detail,
    required this.progress,
    required this.purchase,
  });

  final ChallengeDetail detail;
  final ChallengeProgress? progress;
  final Purchase? purchase;
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
