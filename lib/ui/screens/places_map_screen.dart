import 'package:flutter/material.dart';

import '../../map/place_catalog.dart';
import '../widgets/places_map_surface.dart';

/// Mapa tab: shared MapLibre places surface in the existing 4-item shell.
class PlacesMapScreen extends StatelessWidget {
  const PlacesMapScreen({super.key, this.catalog});

  final PlaceCatalog? catalog;

  @override
  Widget build(BuildContext context) {
    return PlacesMapSurface(catalog: catalog);
  }
}

/// Keeps the existing `/map` route type name used by [app.dart].
class ChallengesMapScreen extends PlacesMapScreen {
  const ChallengesMapScreen({super.key, super.catalog});
}
