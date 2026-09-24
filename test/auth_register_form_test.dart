import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/repositories.dart';
import 'package:viateria/data/unconfigured.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/theme/brand_assets.dart';
import 'package:viateria/ui/screens/auth_screen.dart';

import 'helpers/fakes.dart';

Widget wrapAuth({MemoryAuth? auth, String locale = 'cs'}) {
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
    child: MaterialApp(theme: AppTheme.light(), home: const AuthScreen()),
  );
}

Future<void> pumpAuth(
  WidgetTester tester, {
  MemoryAuth? auth,
  String locale = 'cs',
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(wrapAuth(auth: auth, locale: locale));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('register action shows name, email and password form', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    await pumpAuth(tester);

    expect(find.byKey(const Key('auth-display-name')), findsNothing);
    expect(find.text(strings.registerTitle), findsNothing);
    expect(find.text(strings.registerAction), findsOneWidget);
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('auth-open-register')));
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

  testWidgets(
    'sign-up without session shows email confirmation, not generic error',
    (tester) async {
      final strings = AppStrings('cs');
      await pumpAuth(tester, auth: MemoryAuth(sessionOnSignUp: false));

      await tester.ensureVisible(find.byKey(const Key('auth-open-register')));
      await tester.tap(find.byKey(const Key('auth-open-register')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('auth-display-name')), 'Ada');
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'ada@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'secret12',
      );
      await tester.ensureVisible(find.byKey(const Key('auth-submit-register')));
      await tester.tap(find.byKey(const Key('auth-submit-register')));
      await tester.pumpAndSettle();

      expect(find.text(strings.errorGeneric), findsNothing);
      expect(find.text(strings.confirmEmailTitle), findsOneWidget);
      expect(find.text(strings.confirmEmailBody), findsOneWidget);
      expect(find.byKey(const Key('auth-otp')), findsOneWidget);
      expect(find.text(strings.verifyOtp), findsOneWidget);
      expect(find.text(strings.enterAfterConfirm), findsOneWidget);
    },
  );

  testWidgets('back to sign-in returns to the default screen', (tester) async {
    final strings = AppStrings('en');
    await pumpAuth(tester, locale: 'en');

    await tester.ensureVisible(find.byKey(const Key('auth-open-register')));
    await tester.tap(find.byKey(const Key('auth-open-register')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('auth-back-sign-in')));
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
    await pumpAuth(tester, auth: auth);

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
    await pumpAuth(tester);
    await tester.ensureVisible(find.byKey(const Key('auth-open-register')));
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
    await pumpAuth(tester, auth: MemoryAuth(unavailableProviders: true));

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
    await pumpAuth(tester, auth: auth);

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-magic-link')));
    await tester.pumpAndSettle();

    expect(auth.magicLinks, ['ada@example.com']);
    expect(find.text(strings.magicLinkSentTitle), findsOneWidget);
    expect(find.text(strings.magicLinkSentBody), findsOneWidget);
    expect(find.byKey(const Key('auth-otp')), findsOneWidget);
    expect(find.text(strings.errorGeneric), findsNothing);
  });

  testWidgets('oauth callback failure is shown without a crash', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    final auth = MemoryAuth();
    await pumpAuth(tester, auth: auth);

    auth.emitFailure(const AuthProviderUnavailable());
    // The auth stream delivers on a later microtask, which schedules the
    // rebuild for the following frame.
    await tester.pump();
    await tester.pump();

    expect(find.text(strings.authProviderUnavailableGeneric), findsOneWidget);
  });

  testWidgets('sign-in order, brand colors, and password visibility', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    await pumpAuth(tester);

    expect(find.byType(BrandLockup), findsOneWidget);
    expect(find.text(strings.forgotPassword), findsOneWidget);
    final lockupY = tester.getTopLeft(find.byType(BrandLockup)).dy;
    final emailY = tester.getTopLeft(find.byKey(const Key('auth-email'))).dy;
    final passwordY = tester
        .getTopLeft(find.byKey(const Key('auth-password')))
        .dy;
    final forgotY = tester
        .getTopLeft(find.byKey(const Key('auth-forgot-password')))
        .dy;
    final signInY = tester.getTopLeft(find.byKey(const Key('auth-sign-in'))).dy;
    final magicY = tester
        .getTopLeft(find.byKey(const Key('auth-magic-link')))
        .dy;
    final dividerY = tester.getTopLeft(find.text(strings.authOrDivider)).dy;
    final googleY = tester.getTopLeft(find.byKey(const Key('auth-google'))).dy;
    final appleY = tester.getTopLeft(find.byKey(const Key('auth-apple'))).dy;
    final registerY = tester
        .getTopLeft(find.byKey(const Key('auth-open-register')))
        .dy;
    expect(lockupY, lessThan(emailY));
    expect(emailY, lessThan(passwordY));
    expect(passwordY, lessThan(forgotY));
    expect(forgotY, lessThan(signInY));
    expect(signInY, lessThan(magicY));
    expect(magicY, lessThan(dividerY));
    expect(dividerY, lessThan(googleY));
    expect(googleY, lessThan(appleY));
    expect(appleY, lessThan(registerY));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, BrandColors.cream);
    final signInContext = tester.element(find.byKey(const Key('auth-sign-in')));
    final filled = FilledButtonTheme.of(signInContext).style;
    expect(
      filled?.backgroundColor?.resolve(<WidgetState>{}),
      BrandColors.forest,
    );
    expect(
      filled?.foregroundColor?.resolve(<WidgetState>{}),
      BrandColors.onPrimary,
    );
    final google = tester.widget<OutlinedButton>(
      find.byKey(const Key('auth-google')),
    );
    expect(
      google.style?.side?.resolve(<WidgetState>{}),
      const BorderSide(color: BrandColors.forest),
    );
    expect(
      google.style?.backgroundColor?.resolve(<WidgetState>{}),
      BrandColors.cream,
    );
    final forgot = tester.widget<TextButton>(
      find.byKey(const Key('auth-forgot-password')),
    );
    expect(
      forgot.style?.foregroundColor?.resolve(<WidgetState>{}),
      BrandColors.bark,
    );
    final divider = tester.widget<Divider>(find.byType(Divider).first);
    expect(divider.color, BrandColors.beige);

    var password = tester.widget<TextField>(
      find.byKey(const Key('auth-password')),
    );
    expect(password.obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byKey(const Key('auth-toggle-password')));
    await tester.pump();
    password = tester.widget<TextField>(find.byKey(const Key('auth-password')));
    expect(password.obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('auth-open-register')));
    await tester.tap(find.byKey(const Key('auth-open-register')));
    await tester.pumpAndSettle();
    password = tester.widget<TextField>(find.byKey(const Key('auth-password')));
    expect(password.obscureText, isTrue);
    await tester.tap(find.byKey(const Key('auth-toggle-password')));
    await tester.pump();
    password = tester.widget<TextField>(find.byKey(const Key('auth-password')));
    expect(password.obscureText, isFalse);
  });

  testWidgets('forgot password emails a reset link and confirms check email', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    final auth = MemoryAuth();
    await pumpAuth(tester, auth: auth);

    await tester.tap(find.byKey(const Key('auth-forgot-password')));
    await tester.pumpAndSettle();
    expect(find.text(strings.forgotPasswordTitle), findsOneWidget);
    expect(find.byKey(const Key('auth-send-reset')), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-send-reset')));
    await tester.pumpAndSettle();
    expect(auth.resetEmails, isEmpty);
    expect(find.text(strings.errorGeneric), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-send-reset')));
    await tester.pumpAndSettle();

    expect(auth.resetEmails, ['ada@example.com']);
    expect(find.text(strings.resetEmailSentTitle), findsOneWidget);
    expect(find.text(strings.resetEmailSentBody), findsOneWidget);
    expect(find.text(strings.errorGeneric), findsNothing);

    await tester.tap(find.byKey(const Key('auth-back-sign-in')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-forgot-password')), findsOneWidget);
    expect(find.text(strings.signIn), findsOneWidget);
  });

  testWidgets('password recovery sets a new password and rejects mismatches', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    final auth = MemoryAuth();
    await pumpAuth(tester, auth: auth);

    auth.beginPasswordRecovery();
    await tester.pump();
    await tester.pump();

    expect(find.text(strings.setPasswordTitle), findsNWidgets(2));
    expect(find.byKey(const Key('auth-new-password')), findsOneWidget);
    expect(find.byKey(const Key('auth-confirm-password')), findsOneWidget);
    expect(find.byKey(const Key('auth-email')), findsNothing);

    await tester.enterText(find.byKey(const Key('auth-new-password')), 'abc');
    await tester.enterText(
      find.byKey(const Key('auth-confirm-password')),
      'abc',
    );
    await tester.tap(find.byKey(const Key('auth-save-password')));
    await tester.pumpAndSettle();
    expect(find.text(strings.passwordTooShort), findsOneWidget);
    expect(auth.updatedPasswords, isEmpty);
    final error = tester.widget<Text>(find.byKey(const Key('auth-error')));
    expect(error.style?.color, BrandColors.error);

    await tester.enterText(
      find.byKey(const Key('auth-new-password')),
      'secret12',
    );
    await tester.enterText(
      find.byKey(const Key('auth-confirm-password')),
      'secret99',
    );
    await tester.tap(find.byKey(const Key('auth-save-password')));
    await tester.pumpAndSettle();
    expect(find.text(strings.passwordMismatch), findsOneWidget);
    expect(auth.updatedPasswords, isEmpty);
    expect(auth.pendingPasswordRecovery, isTrue);

    var field = tester.widget<TextField>(
      find.byKey(const Key('auth-new-password')),
    );
    expect(field.obscureText, isTrue);
    await tester.tap(find.byKey(const Key('auth-toggle-new-password')));
    await tester.pump();
    field = tester.widget<TextField>(
      find.byKey(const Key('auth-new-password')),
    );
    expect(field.obscureText, isFalse);
    final confirm = tester.widget<TextField>(
      find.byKey(const Key('auth-confirm-password')),
    );
    expect(confirm.obscureText, isTrue);

    await tester.enterText(
      find.byKey(const Key('auth-confirm-password')),
      'secret12',
    );
    await tester.tap(find.byKey(const Key('auth-save-password')));
    await tester.pumpAndSettle();
    expect(auth.updatedPasswords, ['secret12']);
    expect(auth.pendingPasswordRecovery, isFalse);
    expect(find.text(strings.passwordMismatch), findsNothing);
  });

  testWidgets('cold-start recovery opens the new-password screen', (
    tester,
  ) async {
    final auth = MemoryAuth(
      user: const Profile(id: 'user-1', email: 'ada@example.com', locale: 'cs'),
    );
    auth.beginPasswordRecovery();
    await pumpAuth(tester, auth: auth);

    expect(find.byKey(const Key('auth-new-password')), findsOneWidget);
    expect(find.byKey(const Key('auth-sign-in')), findsNothing);
  });
}
