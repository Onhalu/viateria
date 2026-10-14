import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../domain/route_planner.dart';
import '../../l10n/locale_controller.dart';
import '../../map/place.dart';
import '../../map/place_catalog.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';
import '../layout/breakpoints.dart';
import '../widgets/places_map_surface.dart';

/// Mapa tab: shared MapLibre places surface in the existing 4-item shell.
class PlacesMapScreen extends StatefulWidget {
  const PlacesMapScreen({super.key, this.catalog});

  final PlaceCatalog? catalog;

  @override
  State<PlacesMapScreen> createState() => _PlacesMapScreenState();
}

class _PlacesMapScreenState extends State<PlacesMapScreen> {
  final List<Place> _stops = [];
  var _open = false;
  var _expanded = false;

  void _add(Place place) {
    setState(() {
      if (_stops.every((stop) => stop.id != place.id)) {
        _stops.add(place);
      }
      _open = true;
      _expanded = true;
    });
  }

  void _cancel() {
    setState(() {
      _stops.clear();
      _open = false;
      _expanded = false;
    });
  }

  double get _km {
    if (_stops.length < 2) return 0;
    final waypoints = [
      for (var i = 0; i < _stops.length; i++)
        RouteEndpoint.fromPlace(_stops[i]).toWaypoint(sortOrder: i),
    ];
    return const RoutePlanner()
        .plan(mode: TravelMode.hike, waypoints: waypoints)
        .distanceKm;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    final line = [
      for (final stop in _stops)
        LatLng(stop.location.latitude, stop.location.longitude),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePanel = constraints.maxWidth >= Breakpoints.mediumMax;
        final map = PlacesMapSurface(
          catalog: widget.catalog,
          catalogRoute: line,
          onAddToRoute: _add,
        );
        final panel = _RoutePanel(
          stops: _stops,
          expanded: _expanded || _stops.isEmpty,
          summary: strings.routeStopsSummary(_stops.length, _km),
          cancelLabel: strings.cancelRoute,
          emptyLabel: strings.addToRoute,
          onCancel: _cancel,
          onToggle: () => setState(() => _expanded = !_expanded),
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              final stop = _stops.removeAt(oldIndex);
              _stops.insert(newIndex, stop);
            });
          },
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
                  onPressed: () => setState(() {
                    _open = true;
                    _expanded = true;
                  }),
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
                  child: SizedBox(
                    height: (_expanded && _stops.isNotEmpty) ? 360 : 72,
                    width: 480,
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

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({
    required this.stops,
    required this.expanded,
    required this.summary,
    required this.cancelLabel,
    required this.emptyLabel,
    required this.onCancel,
    required this.onToggle,
    required this.onReorderItem,
  });

  final List<Place> stops;
  final bool expanded;
  final String summary;
  final String cancelLabel;
  final String emptyLabel;
  final VoidCallback onCancel;
  final VoidCallback onToggle;
  final void Function(int oldIndex, int newIndex) onReorderItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 72,
          child: InkWell(
            key: const Key('map-route-summary'),
            onTap: stops.isEmpty ? null : onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      stops.isEmpty ? emptyLabel : summary,
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
                    child: Text(cancelLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded && stops.isNotEmpty)
          Expanded(
            child: ReorderableListView.builder(
              key: const Key('map-route-stops'),
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              itemCount: stops.length,
              onReorderItem: onReorderItem,
              itemBuilder: (context, index) {
                final stop = stops[index];
                return ListTile(
                  key: ValueKey(stop.id),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(
                      Icons.drag_handle,
                      color: BrandColors.bark,
                    ),
                  ),
                  title: Text(
                    stop.name,
                    style: const TextStyle(color: BrandColors.forest),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Keeps the existing `/map` route type name used by [app.dart].
class ChallengesMapScreen extends PlacesMapScreen {
  const ChallengesMapScreen({super.key, super.catalog});
}
