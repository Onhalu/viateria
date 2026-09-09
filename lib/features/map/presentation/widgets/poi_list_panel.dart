import 'package:flutter/material.dart';

import '../../../../core/l10n/map_strings.dart';
import '../../domain/poi.dart';
import '../../domain/poi_query.dart';

class PoiListPanel extends StatelessWidget {
  const PoiListPanel({
    super.key,
    required this.pois,
    required this.strings,
    required this.userLocation,
    required this.onSelect,
  });

  final List<Poi> pois;
  final MapStrings strings;
  final GeoPoint? userLocation;
  final ValueChanged<Poi> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('map-poi-list'),
      color: const Color(0xF2F4F1EA),
      child: pois.isEmpty
          ? Center(
              child: Text(
                strings.poiCount(0),
                style: const TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: pois.length,
              itemBuilder: (context, index) {
                final poi = pois[index];
                final km = userLocation == null
                    ? null
                    : distanceKm(userLocation!, poi.location);
                return ListTile(
                  key: Key('map-poi-list-${poi.id}'),
                  minVerticalPadding: 14,
                  title: Text(
                    poi.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      strings.categoryLabel(poi.category.l10nKey),
                      if (km != null) strings.distanceKm(km),
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelect(poi),
                );
              },
            ),
    );
  }
}
