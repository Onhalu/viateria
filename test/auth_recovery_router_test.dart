import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/app.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/catalog_screen.dart';

import 'helpers/fakes.dart';

AppServices _services(MemoryAuth auth) {
  return AppServices(
    config: const AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon',
      stripePublishableKey: 'pk_test',
    ),
    auth: auth,
    catalog: MemoryCatalog(),
    progress: MemoryProgress(),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
  );
}

Widget _app(MemoryAuth auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: 'cs')),
      ChangeNotifierProvider(create: (_) => LastOpenedChallengeStore()),
      Provider.value(value: _services(auth)),
    ],
    child: const ViateriaApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('recovery session stays on auth until the password is saved', (
    tester,
  ) async {
    final auth = MemoryAuth(
      user: const Profile(id: 'user-1', email: 'ada@example.com', locale: 'cs'),
    );
    auth.beginPasswordRecovery();

    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-new-password')), findsOneWidget);
    expect(find.byType(CatalogScreen), findsNothing);

    await tester.enterText(
      find.byKey(const Key('auth-new-password')),
      'secret12',
    );
    await tester.enterText(
      find.byKey(const Key('auth-confirm-password')),
      'secret12',
    );
    await tester.tap(find.byKey(const Key('auth-save-password')));
    await tester.pumpAndSettle();

    expect(auth.pendingPasswordRecovery, isFalse);
    expect(auth.updatedPasswords, ['secret12']);
    expect(find.byKey(const Key('auth-new-password')), findsNothing);
    expect(find.byType(CatalogScreen), findsOneWidget);
  });
}
