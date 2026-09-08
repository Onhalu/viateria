import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/app.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/unconfigured.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/l10n/sdk_fallback_localizations.dart';
import 'package:viateria/ui/screens/auth_screen.dart';

import 'helpers/fakes.dart';

Widget _appForLocale(String code) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: code)),
      Provider.value(
        value: AppServices(
          config: const AppConfig(
            supabaseUrl: 'https://example.supabase.co',
            supabaseAnonKey: 'anon',
            stripePublishableKey: 'pk_test',
          ),
          auth: MemoryAuth(),
          catalog: UnconfiguredCatalog(),
          progress: UnconfiguredProgress(),
          purchases: UnconfiguredPurchases(),
          photos: UnconfiguredPhotos(),
          photoCapture: UnconfiguredCapture(),
        ),
      ),
    ],
    child: const ViateriaApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final code in ['cs', 'en', 'de']) {
    testWidgets('MaterialLocalizations load for $code (TextField / Material)', (
      tester,
    ) async {
      await tester.pumpWidget(_appForLocale(code));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AuthScreen));
      expect(MaterialLocalizations.of(context), isNotNull);
      expect(find.byType(TextField), findsWidgets);
    });
  }

  testWidgets(
    'ViateriaApp locale cs does not throw unsupported-locale warning and TextField builds',
    (tester) async {
      await tester.pumpWidget(_appForLocale('cs'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsWidgets);

      final context = tester.element(find.byType(AuthScreen));
      expect(Localizations.localeOf(context), const Locale('cs'));
      expect(MaterialLocalizations.of(context), isNotNull);
      expect(CupertinoLocalizations.of(context), isNotNull);
      expect(find.text(AppStrings('cs').signIn), findsOneWidget);
    },
  );

  testWidgets(
    'MaterialApp locale cs with app delegates builds TextField without warning',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('cs'),
          supportedLocales: AppStringsLocales.supported,
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(body: TextField()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        MaterialLocalizations.of(
          tester.element(find.byType(TextField)),
        ),
        isNotNull,
      );
    },
  );

  test('cs fallback delegates claim cs and load English Global catalogs', () async {
    const material = FallbackMaterialLocalizationsDelegate();
    const cupertino = FallbackCupertinoLocalizationsDelegate();
    expect(material.isSupported(const Locale('cs')), isTrue);
    expect(material.isSupported(const Locale('en')), isFalse);
    expect(material.isSupported(const Locale('de')), isFalse);
    expect(cupertino.isSupported(const Locale('cs')), isTrue);
    expect(cupertino.isSupported(const Locale('en')), isFalse);
    expect(cupertino.isSupported(const Locale('de')), isFalse);

    final materialLoc = await material.load(const Locale('cs'));
    final cupertinoLoc = await cupertino.load(const Locale('cs'));
    expect(materialLoc, isA<MaterialLocalizations>());
    expect(cupertinoLoc, isA<CupertinoLocalizations>());
  });
}
