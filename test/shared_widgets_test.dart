import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/layout/breakpoints.dart';
import 'package:viateria/ui/widgets/app_network_image.dart';
import 'package:viateria/ui/widgets/error_state.dart';

void main() {
  test('window classes, rails, and content widths', () {
    expect(Breakpoints.ofWidth(390), WindowClass.compact);
    expect(Breakpoints.ofWidth(599), WindowClass.compact);
    expect(Breakpoints.ofWidth(600), WindowClass.medium);
    expect(Breakpoints.ofWidth(839), WindowClass.medium);
    expect(Breakpoints.ofWidth(840), WindowClass.expanded);
    expect(Breakpoints.ofWidth(1199), WindowClass.expanded);
    expect(Breakpoints.ofWidth(1280), WindowClass.large);
    expect(Breakpoints.usesNavigationRail(599), isFalse);
    expect(Breakpoints.usesNavigationRail(600), isFalse);
    expect(Breakpoints.usesNavigationRail(839), isFalse);
    expect(Breakpoints.usesNavigationRail(840), isTrue);
    expect(Breakpoints.challengeTwoColumn(839), isFalse);
    expect(Breakpoints.challengeTwoColumn(840), isTrue);
    expect(Breakpoints.catalogColumns(390), 1);
    expect(Breakpoints.catalogColumns(800), 2);
    expect(Breakpoints.catalogColumns(1024), 3);
    expect(Breakpoints.authMaxWidth, 440);
    expect(Breakpoints.catalogMaxWidth, 1200);
    expect(Breakpoints.profileMaxWidth, 640);
  });

  test('cache pixels and supabase render urls', () {
    expect(cachePixelsFor(100, 2), 200);
    expect(cachePixelsFor(0, 2), isNull);
    expect(cachePixelsFor(10, 0), isNull);
    expect(cachePixelsFor(double.nan, 2), isNull);
    const url =
        'https://abc.supabase.co/storage/v1/object/public/covers/a.jpg';
    final rendered = Uri.parse(supabaseRenderUrl(url, 400));
    expect(rendered.host, 'abc.supabase.co');
    expect(rendered.path, '/storage/v1/render/image/public/covers/a.jpg');
    expect(rendered.queryParameters['width'], '400');
    expect(rendered.queryParameters['quality'], '70');
    expect(rendered.queryParameters['resize'], isNull);
    expect(catalogCoverShouldCrop(4 / 3), isTrue);
    expect(catalogCoverShouldCrop(1.13), isTrue);
    expect(catalogCoverShouldCrop(1.53), isTrue);
    expect(catalogCoverShouldCrop(1.12), isFalse);
    expect(catalogCoverShouldCrop(0.86), isFalse);
    expect(
      supabaseRenderUrl('https://example.com/a.jpg', 400),
      'https://example.com/a.jpg',
    );
    expect(supabaseRenderUrl(url, null), url);
  });

  test('splash uses cream, a forest bar, and the existing lockup', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('#F3EFE5'));
    expect(html, contains('#35483C'));
    expect(html, contains('brand/vandery-lockup.png'));
    expect(html, contains('height: 2px'));
    expect(html, contains('prefers-reduced-motion'));
    expect(File('web/brand/vandery-lockup.png').existsSync(), isTrue);
    final asset = File('assets/brand/vandery-lockup.png').readAsBytesSync();
    final splash = File('web/brand/vandery-lockup.png').readAsBytesSync();
    expect(splash, asset);
  });

  testWidgets('ErrorState retry is a forest pill and text stays readable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ErrorState(
            title: 'Failed',
            hint: 'Offline',
            retryLabel: 'Retry',
            onRetry: () => taps++,
          ),
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('Failed'));
    expect(title.style?.color, BrandColors.error);
    expect(title.style?.fontSize, greaterThanOrEqualTo(14));
    final hint = tester.widget<Text>(find.text('Offline'));
    expect(hint.style?.color, BrandColors.forest);
    expect(hint.style?.fontSize, greaterThanOrEqualTo(14));
    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(icon.color, BrandColors.bark);
    await tester.tap(find.text('Retry'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
  });

  testWidgets('skeleton is beige and stays still when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(body: AppSkeleton(width: 80, height: 24)),
        ),
      ),
    );
    await tester.pump();
    final box = tester.widget<Container>(find.byType(Container));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, BrandColors.beige.withValues(alpha: 0.4));
  });

  testWidgets('blank network image shows the beige placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 80,
            child: AppNetworkImage(url: '  '),
          ),
        ),
      ),
    );
    expect(find.byType(AppImagePlaceholder), findsOneWidget);
    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(AppImagePlaceholder),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(box.color, BrandColors.beige);
  });

  testWidgets('primary filled button is a padded pill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('Go')),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FilledButton)).height, 48);
    final theme = FilledButtonTheme.of(
      tester.element(find.byType(FilledButton)),
    );
    expect(theme.style?.shape?.resolve(<WidgetState>{}), isA<StadiumBorder>());
  });

  testWidgets('content width wrapper caps and centers its child', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppContentWidth(
            maxWidth: 440,
            child: SizedBox(key: Key('inner'), height: 20),
          ),
        ),
      ),
    );
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppContentWidth(
            maxWidth: 440,
            child: SizedBox(key: Key('inner'), width: double.infinity, height: 20),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('inner'))).width, 440);
  });
}
