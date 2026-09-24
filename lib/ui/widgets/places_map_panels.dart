import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../map/place.dart';
import '../../map/place_category.dart';
import '../../map/place_query.dart';
import 'map_chrome.dart';
import 'place_presentation.dart';

class MapFilterSelection {
  const MapFilterSelection({
    required this.categories,
    this.challengeOnly = false,
  });

  final Set<PlaceCategory> categories;
  final bool challengeOnly;
}

Future<MapFilterSelection?> showMapFilterSheet({
  required BuildContext context,
  required AppStrings strings,
  required Set<PlaceCategory> selected,
  bool challengeOnly = false,
}) {
  return showModalBottomSheet<MapFilterSelection>(
    context: context,
    backgroundColor: MapOverlayColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _FilterBody(
      strings: strings,
      initial: selected,
      initialChallengeOnly: challengeOnly,
    ),
  );
}

class _FilterBody extends StatefulWidget {
  const _FilterBody({
    required this.strings,
    required this.initial,
    required this.initialChallengeOnly,
  });

  final AppStrings strings;
  final Set<PlaceCategory> initial;
  final bool initialChallengeOnly;

  @override
  State<_FilterBody> createState() => _FilterBodyState();
}

class _FilterBodyState extends State<_FilterBody> {
  late Set<PlaceCategory> _selected = Set<PlaceCategory>.from(widget.initial);
  late bool _challengeOnly = widget.initialChallengeOnly;

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
                  _filterChip(
                    key: Key('map-filter-${category.name}'),
                    label: strings.t(category.l10nKey),
                    selected: _selected.contains(category),
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
                _filterChip(
                  key: const Key('map-filter-challenge-only'),
                  label: strings.filterChallengeOnly,
                  selected: _challengeOnly,
                  onSelected: (on) => setState(() => _challengeOnly = on),
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
                  onPressed: () => Navigator.pop(
                    context,
                    MapFilterSelection(
                      categories: _selected,
                      challengeOnly: _challengeOnly,
                    ),
                  ),
                  child: Text(strings.applyFilters),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required Key key,
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      key: key,
      label: Text(label),
      selected: selected,
      selectedColor: MapPalette.forest,
      checkmarkColor: MapPalette.cream,
      labelStyle: TextStyle(
        color: selected ? MapPalette.cream : MapPalette.bark,
      ),
      backgroundColor: MapPalette.cream,
      side: BorderSide(color: selected ? MapPalette.forest : MapPalette.beige),
      onSelected: onSelected,
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
    required this.onVerify,
    this.compact = false,
  });

  final Place place;
  final AppStrings strings;
  final GeoPoint? userLocation;
  final VoidCallback onClose;
  final VoidCallback onVerify;
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
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PlaceMetaChip(label: strings.t(place.category.l10nKey)),
                if (place.elevationM != null)
                  PlaceMetaChip(
                    key: const Key('map-poi-sheet-elevation'),
                    label: strings.formatElevationM(place.elevationM!),
                  ),
                if (km != null)
                  PlaceMetaChip(label: strings.formatDistanceKm(km)),
              ],
            ),
            if (place.description != null) ...[
              const SizedBox(height: 8),
              PlaceDescriptionText(
                text: place.description!,
                textKey: const Key('map-poi-sheet-description'),
                toggleKey: const Key('map-poi-sheet-description-toggle'),
                maxLines: 4,
                moreLabel: strings.showMore,
                lessLabel: strings.showLess,
              ),
            ],
            SizedBox(height: compact ? 12 : 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('map-poi-verify'),
                    onPressed: onVerify,
                    style: FilledButton.styleFrom(
                      backgroundColor: MapPalette.forest,
                      foregroundColor: MapPalette.cream,
                      minimumSize: Size.fromHeight(buttonHeight),
                    ),
                    child: Text(strings.verify),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('map-poi-close'),
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: MapPalette.cream,
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
    this.emptyLabel,
  });

  final List<Place> places;
  final AppStrings strings;
  final GeoPoint? userLocation;
  final ValueChanged<Place> onSelect;
  final bool compact;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('map-poi-list'),
      color: MapPalette.creamFill,
      child: places.isEmpty
          ? Center(
              child: Text(
                emptyLabel ?? strings.monumentCount(0),
                textAlign: TextAlign.center,
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
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('map-poi-list-${place.id}'),
                    onTap: () => onSelect(place),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        compact ? 8 : 12,
                        12,
                        compact ? 8 : 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PlaceCategoryIcon(iconName: place.iconName),
                          const SizedBox(width: PlaceRowMetrics.titleGap),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: PlaceRowMetrics.titleNudge,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place.name,
                                    style: PlaceRowMetrics.titleStyle,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      PlaceMetaChip(
                                        label: strings.t(
                                          place.category.l10nKey,
                                        ),
                                      ),
                                      if (place.elevationM != null)
                                        PlaceMetaChip(
                                          key: Key(
                                            'map-poi-list-elevation-${place.id}',
                                          ),
                                          label: strings.formatElevationM(
                                            place.elevationM!,
                                          ),
                                        ),
                                      if (km != null)
                                        PlaceMetaChip(
                                          label: strings.formatDistanceKm(km),
                                        ),
                                    ],
                                  ),
                                  if (place.description != null) ...[
                                    const SizedBox(height: 4),
                                    PlaceDescriptionText(
                                      text: place.description!,
                                      textKey: Key(
                                        'map-poi-list-description-${place.id}',
                                      ),
                                      maxLines: 3,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(
                              top: PlaceRowMetrics.titleNudge,
                            ),
                            child: Icon(
                              Icons.chevron_right,
                              color: MapPalette.bark,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
