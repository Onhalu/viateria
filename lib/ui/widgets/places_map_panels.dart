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
                color: MapPalette.forest,
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
                    checkmarkColor: MapPalette.forest,
                    labelStyle: const TextStyle(color: MapPalette.forest),
                    backgroundColor: MapPalette.beige,
                    side: const BorderSide(color: MapPalette.beige),
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
                  style: TextButton.styleFrom(
                    foregroundColor: MapPalette.forest,
                  ),
                  child: Text(strings.selectAll),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('map-filter-apply'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MapPalette.forest,
                    foregroundColor: MapPalette.cream,
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
    this.compact = false,
  });

  final Place place;
  final AppStrings strings;
  final GeoPoint? userLocation;
  final VoidCallback onClose;
  final VoidCallback onDetail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final km = userLocation == null
        ? null
        : distanceKm(userLocation!, place.location);
    final pad = compact
        ? const EdgeInsets.fromLTRB(12, 8, 12, 12)
        : const EdgeInsets.fromLTRB(20, 10, 20, 16);
    final titleSize = compact ? 16.0 : 22.0;
    final buttonHeight = compact ? 40.0 : 48.0;
    return Material(
      key: const Key('map-poi-sheet'),
      color: MapOverlayColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: pad,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MapPalette.beige,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            SizedBox(height: compact ? 8 : 16),
            Text(
              place.name,
              key: const Key('map-poi-sheet-name'),
              style: TextStyle(
                color: MapPalette.forest,
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.t(place.category.l10nKey),
              style: const TextStyle(color: MapPalette.bark, fontSize: 14),
            ),
            if (km != null) ...[
              const SizedBox(height: 2),
              Text(
                strings.formatDistanceKm(km),
                style: const TextStyle(color: MapPalette.bark, fontSize: 13),
              ),
            ],
            SizedBox(height: compact ? 12 : 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('map-poi-detail'),
                    onPressed: onDetail,
                    style: FilledButton.styleFrom(
                      backgroundColor: MapPalette.forest,
                      foregroundColor: MapPalette.cream,
                      minimumSize: Size.fromHeight(buttonHeight),
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
                      foregroundColor: MapPalette.forest,
                      side: const BorderSide(color: MapPalette.beige),
                      minimumSize: Size.fromHeight(buttonHeight),
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
    this.compact = false,
  });

  final List<Place> places;
  final AppStrings strings;
  final GeoPoint? userLocation;
  final ValueChanged<Place> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('map-poi-list'),
      color: MapPalette.creamFill,
      child: places.isEmpty
          ? Center(
              child: Text(
                strings.monumentCount(0),
                style: const TextStyle(fontSize: 16, color: MapPalette.bark),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(bottom: compact ? 8 : 24),
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                final km = userLocation == null
                    ? null
                    : distanceKm(userLocation!, place.location);
                return ListTile(
                  key: Key('map-poi-list-${place.id}'),
                  dense: compact,
                  minVerticalPadding: compact ? 8 : 14,
                  title: Text(
                    place.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: MapPalette.forest,
                    ),
                  ),
                  subtitle: Text(
                    [
                      strings.t(place.category.l10nKey),
                      if (km != null) strings.formatDistanceKm(km),
                    ].join(' · '),
                    style: const TextStyle(color: MapPalette.bark),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MapPalette.bark,
                  ),
                  onTap: () => onSelect(place),
                );
              },
            ),
    );
  }
}
