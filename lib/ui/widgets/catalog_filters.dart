import 'package:flutter/material.dart';

import '../../domain/catalog_query.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';
import 'country_flag.dart';

class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('catalog-search-field'),
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: BrandColors.forest),
      cursorColor: BrandColors.forest,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: BrandColors.forest.withValues(alpha: 0.7)),
        filled: true,
        fillColor: BrandColors.creamFill,
        prefixIcon: const Icon(Icons.search, color: BrandColors.forest),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.forest, width: 1.5),
        ),
      ),
    );
  }
}

class CatalogFilterChipRow extends StatelessWidget {
  const CatalogFilterChipRow({
    super.key,
    required this.filter,
    required this.strings,
    required this.onChanged,
  });

  final CatalogFilter filter;
  final AppStrings strings;
  final ValueChanged<CatalogFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            key: const Key('catalog-filter-chips'),
            scrollDirection: Axis.horizontal,
            children: [
              CatalogFilterChip(
                key: const Key('catalog-filter-price-free'),
                selected: filter.pricingTypes.contains(PricingType.free),
                label: strings.free,
                onShell: true,
                onTap: () => onChanged(
                  filter.copyWith(
                    pricingTypes: _toggle(
                      filter.pricingTypes,
                      PricingType.free,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CatalogFilterChip(
                key: const Key('catalog-filter-price-paid'),
                selected: filter.pricingTypes.contains(PricingType.paid),
                label: strings.paid,
                onShell: true,
                onTap: () => onChanged(
                  filter.copyWith(
                    pricingTypes: _toggle(
                      filter.pricingTypes,
                      PricingType.paid,
                    ),
                  ),
                ),
              ),
              const _ChipGroupGap(),
              CatalogFilterChip(
                key: const Key('catalog-filter-mode-open'),
                selected: filter.accessModes.contains(AccessMode.open),
                label: strings.catalogFilterOpen,
                onShell: true,
                onTap: () => onChanged(
                  filter.copyWith(
                    accessModes: _toggle(filter.accessModes, AccessMode.open),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CatalogFilterChip(
                key: const Key('catalog-filter-mode-story'),
                selected: filter.accessModes.contains(AccessMode.story),
                label: strings.catalogFilterStory,
                onShell: true,
                onTap: () => onChanged(
                  filter.copyWith(
                    accessModes: _toggle(filter.accessModes, AccessMode.story),
                  ),
                ),
              ),
              const _ChipGroupGap(),
              for (var i = 0; i < catalogCountryCodes.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                CatalogFilterChip(
                  key: Key('catalog-filter-region-${catalogCountryCodes[i]}'),
                  selected: filter.countryCodes.contains(
                    catalogCountryCodes[i],
                  ),
                  semanticLabel: catalogCountryCodes[i],
                  flagCode: catalogCountryCodes[i],
                  onShell: true,
                  onTap: () => onChanged(
                    filter.copyWith(
                      countryCodes: _toggle(
                        filter.countryCodes,
                        catalogCountryCodes[i],
                      ),
                    ),
                  ),
                ),
              ],
              if (filter.isActive) ...[
                const SizedBox(width: 12),
                Center(
                  child: TextButton(
                    key: const Key('catalog-clear-filters'),
                    style: TextButton.styleFrom(
                      foregroundColor: BrandColors.cream,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      onChanged(filter.cleared());
                    },
                    child: Text(
                      strings.catalogClearFilters,
                      style: const TextStyle(
                        color: BrandColors.cream,
                        decoration: TextDecoration.underline,
                        decorationColor: BrandColors.cream,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Column(
          key: const Key('catalog-length-difficulty-chips'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CatalogLengthChipRow(
              filter: filter,
              strings: strings,
              onChanged: onChanged,
            ),
            const SizedBox(height: 8),
            CatalogDifficultyChipRow(
              filter: filter,
              strings: strings,
              onChanged: onChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class CatalogLengthChipRow extends StatelessWidget {
  const CatalogLengthChipRow({
    super.key,
    required this.filter,
    required this.strings,
    required this.onChanged,
  });

  final CatalogFilter filter;
  final AppStrings strings;
  final ValueChanged<CatalogFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('catalog-length-chips'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final band in CatalogLengthBand.values)
          CatalogFilterChip(
            key: Key('catalog-filter-length-${band.name}'),
            selected: filter.lengthBands.contains(band),
            label: _lengthLabel(strings, band),
            onShell: true,
            onTap: () => onChanged(
              filter.copyWith(lengthBands: _toggle(filter.lengthBands, band)),
            ),
          ),
      ],
    );
  }
}

class CatalogDifficultyChipRow extends StatelessWidget {
  const CatalogDifficultyChipRow({
    super.key,
    required this.filter,
    required this.strings,
    required this.onChanged,
  });

  final CatalogFilter filter;
  final AppStrings strings;
  final ValueChanged<CatalogFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('catalog-difficulty-chips'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final difficulty in CatalogDifficulty.values)
          CatalogFilterChip(
            key: Key('catalog-filter-difficulty-${difficulty.name}'),
            selected: filter.difficulties.contains(difficulty),
            label: _difficultyLabel(strings, difficulty),
            onShell: true,
            onTap: () => onChanged(
              filter.copyWith(
                difficulties: _toggle(filter.difficulties, difficulty),
              ),
            ),
          ),
      ],
    );
  }
}

class CatalogRegionsSection extends StatelessWidget {
  const CatalogRegionsSection({
    super.key,
    required this.filter,
    required this.strings,
    required this.onChanged,
  });

  final CatalogFilter filter;
  final AppStrings strings;
  final ValueChanged<CatalogFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('catalog-regions'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.catalogRegions,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: BrandColors.forest,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            primary: false,
            children: [
              for (var i = 0; i < catalogCountryCodes.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                CatalogFilterChip(
                  key: Key('catalog-regions-${catalogCountryCodes[i]}'),
                  selected: filter.countryCodes.contains(
                    catalogCountryCodes[i],
                  ),
                  semanticLabel: catalogCountryCodes[i],
                  flagCode: catalogCountryCodes[i],
                  onTap: () => onChanged(
                    filter.copyWith(
                      countryCodes: _toggle(
                        filter.countryCodes,
                        catalogCountryCodes[i],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _lengthLabel(AppStrings strings, CatalogLengthBand band) {
  return switch (band) {
    CatalogLengthBand.short => strings.catalogLengthShort,
    CatalogLengthBand.medium => strings.catalogLengthMedium,
    CatalogLengthBand.long => strings.catalogLengthLong,
  };
}

String _difficultyLabel(AppStrings strings, CatalogDifficulty difficulty) {
  return switch (difficulty) {
    CatalogDifficulty.easy => strings.catalogDifficultyEasy,
    CatalogDifficulty.normal => strings.catalogDifficultyNormal,
    CatalogDifficulty.hard => strings.catalogDifficultyHard,
  };
}

class CatalogFilterChip extends StatelessWidget {
  const CatalogFilterChip({
    super.key,
    required this.selected,
    required this.onTap,
    this.label,
    this.flagCode,
    this.semanticLabel,
    this.onShell = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final String? flagCode;
  final String? semanticLabel;

  /// When true, chips sit on [BrandColors.shellFill]: cream @ 22% unselected,
  /// solid cream selected, no border.
  final bool onShell;

  @override
  Widget build(BuildContext context) {
    final isFlag = flagCode != null;
    final fill = onShell
        ? (selected ? BrandColors.cream : BrandColors.creamPill)
        : (selected && !isFlag ? BrandColors.forest : BrandColors.cream);
    final border = selected ? BrandColors.forest : BrandColors.beige;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: onShell
              ? BorderSide.none
              : BorderSide(color: border, width: selected ? 2.0 : 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: isFlag
                    ? ExcludeSemantics(child: CountryFlag(code: flagCode!))
                    : Text(
                        label!,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: onShell
                                  ? (selected
                                        ? BrandColors.forest
                                        : BrandColors.cream)
                                  : (selected
                                        ? BrandColors.onPrimary
                                        : BrandColors.bark),
                            ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipGroupGap extends StatelessWidget {
  const _ChipGroupGap();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 21,
      height: 36,
      child: Center(
        child: SizedBox(
          width: 1,
          height: 16,
          child: ColoredBox(color: BrandColors.cream.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}

Set<T> _toggle<T>(Set<T> current, T value) {
  final next = {...current};
  if (!next.add(value)) {
    next.remove(value);
  }
  return next;
}
