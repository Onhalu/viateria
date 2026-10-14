import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/route_services.dart';
import '../../domain/route_planner.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../map/place.dart';
import '../../map/place_catalog.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';
import '../layout/breakpoints.dart';
import '../widgets/places_map_surface.dart';
import '../widgets/route_start_field.dart';

/// Mapa tab: shared MapLibre places surface in the existing 4-item shell.
///
/// The route lives on this [State] for the session only. Nothing is written
/// to disk.
class PlacesMapScreen extends StatefulWidget {
  const PlacesMapScreen({super.key, this.catalog});

  final PlaceCatalog? catalog;

  @override
  State<PlacesMapScreen> createState() => _PlacesMapScreenState();
}

class _PlacesMapScreenState extends State<PlacesMapScreen> {
  final _startController = TextEditingController();
  final _startFocus = FocusNode();
  Place? _destination;
  RouteEndpoint? _start;
  List<LatLng> _line = const [];
  String? _error;
  var _open = false;
  var _routing = false;

  @override
  void dispose() {
    _startController.dispose();
    _startFocus.dispose();
    super.dispose();
  }

  void _add(Place place) {
    setState(() {
      _destination = place;
      _open = true;
      _error = null;
    });
    if (_start == null) unawaited(_applyDefaultStart());
    unawaited(_refreshRoute());
  }

  void _openPlanner() {
    setState(() => _open = true);
    if (_start == null && _startController.text.isEmpty) {
      unawaited(_applyDefaultStart());
    }
  }

  Future<void> _applyDefaultStart() async {
    final services = context.read<AppServices>();
    final strings = context.read<LocaleController>().strings;
    final start = await resolveRouteStart(
      location: services.deviceLocation,
      label: strings.locateTooltip,
    );
    if (!mounted) return;
    if (start == null) {
      setState(() {
        _start = null;
        _error = null;
      });
      _startController.clear();
      _startFocus.requestFocus();
      return;
    }
    setState(() {
      _start = start;
      _error = null;
      _startController.text = start.label;
    });
    await _refreshRoute();
  }

  Future<void> _useGps() async {
    await _applyDefaultStart();
  }

  Future<void> _submitStart(String raw) async {
    final strings = context.read<LocaleController>().strings;
    final services = context.read<AppServices>();
    final query = raw.trim();
    if (query.isEmpty) return;
    try {
      final near = _destination == null
          ? null
          : LatLng(
              _destination!.location.latitude,
              _destination!.location.longitude,
            );
      final found = await services.geocoder.findPlace(query, near: near);
      if (!mounted) return;
      if (found == null) {
        setState(() {
          _start = null;
          _line = const [];
          _error = strings.routePlaceNotFound;
        });
        return;
      }
      setState(() {
        _start = found;
        _error = null;
        _startController.text = found.label;
      });
      await _refreshRoute();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _line = const [];
        _error = strings.routePlaceNotFound;
      });
    }
  }

  Future<void> _refreshRoute() async {
    final start = _start;
    final destination = _destination;
    if (start == null || destination == null) {
      if (mounted) setState(() => _line = const []);
      return;
    }
    final services = context.read<AppServices>();
    setState(() => _routing = true);
    try {
      final plan = await DualRoutePlanner(
        routing: services.routing,
        elevation: services.elevation,
      ).plan(start: start, end: RouteEndpoint.fromPlace(destination));
      if (!mounted) return;
      final line = plan.hikeLine.isNotEmpty ? plan.hikeLine : plan.bikeLine;
      setState(() {
        _routing = false;
        _line = line;
        _error = plan.isEmpty ? servicesError(context) : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routing = false;
        _line = [
          LatLng(start.lat, start.lng),
          LatLng(destination.location.latitude, destination.location.longitude),
        ];
        _error = null;
      });
    }
  }

  String? servicesError(BuildContext context) {
    return context.read<LocaleController>().strings.routeLoadFailed;
  }

  void _cancel() {
    setState(() {
      _destination = null;
      _start = null;
      _line = const [];
      _error = null;
      _open = false;
      _routing = false;
      _startController.clear();
    });
  }

  double get _km {
    if (_line.length < 2) return 0;
    final waypoints = [
      for (var i = 0; i < _line.length; i++)
        RouteEndpoint(
          lat: _line[i].latitude,
          lng: _line[i].longitude,
          label: '$i',
        ).toWaypoint(sortOrder: i),
    ];
    return const RoutePlanner()
        .plan(mode: TravelMode.hike, waypoints: waypoints)
        .distanceKm;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePanel = constraints.maxWidth >= Breakpoints.mediumMax;
        final map = PlacesMapSurface(
          catalog: widget.catalog,
          catalogRoute: _line,
          onAddToRoute: _add,
        );
        final panel = _CatalogRoutePanel(
          strings: strings,
          destination: _destination,
          startController: _startController,
          startFocus: _startFocus,
          autofocus: _open && _start == null && _startController.text.isEmpty,
          summary: _destination == null
              ? strings.addToRoute
              : strings.routeStopsSummary(1, _km),
          error: _error,
          routing: _routing,
          onCancel: _cancel,
          onSubmitted: _submitStart,
          onUseGps: _useGps,
        );
        if (sidePanel && _open) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: map),
              SizedBox(
                width: 400,
                child: Material(
                  key: const Key('map-route-panel'),
                  color: BrandColors.cream,
                  child: panel,
                ),
              ),
            ],
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            map,
            if (!_open)
              Positioned(
                left: 12,
                bottom: 12 + MediaQuery.paddingOf(context).bottom,
                child: _PlanRouteButton(
                  label: strings.planRoute,
                  onPressed: _openPlanner,
                ),
              ),
            if (_open)
              Positioned(
                left: 12,
                right: sidePanel ? null : 12,
                bottom: 12 + MediaQuery.paddingOf(context).bottom,
                child: Material(
                  key: const Key('map-route-panel'),
                  color: BrandColors.cream,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: panel,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlanRouteButton extends StatelessWidget {
  const _PlanRouteButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('map-plan-route'),
      color: BrandColors.cream,
      elevation: 3,
      shadowColor: BrandColors.forest.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.route, color: BrandColors.forest),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: BrandColors.forest,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogRoutePanel extends StatelessWidget {
  const _CatalogRoutePanel({
    required this.strings,
    required this.destination,
    required this.startController,
    required this.startFocus,
    required this.autofocus,
    required this.summary,
    required this.error,
    required this.routing,
    required this.onCancel,
    required this.onSubmitted,
    required this.onUseGps,
  });

  final AppStrings strings;
  final Place? destination;
  final TextEditingController startController;
  final FocusNode startFocus;
  final bool autofocus;
  final String summary;
  final String? error;
  final bool routing;
  final VoidCallback onCancel;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onUseGps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    summary,
                    key: const Key('map-route-summary'),
                    style: const TextStyle(
                      color: BrandColors.forest,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('map-route-cancel'),
                  onPressed: onCancel,
                  child: Text(strings.cancelRoute),
                ),
              ],
            ),
          ),
          RouteStartField(
            controller: startController,
            focusNode: startFocus,
            strings: strings,
            autofocus: autofocus,
            onSubmitted: onSubmitted,
            onUseGps: onUseGps,
          ),
          if (destination != null) ...[
            const SizedBox(height: 8),
            Text(
              destination!.name,
              key: const Key('map-route-destination'),
              style: const TextStyle(
                color: BrandColors.forest,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (routing)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                key: const Key('map-route-error'),
                style: const TextStyle(color: BrandColors.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// Keeps the existing `/map` route type name used by [app.dart].
class ChallengesMapScreen extends PlacesMapScreen {
  const ChallengesMapScreen({super.key, super.catalog});
}
