import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/repositories.dart';
import 'package:viateria/data/unconfigured.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/ui/screens/auth_screen.dart';

import 'helpers/fakes.dart';

Widget wrapAuth({
  MemoryAuth? auth,
  String locale = 'cs',
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: locale)),
      Provider.value(
        value: AppServices(
          config: const AppConfig(
            supabaseUrl: 'https://example.supabase.co',
            supabaseAnonKey: 'anon',
            stripePublishableKey: 'pk_test',
          ),
          auth: auth ?? MemoryAuth(),
          catalog: UnconfiguredCatalog(),
          progress: UnconfiguredProgress(),
          purchases: UnconfiguredPurchases(),
          photos: UnconfiguredPhotos(),
          photoCapture: UnconfiguredCapture(),
        ),
      ),
    ],
    child: const MaterialApp(home: AuthScreen()),
  );
}

void main() {
  testWidgets('register action shows name, email and password form', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(wrapAuth());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-display-name')), findsNothing);
    expect(find.text(strings.registerTitle), findsNothing);
    expect(find.text(strings.registerAction), findsOneWidget);
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-open-register')));
    await tester.pumpAndSettle();

    expect(find.text(strings.registerTitle), findsOneWidget);
    expect(find.byKey(const Key('auth-display-name')), findsOneWidget);
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsOneWidget);
    expect(find.text(strings.displayName), findsOneWidget);
    expect(find.text(strings.email), findsOneWidget);
    expect(find.text(strings.password), findsOneWidget);
    expect(find.text(strings.signUp), findsOneWidget);
    expect(find.text(strings.backToSignIn), findsOneWidget);
  });

  testWidgets('sign-up without session shows email confirmation, not generic error', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(wrapAuth(auth: MemoryAuth(sessionOnSignUp: false)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auth-open-register')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('auth-display-name')), 'Ada');
    await tester.enterText(find.byKey(const Key('auth-email')), 'ada@example.com');
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret12');
    await tester.tap(find.byKey(const Key('auth-submit-register')));
    await tester.pumpAndSettle();

    expect(find.text(strings.errorGeneric), findsNothing);
    expect(find.text(strings.confirmEmailTitle), findsOneWidget);
    expect(find.text(strings.confirmEmailBody), findsOneWidget);
    expect(find.byKey(const Key('auth-otp')), findsOneWidget);
    expect(find.text(strings.verifyOtp), findsOneWidget);
    expect(find.text(strings.enterAfterConfirm), findsOneWidget);
  });

  testWidgets('back to sign-in returns to the default screen', (tester) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(wrapAuth(locale: 'en'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auth-open-register')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-back-sign-in')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-display-name')), findsNothing);
    expect(find.text(strings.signIn), findsOneWidget);
    expect(find.text(strings.registerAction), findsOneWidget);
  });

  testWidgets('sign-in offers email, magic link, Google, and Apple', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    final auth = MemoryAuth();
    await tester.pumpWidget(wrapAuth(auth: auth));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-google')), findsOneWidget);
    expect(find.byKey(const Key('auth-apple')), findsOneWidget);
    expect(find.byIcon(Icons.apple), findsOneWidget);
    expect(find.text(strings.continueWithGoogle), findsOneWidget);
    expect(find.text(strings.continueWithApple), findsOneWidget);
    expect(find.text(strings.sendMagicLink), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-google')));
    await tester.pumpAndSettle();
    expect(auth.providers, [AuthProvider.google]);
    expect(find.byKey(const Key('auth-error')), findsNothing);

    await tester.tap(find.byKey(const Key('auth-apple')));
    await tester.pumpAndSettle();
    expect(auth.providers, [AuthProvider.google, AuthProvider.apple]);
  });

  testWidgets('register offers Google and Apple on the same session API', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(wrapAuth());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-open-register')));
    await tester.pumpAndSettle();

    expect(find.text(strings.continueWithGoogle), findsOneWidget);
    expect(find.text(strings.continueWithApple), findsOneWidget);
    expect(find.byIcon(Icons.apple), findsOneWidget);
  });

  testWidgets('disabled Google provider shows a clear Czech error', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(
      wrapAuth(auth: MemoryAuth(unavailableProviders: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auth-google')));
    await tester.pumpAndSettle();

    expect(
      find.text(strings.authProviderUnavailable('Google')),
      findsOneWidget,
    );
    expect(find.text(strings.errorGeneric), findsNothing);
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
  });

  testWidgets('magic link asks the user to check email', (tester) async {
    final strings = AppStrings('cs');
    final auth = MemoryAuth();
    await tester.pumpWidget(wrapAuth(auth: auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('auth-email')), 'ada@example.com');
    await tester.tap(find.byKey(const Key('auth-magic-link')));
    await tester.pumpAndSettle();

    expect(auth.magicLinks, ['ada@example.com']);
    expect(find.text(strings.magicLinkSentTitle), findsOneWidget);
    expect(find.text(strings.magicLinkSentBody), findsOneWidget);
    expect(find.byKey(const Key('auth-otp')), findsOneWidget);
    expect(find.text(strings.errorGeneric), findsNothing);
  });

  testWidgets('oauth callback failure is shown without a crash', (tester) async {
    final strings = AppStrings('cs');
    final auth = MemoryAuth();
    await tester.pumpWidget(wrapAuth(auth: auth));
    await tester.pumpAndSettle();

    auth.emitFailure(const AuthProviderUnavailable());
    await tester.pump();

    expect(find.text(strings.authProviderUnavailableGeneric), findsOneWidget);
  });
}
