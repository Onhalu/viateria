import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/app.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/unconfigured.dart';
import 'package:viateria/l10n/locale_controller.dart';
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
}
