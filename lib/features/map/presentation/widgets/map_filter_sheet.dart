import 'package:flutter/material.dart';

import '../../../../core/l10n/map_strings.dart';
import '../../../../core/theme/map_colors.dart';
import '../../domain/poi_category.dart';

Future<Set<PoiCategory>?> showMapFilterSheet({
  required BuildContext context,
  required MapStrings strings,
  required Set<PoiCategory> selected,
}) {
  return showModalBottomSheet<Set<PoiCategory>>(
    context: context,
    backgroundColor: MapColors.surface.withValues(alpha: 0.96),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _FilterBody(strings: strings, initial: selected),
  );
}

class _FilterBody extends StatefulWidget {
  const _FilterBody({required this.strings, required this.initial});

  final MapStrings strings;
  final Set<PoiCategory> initial;

  @override
  State<_FilterBody> createState() => _FilterBodyState();
}

class _FilterBodyState extends State<_FilterBody> {
  late Set<PoiCategory> _selected = Set<PoiCategory>.from(widget.initial);

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
                for (final category in PoiCategory.values)
                  FilterChip(
                    key: Key('map-filter-${category.name}'),
                    label: Text(strings.categoryLabel(category.l10nKey)),
                    selected: _selected.contains(category),
                    selectedColor: MapColors.accent,
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
                      () => _selected = Set<PoiCategory>.from(
                        PoiCategory.values,
                      ),
                    );
                  },
                  child: Text(strings.selectAll),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('map-filter-apply'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MapColors.accent,
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
