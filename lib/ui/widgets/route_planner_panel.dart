import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/route_planner.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';

class RoutePlannerPanel extends StatelessWidget {
  const RoutePlannerPanel({
    super.key,
    required this.strings,
    required this.locale,
    required this.waypoints,
    required this.startController,
    required this.onStartSubmitted,
    required this.onUseGps,
    required this.onStartPlacePicked,
    required this.destination,
    required this.onDestinationChanged,
    required this.startPlaceId,
    required this.loading,
    this.startLabel,
    this.errorMessage,
    this.hike,
    this.bike,
    this.onRetry,
  });

  final AppStrings strings;
  final String locale;
  final List<Waypoint> waypoints;
  final TextEditingController startController;
  final ValueChanged<String> onStartSubmitted;
  final VoidCallback onUseGps;
  final ValueChanged<Waypoint?> onStartPlacePicked;
  final Waypoint? destination;
  final ValueChanged<Waypoint> onDestinationChanged;
  final String? startPlaceId;
  final bool loading;
  final String? startLabel;
  final String? errorMessage;
  final RouteSummary? hike;
  final RouteSummary? bike;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.routePlanner,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              strings.routeStart,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('route-start-field'),
                    controller: startController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: strings.routeStartHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: onStartSubmitted,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('route-start-submit'),
                  tooltip: strings.routeSearch,
                  onPressed: () => onStartSubmitted(startController.text),
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('route-use-gps'),
              onPressed: onUseGps,
              icon: const Icon(Icons.my_location),
              label: Text(strings.routeUseGps),
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: const Key('route-start-place'),
              child: DropdownButtonFormField<String?>(
                key: ValueKey(startPlaceId ?? 'none'),
                initialValue: startPlaceId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: strings.routeFromPlace,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(strings.routeChoosePlace),
                  ),
                  for (final waypoint in waypoints)
                    DropdownMenuItem<String?>(
                      value: waypoint.id,
                      child: Text(waypoint.copyFor(locale).title),
                    ),
                ],
                onChanged: (id) {
                  if (id == null) {
                    onStartPlacePicked(null);
                    return;
                  }
                  final match = waypoints.where((w) => w.id == id);
                  onStartPlacePicked(match.isEmpty ? null : match.first);
                },
              ),
            ),
            if (startLabel != null && startLabel!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(startLabel!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            KeyedSubtree(
              key: const Key('route-destination-place'),
              child: DropdownButtonFormField<String>(
                key: ValueKey(destination?.id ?? 'none'),
                initialValue: destination?.id,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: strings.routeDestination,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final waypoint in waypoints)
                    DropdownMenuItem<String>(
                      value: waypoint.id,
                      child: Text(waypoint.copyFor(locale).title),
                    ),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  final match = waypoints.where((w) => w.id == id);
                  if (match.isNotEmpty) onDestinationChanged(match.first);
                },
              ),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                key: Key('route-loading'),
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (hike != null || bike != null) ...[
              if (hike != null)
                _RouteStatsCard(
                  key: const Key('route-hike-stats'),
                  title: strings.routeWalking,
                  icon: Icons.hiking,
                  summary: hike!,
                  strings: strings,
                ),
              if (hike != null && bike != null) const SizedBox(height: 8),
              if (bike != null)
                _RouteStatsCard(
                  key: const Key('route-bike-stats'),
                  title: strings.routeCycling,
                  icon: Icons.directions_bike,
                  summary: bike!,
                  strings: strings,
                ),
            ] else
              _RouteEmpty(
                message: errorMessage ?? strings.routeNeedTwoPoints,
                retryLabel: errorMessage == null ? null : strings.retry,
                onRetry: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteEmpty extends StatelessWidget {
  const _RouteEmpty({required this.message, this.retryLabel, this.onRetry});

  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('route-empty'),
      children: [
        Text(message, textAlign: TextAlign.center),
        if (retryLabel != null && onRetry != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(retryLabel!)),
        ],
      ],
    );
  }
}

class _RouteStatsCard extends StatelessWidget {
  const _RouteStatsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.summary,
    required this.strings,
  });

  final String title;
  final IconData icon;
  final RouteSummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Stat(
              label: strings.distance,
              value: '${summary.distanceKm.toStringAsFixed(1)} km',
            ),
            _Stat(label: strings.time, value: summary.timeLabel),
            _Stat(
              label: strings.elevation,
              value: '${summary.elevationGainM.round()} m',
            ),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(summary.osmUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.map_outlined),
              label: Text(strings.openInOsm),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
