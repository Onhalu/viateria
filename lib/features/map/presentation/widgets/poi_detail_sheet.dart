import 'package:flutter/material.dart';

import '../../../../core/l10n/map_strings.dart';
import '../../../../core/theme/map_colors.dart';
import '../../domain/poi.dart';
import '../../domain/poi_query.dart';

class PoiDetailSheet extends StatelessWidget {
  const PoiDetailSheet({
    super.key,
    required this.poi,
    required this.strings,
    required this.userLocation,
    required this.onClose,
    required this.onDetail,
  });

  final Poi poi;
  final MapStrings strings;
  final GeoPoint? userLocation;
  final VoidCallback onClose;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final km = userLocation == null
        ? null
        : distanceKm(userLocation!, poi.location);
    return Material(
      key: const Key('map-poi-sheet'),
      color: MapColors.surface.withValues(alpha: 0.94),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              poi.name,
              key: const Key('map-poi-sheet-name'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.categoryLabel(poi.category.l10nKey),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            if (km != null) ...[
              const SizedBox(height: 4),
              Text(
                strings.distanceKm(km),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('map-poi-detail'),
                    onPressed: onDetail,
                    style: FilledButton.styleFrom(
                      backgroundColor: MapColors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(strings.detailCta),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('map-poi-close'),
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(strings.closeCta),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
