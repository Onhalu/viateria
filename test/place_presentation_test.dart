import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_category.dart';
import 'package:viateria/ui/widgets/place_presentation.dart';
import 'package:viateria/ui/widgets/places_map_panels.dart';

void main() {
  testWidgets('long place description expands and collapses', (tester) async {
    final strings = AppStrings('cs');
    const place = Place(
      id: 'long',
      name: 'Dlouhý text',
      category: PlaceCategory.historical,
      location: GeoPoint(49.1, 14.2),
      description:
          'Tato památka stojí nad údolím a její příběh se vine několika stoletími. '
          'Návštěvníci sem chodí pro výhled, klid a vrstvy historie, které se '
          'na místě střídají od středověku až po dnešní vyhlídkovou cestu. '
          'Cesta pokračuje kolem skal, lesních průseků a starých mezníků, '
          'které ukazují, kudy chodili lidé dávno před vyznačenou stezkou. '
          'Na konci je tiché místo s výhledem, kde se dá zastavit a číst dál.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailSheet(
            place: place,
            strings: strings,
            userLocation: null,
            onClose: () {},
            onVerify: () {},
          ),
        ),
      ),
    );

    final collapsed = tester.widget<Text>(
      find.byKey(const Key('map-poi-sheet-description')),
    );
    expect(collapsed.maxLines, 4);
    expect(collapsed.overflow, TextOverflow.ellipsis);
    expect(find.text(strings.showMore), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-poi-sheet-description-toggle')));
    await tester.pumpAndSettle();

    final expanded = tester.widget<Text>(
      find.byKey(const Key('map-poi-sheet-description')),
    );
    expect(expanded.maxLines, isNull);
    expect(find.text(strings.showLess), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-poi-sheet-description-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('map-poi-sheet-description')))
          .maxLines,
      4,
    );
  });

  testWidgets('blank description stays hidden', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PlaceDescriptionText(text: '   ')),
      ),
    );
    expect(find.byType(Text), findsNothing);
  });
}
