import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/catalog_screen.dart';
import 'package:viateria/ui/screens/missing_config_screen.dart';
import 'package:viateria/ui/widgets/diploma_view.dart';

import 'helpers/fakes.dart';

AppServices buildServices({
  List<Challenge>? challenges,
  List<PromoStripe>? promos,
  bool configured = true,
}) {
  final open = sampleOpenChallenge();
  final story = sampleStoryChallenge();
  final draft = Challenge(
    id: 'draft-1',
    slug: 'hidden',
    accessMode: AccessMode.open,
    pricingType: PricingType.free,
    priceCents: 0,
    currency: 'eur',
    status: PublishStatus.draft,
    translations: const [
      LocalizedText(locale: 'en', title: 'Hidden draft', description: ''),
    ],
  );
  return AppServices(
    config: AppConfig(
      supabaseUrl: configured ? 'https://example.supabase.co' : '',
      supabaseAnonKey: configured ? 'anon' : '',
      stripePublishableKey: configured ? 'pk_test' : '',
    ),
    auth: MemoryAuth(
      user: const Profile(id: 'user-1', locale: 'en', displayName: 'Ada'),
    ),
    catalog: MemoryCatalog(
      challenges: challenges ?? [open.challenge, story.challenge, draft],
      details: [open, story],
      promos: promos ?? [samplePromo()],
    ),
    progress: MemoryProgress(details: [open, story]),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
  );
}

Widget wrap(Widget child, AppServices services, {LocaleController? locale}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => locale ?? LocaleController(initial: 'en'),
      ),
      Provider.value(value: services),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('catalog smoke: published challenges and promo stripe, no drafts',
      (tester) async {
    await tester.pumpWidget(
      wrap(const CatalogScreen(), buildServices()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Weekend hike'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Open trail'), 400);
    expect(find.text('Open trail'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Story trail'), 400);
    expect(find.text('Story trail'), findsOneWidget);
    expect(find.text('Hidden draft'), findsNothing);
  });

  testWidgets('catalog empty state when CMS has no published rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const CatalogScreen(),
        buildServices(challenges: const [], promos: const []),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings('en').catalogEmpty), findsOneWidget);
  });

  testWidgets('missing config screen is shown when secrets are absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MissingConfigScreen(), buildServices(configured: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings('en').missingConfig), findsOneWidget);
  });

  testWidgets('diploma is 9:16 with medals', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: DiplomaView(
                challengeTitle: 'Open trail',
                explorerName: 'Ada',
                completedAt: DateTime.utc(2026, 9, 7),
                medalCount: 3,
                strings: AppStrings('en'),
                showConfetti: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sized = tester.getSize(find.byType(DiplomaView));
    expect(sized.width / sized.height, closeTo(9 / 16, 0.02));
    expect(find.text('Open trail'), findsOneWidget);
    expect(find.byIcon(Icons.military_tech), findsNWidgets(3));
  });
}
