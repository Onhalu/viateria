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

  /// Gap between the access/difficulty row and the country flags.
  static const rowGap = 8.0;

  /// Two chip rows plus [rowGap]. Used by welcome-panel height tests.
  static const areaHeight = CatalogFilterChip.height * 2 + rowGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('catalog-filter-chips'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EqualOrScrollChips(
          filter: filter,
          strings: strings,
          onChanged: onChanged,
        ),
        const SizedBox(height: rowGap),
        _FilterScrollRow(
          rowKey: const Key('catalog-filter-country-chips'),
          children: [
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
          ],
        ),
      ],
    );
  }
}

/// Country flags under the promo. Same [CatalogFilter.countryCodes] as the
/// header chips, so either row selects the country for the challenge list.
class CatalogRegionsSection extends StatelessWidget {
  const CatalogRegionsSection({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final CatalogFilter filter;
  final ValueChanged<CatalogFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('catalog-regions'),
      height: CatalogFilterChip.height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        primary: false,
        children: [
          for (var i = 0; i < catalogCountryCodes.length; i++) ...[
            if (i > 0) const SizedBox(width: CatalogFilterChip.gap),
            CatalogFilterChip(
              key: Key('catalog-regions-${catalogCountryCodes[i]}'),
              selected: filter.countryCodes.contains(catalogCountryCodes[i]),
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

class _FilterScrollRow extends StatelessWidget {
  const _FilterScrollRow({required this.rowKey, required this.children});

  final Key rowKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CatalogFilterChip.height,
      child: SingleChildScrollView(
        key: rowKey,
        scrollDirection: Axis.horizontal,
        primary: false,
        child: Row(children: children),
      ),
    );
  }
}

class _EqualOrScrollChips extends StatelessWidget {
  const _EqualOrScrollChips({
    required this.filter,
    required this.strings,
    required this.onChanged,
  });

  final CatalogFilter filter;
  final AppStrings strings;
  final ValueChanged<CatalogFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = CatalogFilterChip.gap;
        const groupGap = 16.0;
        final clearSlot = filter.isActive ? 60.0 : 0.0;
        final width = constraints.maxWidth;
        final available = width - groupGap - clearSlot - gap * 3;
        final each = available / 5;
        final scroll = each < CatalogFilterChip.minOptionWidth;
        final access = _accessChips(expand: !scroll);
        final difficulty = CatalogDifficultyChipRow(
          filter: filter,
          strings: strings,
          onChanged: onChanged,
          expand: !scroll,
        );
        final clear = filter.isActive ? _clearButton() : null;
        if (scroll) {
          return SizedBox(
            key: const Key('catalog-filter-access-chips'),
            height: CatalogFilterChip.height,
            child: ListView(
              scrollDirection: Axis.horizontal,
              primary: false,
              children: [
                ...access,
                const _ChipGroupGap(),
                difficulty,
                if (clear != null) ...[const SizedBox(width: 12), clear],
              ],
            ),
          );
        }
        return SizedBox(
          key: const Key('catalog-filter-access-chips'),
          height: CatalogFilterChip.height,
          child: Row(
            children: [
              Expanded(flex: 2, child: Row(children: access)),
              const _ChipGroupGap(),
              Expanded(flex: 3, child: difficulty),
              if (clear != null) ...[const SizedBox(width: 12), clear],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _accessChips({required bool expand}) {
    Widget chip({
      required Key key,
      required bool selected,
      required String label,
      required VoidCallback onTap,
    }) {
      return CatalogFilterChip(
        key: key,
        selected: selected,
        label: label,
        onShell: true,
        expand: expand,
        onTap: onTap,
      );
    }

    final story = chip(
      key: const Key('catalog-filter-mode-story'),
      selected: filter.accessModes.contains(AccessMode.story),
      label: strings.catalogFilterStory,
      onTap: () => onChanged(
        filter.copyWith(
          accessModes: _toggle(filter.accessModes, AccessMode.story),
        ),
      ),
    );
    final open = chip(
      key: const Key('catalog-filter-mode-open'),
      selected: filter.accessModes.contains(AccessMode.open),
      label: strings.catalogFilterOpen,
      onTap: () => onChanged(
        filter.copyWith(
          accessModes: _toggle(filter.accessModes, AccessMode.open),
        ),
      ),
    );
    if (expand) {
      return [
        Expanded(child: story),
        const SizedBox(width: CatalogFilterChip.gap),
        Expanded(child: open),
      ];
    }
    return [story, const SizedBox(width: CatalogFilterChip.gap), open];
  }

  Widget _clearButton() {
    return TextButton(
      key: const Key('catalog-clear-filters'),
      style: TextButton.styleFrom(
        foregroundColor: BrandColors.cream,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(48, CatalogFilterChip.height),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => onChanged(filter.cleared()),
      child: Text(
        strings.catalogClearFilters,
        style: const TextStyle(
          color: BrandColors.cream,
          fontSize: CatalogFilterChip.fontSize,
          decoration: TextDecoration.underline,
          decorationColor: BrandColors.cream,
        ),
      ),
    );
  }
}

class CatalogDifficultyChipRow extends StatelessWidget {
  const CatalogDifficultyChipRow({
    super.key,
    required this.filter,
    required this.strings,
    required this.onChanged,
    this.expand = false,
  });

  final CatalogFilter filter;
  final AppStrings strings;
  final ValueChanged<CatalogFilter> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      for (var i = 0; i < CatalogDifficulty.values.length; i++) ...[
        if (i > 0) const SizedBox(width: CatalogFilterChip.gap),
        if (expand)
          Expanded(
            child: CatalogFilterChip(
              key: Key(
                'catalog-filter-difficulty-${CatalogDifficulty.values[i].name}',
              ),
              selected: filter.difficulties.contains(
                CatalogDifficulty.values[i],
              ),
              label: _difficultyLabel(strings, CatalogDifficulty.values[i]),
              onShell: true,
              expand: true,
              onTap: () => onChanged(
                filter.copyWith(
                  difficulties: _toggle(
                    filter.difficulties,
                    CatalogDifficulty.values[i],
                  ),
                ),
              ),
            ),
          )
        else
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
    ];
    return Row(
      key: const Key('catalog-difficulty-chips'),
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: chips,
    );
  }
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
    this.expand = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final String? flagCode;
  final String? semanticLabel;
  final bool expand;

  /// When true, chips sit on [BrandColors.shellFill]: cream @ 22% unselected,
  /// solid cream selected, no border.
  final bool onShell;

  static const height = 40.0;
  static const gap = 8.0;
  static const horizontalPadding = 8.0;
  static const fontSize = 14.0;
  static const radius = 20.0;
  static const minOptionWidth = 72.0;

  @override
  Widget build(BuildContext context) {
    final isFlag = flagCode != null;
    final fill = isFlag
        ? BrandColors.cream
        : (selected ? BrandColors.forest : BrandColors.cream);
    final side = isFlag
        ? BorderSide(
            color: selected ? BrandColors.forest : BrandColors.beige,
            width: selected ? 1.5 : 1,
          )
        : (selected
              ? BorderSide.none
              : const BorderSide(color: BrandColors.beige));
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: expand ? double.infinity : null,
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isFlag ? horizontalPadding : 4,
              ),
              child: Center(
                child: isFlag
                    ? ExcludeSemantics(child: CountryFlag(code: flagCode!))
                    : Text(
                        label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? BrandColors.onPrimary
                              : (onShell
                                    ? BrandColors.forest
                                    : BrandColors.forest),
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

Set<T> _toggle<T>(Set<T> current, T value) {
  final next = {...current};
  if (!next.add(value)) {
    next.remove(value);
  }
  return next;
}
