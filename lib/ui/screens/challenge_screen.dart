import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_services.dart';
import '../../data/last_opened_challenge.dart';
import '../../data/repositories.dart';
import '../../data/route_services.dart';
import '../../domain/route_planner.dart';
import '../../domain/unlock_rules.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../widgets/challenge_map.dart';
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
  String? _routeError;
  int _routeToken = 0;

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
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _unlockPaid() async {
    final services = context.read<AppServices>();
    final session = await services.purchases.startCheckout(widget.challengeId);
    await launchUrl(
      Uri.parse(session.url),
      mode: LaunchMode.externalApplication,
    );
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
      });
      return;
    }
    if ((start.lat - destination.lat).abs() < 0.00001 &&
        (start.lng - destination.lng).abs() < 0.00001) {
      setState(() {
        _routes = null;
        _routing = false;
        _routeError = strings.routeSamePoint;
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
      });
    } catch (_) {
      if (!mounted || token != _routeToken) return;
      setState(() {
        _routing = false;
        _routes = null;
        _routeError = strings.routeLoadFailed;
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
        });
        return;
      }
      setState(() {
        _start = found;
        _startController.text = found.label;
      });
      await _refreshRoutes();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routeError = strings.routePlaceNotFound;
        _routes = null;
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

  void _pickStartPlace(Waypoint? waypoint, String locale) {
    if (waypoint == null) {
      final keepTyped = _start?.waypointId == null;
      setState(() {
        if (!keepTyped) {
          _start = null;
          _routes = null;
          _routeError = null;
        }
      });
      return;
    }
    setState(() {
      _start = RouteEndpoint.fromWaypoint(waypoint, locale);
      _startController.text = _start!.label;
    });
    _refreshRoutes();
  }

  void _setDestination(Waypoint waypoint) {
    setState(() => _destinationId = waypoint.id);
    _refreshRoutes();
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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              copy.title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(copy.description),
            const SizedBox(height: 12),
            ChallengeMap(
              waypoints: waypoints,
              selectedWaypointId: destination?.id,
              start: _start?.latLng,
              hikeLine: _routes?.hikeLine ?? const <LatLng>[],
              bikeLine: _routes?.bikeLine ?? const <LatLng>[],
              onWaypointTap: _setDestination,
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
              destination: destination,
              onDestinationChanged: _setDestination,
              startPlaceId: _start?.waypointId,
              loading: _routing,
              startLabel: _start?.label,
              errorMessage: _routeError,
              hike: _routes?.hike,
              bike: _routes?.bike,
              onRetry: _refreshRoutes,
            ),
            const SizedBox(height: 16),
            if (!hasAccess) ...[
              Text(strings.challengeLockedPaid),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _unlockPaid,
                child: Text(strings.unlockWithStripe),
              ),
              if (data.purchase?.status == PurchaseStatus.pending)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(strings.purchasePending),
                ),
            ],
            if (isComplete)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.tonal(
                  onPressed: () =>
                      context.push('/diploma/${challenge.id}', extra: data),
                  child: Text(strings.viewDiploma),
                ),
              ),
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
          ],
        );
      },
    );
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(strings.appName)),
      body: widget.embedded ? SafeArea(bottom: false, child: body) : body,
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
            ? const Icon(Icons.check_circle, color: Color(0xFF2D6A4F))
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
