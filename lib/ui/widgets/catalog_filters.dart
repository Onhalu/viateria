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

  static const iconSize = 20.0;
  static const iconConstraints = BoxConstraints(
    minWidth: 36,
    minHeight: 32,
    maxHeight: 36,
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('catalog-search-field'),
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: BrandColors.forest, fontSize: 14),
      cursorColor: BrandColors.forest,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: BrandColors.forest.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        filled: true,
        fillColor: BrandColors.creamFill,
        prefixIcon: const Icon(
          Icons.search,
          color: BrandColors.forest,
          size: iconSize,
        ),
        prefixIconConstraints: iconConstraints,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
    return SizedBox(
      height: CatalogFilterChip.height,
      child: SingleChildScrollView(
        key: const Key('catalog-filter-chips'),
        scrollDirection: Axis.horizontal,
        primary: false,
        child: Row(
          children: [
            CatalogFilterChip(
              key: const Key('catalog-filter-price-free'),
              selected: filter.pricingTypes.contains(PricingType.free),
              label: strings.free,
              onShell: true,
              onTap: () => onChanged(
                filter.copyWith(
                  pricingTypes: _toggle(filter.pricingTypes, PricingType.free),
                ),
              ),
            ),
            const SizedBox(width: CatalogFilterChip.gap),
            CatalogFilterChip(
              key: const Key('catalog-filter-price-paid'),
              selected: filter.pricingTypes.contains(PricingType.paid),
              label: strings.paid,
              onShell: true,
              onTap: () => onChanged(
                filter.copyWith(
                  pricingTypes: _toggle(filter.pricingTypes, PricingType.paid),
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
            const SizedBox(width: CatalogFilterChip.gap),
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
              if (i > 0) const SizedBox(width: CatalogFilterChip.gap),
              CatalogFilterChip(
                key: Key('catalog-filter-region-${catalogCountryCodes[i]}'),
                selected: filter.countryCodes.contains(catalogCountryCodes[i]),
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
            const _ChipGroupGap(),
            Row(
              key: const Key('catalog-length-difficulty-chips'),
              mainAxisSize: MainAxisSize.min,
              children: [
                CatalogLengthChipRow(
                  filter: filter,
                  strings: strings,
                  onChanged: onChanged,
                ),
                const _ChipGroupGap(),
                CatalogDifficultyChipRow(
                  filter: filter,
                  strings: strings,
                  onChanged: onChanged,
                ),
              ],
            ),
            if (filter.isActive) ...[
              const SizedBox(width: 12),
              Center(
                child: TextButton(
                  key: const Key('catalog-clear-filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.cream,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, CatalogFilterChip.height),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    onChanged(filter.cleared());
                  },
                  child: Text(
                    strings.catalogClearFilters,
                    style: const TextStyle(
                      color: BrandColors.cream,
                      fontSize: CatalogFilterChip.fontSize,
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
    return Row(
      key: const Key('catalog-length-chips'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < CatalogLengthBand.values.length; i++) ...[
          if (i > 0) const SizedBox(width: CatalogFilterChip.gap),
          CatalogFilterChip(
            key: Key(
              'catalog-filter-length-${CatalogLengthBand.values[i].name}',
            ),
            selected: filter.lengthBands.contains(CatalogLengthBand.values[i]),
            label: _lengthLabel(strings, CatalogLengthBand.values[i]),
            onShell: true,
            onTap: () => onChanged(
              filter.copyWith(
                lengthBands: _toggle(
                  filter.lengthBands,
                  CatalogLengthBand.values[i],
                ),
              ),
            ),
          ),
        ],
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
    return Row(
      key: const Key('catalog-difficulty-chips'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < CatalogDifficulty.values.length; i++) ...[
          if (i > 0) const SizedBox(width: CatalogFilterChip.gap),
          CatalogFilterChip(
            key: Key(
              'catalog-filter-difficulty-${CatalogDifficulty.values[i].name}',
            ),
            selected: filter.difficulties.contains(CatalogDifficulty.values[i]),
            label: _difficultyLabel(strings, CatalogDifficulty.values[i]),
            onShell: true,
            onTap: () => onChanged(
              filter.copyWith(
                difficulties: _toggle(
                  filter.difficulties,
                  CatalogDifficulty.values[i],
                ),
              ),
            ),
          ),
        ],
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
          height: CatalogFilterChip.height,
          child: ListView(
            scrollDirection: Axis.horizontal,
            primary: false,
            children: [
              for (var i = 0; i < catalogCountryCodes.length; i++) ...[
                if (i > 0) const SizedBox(width: CatalogFilterChip.gap),
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

  static const height = 28.0;
  static const gap = 6.0;
  static const horizontalPadding = 8.0;
  static const fontSize = 12.0;
  static const radius = 14.0;

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
          borderRadius: BorderRadius.circular(radius),
          side: onShell
              ? BorderSide.none
              : BorderSide(color: border, width: selected ? 2.0 : 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Center(
                child: isFlag
                    ? ExcludeSemantics(child: CountryFlag(code: flagCode!))
                    : Text(
                        label!,
                        style: TextStyle(
                          fontSize: fontSize,
                          height: 1.1,
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
      width: 16,
      height: CatalogFilterChip.height,
      child: Center(
        child: SizedBox(
          width: 1,
          height: 12,
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
