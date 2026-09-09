import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../map/place.dart';
import '../../map/place_category.dart';
import '../../map/place_query.dart';
import 'map_chrome.dart';

Future<Set<PlaceCategory>?> showMapFilterSheet({
  required BuildContext context,
  required AppStrings strings,
  required Set<PlaceCategory> selected,
}) {
  return showModalBottomSheet<Set<PlaceCategory>>(
    context: context,
    backgroundColor: MapOverlayColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _FilterBody(strings: strings, initial: selected),
  );
}

class _FilterBody extends StatefulWidget {
  const _FilterBody({required this.strings, required this.initial});

  final AppStrings strings;
  final Set<PlaceCategory> initial;

  @override
  State<_FilterBody> createState() => _FilterBodyState();
}

class _FilterBodyState extends State<_FilterBody> {
  late Set<PlaceCategory> _selected = Set<PlaceCategory>.from(widget.initial);

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.filtersTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in PlaceCategory.values)
                  FilterChip(
                    key: Key('map-filter-${category.name}'),
                    label: Text(strings.t(category.l10nKey)),
                    selected: _selected.contains(category),
                    selectedColor: MapOverlayColors.accent,
                    checkmarkColor: Colors.white,
                    labelStyle: const TextStyle(color: Colors.white),
                    backgroundColor: Colors.white12,
                    onSelected: (on) {
                      setState(() {
                        if (on) {
                          _selected.add(category);
                        } else {
                          _selected.remove(category);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(
                      () => _selected = Set<PlaceCategory>.from(
                        PlaceCategory.values,
                      ),
                    );
                  },
                  child: Text(strings.selectAll),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('map-filter-apply'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MapOverlayColors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 48),
                  ),
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(strings.applyFilters),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceDetailSheet extends StatelessWidget {
  const PlaceDetailSheet({
    super.key,
    required this.place,
    required this.strings,
    required this.userLocation,
    required this.onClose,
    required this.onDetail,
  });

  final Place place;
  final AppStrings strings;
  final GeoPoint? userLocation;
  final VoidCallback onClose;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final km = userLocation == null
        ? null
        : distanceKm(userLocation!, place.location);
    return Material(
      key: const Key('map-poi-sheet'),
      color: MapOverlayColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              place.name,
              key: const Key('map-poi-sheet-name'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.t(place.category.l10nKey),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            if (km != null) ...[
              const SizedBox(height: 4),
              Text(
                strings.formatDistanceKm(km),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('map-poi-detail'),
                    onPressed: onDetail,
                    style: FilledButton.styleFrom(
                      backgroundColor: MapOverlayColors.accent,
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

class PlaceListPanel extends StatelessWidget {
  const PlaceListPanel({
    super.key,
    required this.places,
    required this.strings,
    required this.userLocation,
    required this.onSelect,
  });

  final List<Place> places;
  final AppStrings strings;
  final GeoPoint? userLocation;
  final ValueChanged<Place> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('map-poi-list'),
      color: const Color(0xF2F7F3E9),
      child: places.isEmpty
          ? Center(
              child: Text(
                strings.monumentCount(0),
                style: const TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                final km = userLocation == null
                    ? null
                    : distanceKm(userLocation!, place.location);
                return ListTile(
                  key: Key('map-poi-list-${place.id}'),
                  minVerticalPadding: 14,
                  title: Text(
                    place.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      strings.t(place.category.l10nKey),
                      if (km != null) strings.formatDistanceKm(km),
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelect(place),
                );
              },
            ),
    );
  }
}
