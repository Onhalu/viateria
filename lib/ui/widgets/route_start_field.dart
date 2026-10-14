import 'package:flutter/material.dart';

import '../../data/route_services.dart';
import '../../domain/route_planner.dart';
import '../../l10n/app_strings.dart';

/// Fulltext start plus GPS. Shared by the challenge planner and the main map.
class RouteStartField extends StatelessWidget {
  const RouteStartField({
    super.key,
    required this.controller,
    required this.strings,
    required this.onSubmitted,
    required this.onUseGps,
    this.focusNode,
    this.autofocus = false,
    this.showGps = true,
  });

  final TextEditingController controller;
  final AppStrings strings;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onUseGps;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Challenge start list already has a GPS row. The map planner uses this one.
  final bool showGps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('route-start-field'),
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: strings.routeStartHint,
              border: const OutlineInputBorder(),
              isDense: true,
              prefixIcon: const Icon(Icons.search),
            ),
            onSubmitted: onSubmitted,
          ),
        ),
        if (showGps) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: const Key('route-use-gps'),
            tooltip: strings.routeUseGps,
            onPressed: onUseGps,
            icon: const Icon(Icons.my_location),
          ),
        ],
        const SizedBox(width: 8),
        IconButton.filledTonal(
          key: const Key('route-start-submit'),
          tooltip: strings.routeSearch,
          onPressed: () => onSubmitted(controller.text),
          icon: const Icon(Icons.search),
        ),
      ],
    );
  }
}

/// GPS fix labeled for the start field. Null when location is unavailable.
/// Callers show an empty focused field instead of an error.
Future<RouteEndpoint?> resolveRouteStart({
  required DeviceLocation location,
  required String label,
}) async {
  try {
    final here = await location.current();
    return RouteEndpoint(lat: here.lat, lng: here.lng, label: label);
  } catch (_) {
    return null;
  }
}
