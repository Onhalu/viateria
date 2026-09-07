import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/route_planner.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';

class RoutePlannerPanel extends StatelessWidget {
  const RoutePlannerPanel({
    super.key,
    required this.summary,
    required this.mode,
    required this.onModeChanged,
    required this.strings,
  });

  final RouteSummary summary;
  final TravelMode mode;
  final ValueChanged<TravelMode> onModeChanged;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final hours = summary.estimatedTime.inHours;
    final minutes = summary.estimatedTime.inMinutes.remainder(60);
    final timeLabel = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.routePlanner,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<TravelMode>(
              segments: [
                ButtonSegment(
                  value: TravelMode.hike,
                  label: Text(strings.hike),
                  icon: const Icon(Icons.hiking),
                ),
                ButtonSegment(
                  value: TravelMode.bike,
                  label: Text(strings.bike),
                  icon: const Icon(Icons.directions_bike),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (value) => onModeChanged(value.first),
            ),
            const SizedBox(height: 12),
            _Stat(
              label: strings.distance,
              value: '${summary.distanceKm.toStringAsFixed(1)} km',
            ),
            _Stat(
              label: strings.elevation,
              value: '${summary.elevationGainM.round()} m',
            ),
            _Stat(label: strings.time, value: timeLabel),
            _Stat(
              label: strings.difficulty,
              value: strings.difficultyLabel(summary.difficulty.name),
            ),
            const SizedBox(height: 8),
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
