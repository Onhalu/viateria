import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';

/// Debug/profile-only Flutter Material 3 reference shell.
///
/// Mirrors `flutter create` / the Material template (seeded [ColorScheme],
/// [AppBar], [FloatingActionButton], [NavigationBar] / [NavigationRail],
/// cards and a list). It does **not** replace AppTheme or production
/// [BrandColors]. Hidden in release builds.
class DemoMaterialScreen extends StatefulWidget {
  const DemoMaterialScreen({super.key});

  static const routePath = '/demo/material';
  static const compactBreakpoint = 600.0;

  /// Reachable in debug and profile; stripped from release.
  static bool get isEnabled => !kReleaseMode;

  @override
  State<DemoMaterialScreen> createState() => _DemoMaterialScreenState();
}

class _DemoMaterialScreenState extends State<DemoMaterialScreen> {
  int _destinationIndex = 0;
  int _counter = 0;

  static final ColorScheme _demoScheme = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
  );

  static final ColorScheme _forestSeedScheme = ColorScheme.fromSeed(
    seedColor: BrandColors.forest,
  );

  void _incrementCounter() {
    setState(() => _counter++);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        colorScheme: _demoScheme,
        useMaterial3: true,
      ),
      child: Builder(
        builder: (context) {
          final wide =
              MediaQuery.sizeOf(context).width >=
              DemoMaterialScreen.compactBreakpoint;
          return Scaffold(
            key: const Key('demo-material-screen'),
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              title: const Text('Flutter Material Demo'),
            ),
            body: Row(
              children: [
                if (wide)
                  NavigationRail(
                    key: const Key('demo-material-nav-rail'),
                    selectedIndex: _destinationIndex,
                    onDestinationSelected: (index) {
                      setState(() => _destinationIndex = index);
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.view_list_outlined),
                        selectedIcon: Icon(Icons.view_list),
                        label: Text('List'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.palette_outlined),
                        selectedIcon: Icon(Icons.palette),
                        label: Text('Colors'),
                      ),
                    ],
                  ),
                if (wide) const VerticalDivider(width: 1),
                Expanded(child: _pageForIndex(_destinationIndex)),
              ],
            ),
            floatingActionButton: _destinationIndex == 0
                ? FloatingActionButton(
                    key: const Key('demo-material-fab'),
                    onPressed: _incrementCounter,
                    tooltip: 'Increment',
                    child: const Icon(Icons.add),
                  )
                : null,
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    key: const Key('demo-material-nav-bar'),
                    selectedIndex: _destinationIndex,
                    onDestinationSelected: (index) {
                      setState(() => _destinationIndex = index);
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.view_list_outlined),
                        selectedIcon: Icon(Icons.view_list),
                        label: 'List',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.palette_outlined),
                        selectedIcon: Icon(Icons.palette),
                        label: 'Colors',
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _pageForIndex(int index) {
    switch (index) {
      case 1:
        return const _DemoListPage();
      case 2:
        return _DemoColorsPage(
          demoScheme: _demoScheme,
          forestSeedScheme: _forestSeedScheme,
        );
      default:
        return _DemoHomePage(counter: _counter);
    }
  }
}

class _DemoHomePage extends StatelessWidget {
  const _DemoHomePage({required this.counter});

  final int counter;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _DemoBanner(),
        const SizedBox(height: 32),
        const Text(
          'You have pushed the button this many times:',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '$counter',
          key: const Key('demo-material-counter'),
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        Text(
          'This is the flutter create counter shell, nested under a '
          'Material 3 NavigationBar / NavigationRail. Production Viateria '
          'still boots to Catalog.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _DemoListPage extends StatelessWidget {
  const _DemoListPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _DemoBanner(),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.explore),
            title: const Text('Catalog stays the home tab'),
            subtitle: const Text('This demo is a sibling route, not a replacement.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Maps, FAPI, auth unchanged'),
            subtitle: const Text('Open /demo/material only from Profile in debug/profile.'),
            onTap: () {},
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sample card', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'Filled, outlined, and tonal buttons from the Material 3 template.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(onPressed: () {}, child: const Text('Filled')),
                    FilledButton.tonal(
                      onPressed: () {},
                      child: const Text('Tonal'),
                    ),
                    OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
                    TextButton(onPressed: () {}, child: const Text('Text')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoColorsPage extends StatelessWidget {
  const _DemoColorsPage({
    required this.demoScheme,
    required this.forestSeedScheme,
  });

  final ColorScheme demoScheme;
  final ColorScheme forestSeedScheme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _DemoBanner(),
        const SizedBox(height: 8),
        Text(
          'ColorScheme.fromSeed (flutter create default)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Swatch(label: 'primary', color: demoScheme.primary),
            _Swatch(label: 'secondary', color: demoScheme.secondary),
            _Swatch(label: 'tertiary', color: demoScheme.tertiary),
            _Swatch(label: 'surface', color: demoScheme.surface),
            _Swatch(label: 'inversePrimary', color: demoScheme.inversePrimary),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Optional forest seed (demo only)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'ColorScheme.fromSeed(BrandColors.forest) for comparison. '
          'Cream / forest production tokens live in BrandColors / AppTheme '
          'and are not replaced by this screen.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Swatch(label: 'seeded primary', color: forestSeedScheme.primary),
            _Swatch(label: 'seeded surface', color: forestSeedScheme.surface),
            _Swatch(label: 'BrandColors.forest', color: BrandColors.forest),
            _Swatch(label: 'BrandColors.cream', color: BrandColors.cream),
          ],
        ),
      ],
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('demo-material-banner'),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_outlined, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'DEMO tokens — ColorScheme.fromSeed for inspection only. '
                'Does not replace BrandColors / AppTheme. Do not merge this '
                'branch without an explicit ask.',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor = color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: Text(
            '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
            style: TextStyle(color: onColor, fontSize: 10),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 88,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}
