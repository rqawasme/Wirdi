import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/content_database.dart';
import 'package:wirdi/data/user_database.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/settings.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/voussoir_stripe.dart';
import 'package:wirdi/wirdi_app.dart';

/// The app, pumped.
///
/// Not a test of how anything looks — `flutter_test` renders in a test font,
/// and whether Amiri Quran holds up is a question for a device. What it does
/// check is that the tree builds against real content without throwing, that
/// the theme reaches the widgets that need it, and that a control writes
/// through to `user.db` rather than only to a `setState`.
void main() {
  final File contentFile = File('content/build/content.db');

  group(
    'the dev screen',
    () => _tests(contentFile),
    skip: contentFile.existsSync()
        ? false
        : 'no ${contentFile.path} — run content/scripts/build_content.py',
  );
}

void _tests(File contentFile) {
  late WirdiData data;

  setUp(() {
    data = WirdiData(
      content: ContentDatabase.openReadOnly(contentFile),
      user: UserDatabase.memory(),
    );
  });

  tearDown(() => data.close());

  Future<void> pumpApp(WidgetTester tester) async {
    // A phone, rather than the 800x600 the test binding defaults to: the dev
    // screen puts a control panel under a scrolling list, and the two only
    // share the screen sensibly at a real aspect ratio.
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: const WirdiApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the samples out of the real database', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Type check'), findsOneWidget);
    // The stripe, above the first sample, in both of its modes.
    expect(find.byType(VoussoirStripe), findsWidgets);

    // The samples are built lazily, so reaching one means scrolling to it.
    for (final String reference in <String>['2:1', '2:255', '18:1-2']) {
      await tester.scrollUntilVisible(
        find.text(reference),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(reference), findsOneWidget);
    }
  });

  testWidgets('the theme carries the typography and motion extensions', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final BuildContext context = tester.element(find.byType(Scaffold).first);
    final ThemeData theme = Theme.of(context);

    expect(theme.extension<WirdiTypography>(), isNotNull);
    expect(theme.extension<WirdiMotion>()?.counter, Duration.zero);
    // The palette is the hand-written one, not a seeded approximation of it.
    expect(theme.colorScheme.primary, const Color(0xFF9E4630));
    expect(theme.colorScheme.surface, const Color(0xFFFBF6EC));
  });

  testWidgets('a control writes through to user.db', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(await data.userRepository.setting(SettingKeys.devQuranInGold), null);

    await tester.ensureVisible(find.text('Cedar ink'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cedar ink'));
    await tester.pumpAndSettle();

    expect(
      await data.userRepository.setting(SettingKeys.devQuranInGold),
      'false',
      reason: 'the dev controls persist the same way a real setting would',
    );
  });

  testWidgets('the Arabic size control stores a multiplier, not pixels', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(WirdiApp)),
    );
    await container
        .read(settingsProvider.notifier)
        .setArabicScale(32 / WirdiTypography.quranVerseSize);
    await tester.pumpAndSettle();

    final String? stored = await data.userRepository.setting(
      SettingKeys.arabicScale,
    );
    expect(double.parse(stored!), closeTo(1.3333, 0.0001));

    // And it reaches the type scale: 32 nominal, then the face's optical
    // correction on top.
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    final WirdiTypography type = Theme.of(
      context,
    ).extension<WirdiTypography>()!;
    expect(
      type.quranVerse.fontSize,
      closeTo(32 * ArabicFace.quran.opticalMultiplier, 0.01),
    );
  });
}
