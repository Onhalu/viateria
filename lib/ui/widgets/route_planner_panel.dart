import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/route_planner.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';

class RoutePlannerPanel extends StatefulWidget {
  const RoutePlannerPanel({
    super.key,
    required this.strings,
    required this.locale,
    required this.waypoints,
    required this.startController,
    required this.onStartSubmitted,
    required this.onUseGps,
    required this.onStartPlacePicked,
    required this.onCustomPlaceChosen,
    required this.showCustomStartField,
    required this.destination,
    required this.onDestinationChanged,
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
  final ValueChanged<Waypoint> onStartPlacePicked;
  final VoidCallback onCustomPlaceChosen;
  final bool showCustomStartField;
  final Waypoint? destination;
  final ValueChanged<Waypoint> onDestinationChanged;
  final bool loading;
  final String? startLabel;
  final String? errorMessage;
  final RouteSummary? hike;
  final RouteSummary? bike;
  final VoidCallback? onRetry;

  @override
  State<RoutePlannerPanel> createState() => _RoutePlannerPanelState();
}

class _RoutePlannerPanelState extends State<RoutePlannerPanel> {
  var _listOpen = false;

  void _closeList() {
    if (_listOpen) setState(() => _listOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
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
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  ListTile(
                    key: const Key('route-start-picker'),
                    title: Text(strings.routeStart),
                    subtitle: Text(
                      widget.startLabel == null || widget.startLabel!.isEmpty
                          ? strings.routeChoosePlace
                          : widget.startLabel!,
                    ),
                    trailing: Icon(
                      _listOpen ? Icons.expand_less : Icons.expand_more,
                    ),
                    onTap: () => setState(() => _listOpen = !_listOpen),
                  ),
                  if (_listOpen)
                    Column(
                      key: const Key('route-start-sheet'),
                      children: [
                        ListTile(
                          key: const Key('route-start-custom'),
                          leading: const Icon(Icons.edit_location_alt_outlined),
                          title: Text(strings.routeCustomPlace),
                          onTap: () {
                            _closeList();
                            widget.onCustomPlaceChosen();
                          },
                        ),
                        ListTile(
                          key: const Key('route-use-gps'),
                          leading: const Icon(Icons.my_location),
                          title: Text(strings.routeUseGps),
                          onTap: () {
                            _closeList();
                            widget.onUseGps();
                          },
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              strings.routePlacesInChallenge,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        for (final waypoint in widget.waypoints)
                          ListTile(
                            key: Key('route-start-place-${waypoint.id}'),
                            leading: CircleAvatar(
                              child: Text('${waypoint.sortOrder + 1}'),
                            ),
                            title: Text(waypoint.copyFor(widget.locale).title),
                            onTap: () {
                              _closeList();
                              widget.onStartPlacePicked(waypoint);
                            },
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (widget.showCustomStartField) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('route-start-field'),
                      controller: widget.startController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: strings.routeStartHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: widget.onStartSubmitted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    key: const Key('route-start-submit'),
                    tooltip: strings.routeSearch,
                    onPressed: () =>
                        widget.onStartSubmitted(widget.startController.text),
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            KeyedSubtree(
              key: const Key('route-destination-place'),
              child: DropdownButtonFormField<String>(
                key: ValueKey(widget.destination?.id ?? 'none'),
                initialValue: widget.destination?.id,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: strings.routeDestination,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final waypoint in widget.waypoints)
                    DropdownMenuItem<String>(
                      value: waypoint.id,
                      child: Text(waypoint.copyFor(widget.locale).title),
                    ),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  final match = widget.waypoints.where((w) => w.id == id);
                  if (match.isNotEmpty) {
                    widget.onDestinationChanged(match.first);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            if (widget.loading)
              const Padding(
                key: Key('route-loading'),
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (widget.hike != null || widget.bike != null) ...[
              if (widget.hike != null)
                _RouteStatsCard(
                  key: const Key('route-hike-stats'),
                  title: strings.routeWalking,
                  icon: Icons.hiking,
                  summary: widget.hike!,
                  strings: strings,
                ),
              if (widget.hike != null && widget.bike != null)
                const SizedBox(height: 8),
              if (widget.bike != null)
                _RouteStatsCard(
                  key: const Key('route-bike-stats'),
                  title: strings.routeCycling,
                  icon: Icons.directions_bike,
                  summary: widget.bike!,
                  strings: strings,
                ),
              if ((widget.hike?.elevationGainM == null &&
                      widget.hike != null) ||
                  (widget.bike?.elevationGainM == null &&
                      widget.bike != null)) ...[
                const SizedBox(height: 8),
                if (widget.onRetry != null)
                  Center(
                    child: TextButton(
                      onPressed: widget.onRetry,
                      child: Text(strings.retry),
                    ),
                  ),
              ],
            ] else
              _RouteEmpty(
                message: widget.errorMessage ?? strings.routeNeedTwoPoints,
                retryLabel: widget.errorMessage == null ? null : strings.retry,
                onRetry: widget.onRetry,
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
              key: summary.elevationGainM == null
                  ? Key('route-elevation-missing-${summary.mode.name}')
                  : null,
              label: strings.elevation,
              value: summary.elevationGainM == null
                  ? strings.routeElevationFailed
                  : '${summary.elevationGainM!.round()} m',
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
  const _Stat({super.key, required this.label, required this.value});

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
