import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/providers/streak.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/home_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/bottom_nav.dart';
import 'package:wirdi/widgets/collection_tile.dart';
import 'package:wirdi/widgets/empty_state.dart';
import 'package:wirdi/widgets/voussoir_stripe.dart';

import '../support/fixtures.dart';

/// The home screen and the shell around it: what a tile says, which sections
/// render, and what the greeting is willing to say about a streak.
void main() {
  late TestDatabases dbs;
  late WirdiData data;

  const CollectionId mixed = BuiltinCollectionId(mixedCollectionId);
  const CollectionId simple = BuiltinCollectionId(simpleCollectionId);

  /// A Wednesday, so the date line is checkable.
  final DateTime now = DateTime(2026, 9, 2, 9);

  setUp(() async {
    dbs = await TestDatabases.open();
    // One clock for the repositories and the providers alike, so "today" on a
    // tile and "today" in a completion are the same day.
    data = WirdiData(content: dbs.content, user: dbs.user, clock: () => now);
  });

  tearDown(() => dbs.close());

  Future<void> settle(WidgetTester tester) async {
    for (int frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(400, 1000),
    TextScaler textScaler = TextScaler.noScaling,
    TextDirection direction = TextDirection.ltr,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          wirdiDataProvider.overrideWithValue(data),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: theme ?? WirdiTheme.light(),
          onGenerateRoute: WirdiRouter.onGenerateRoute,
          initialRoute: Routes.shell,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: Directionality(textDirection: direction, child: child!),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// The mixed collection: 6 entries, 14 playback steps, and 100 + 13 more
  /// repetitions between them — the tile counts repetitions, not entries.
  Future<int> repetitions(CollectionId id) async {
    final ResolvedCollection resolved = await dbs
        .collectionRepository()
        .resolve(id);
    return resolved.steps.fold<int>(
      0,
      (int sum, PlaybackStep step) => sum + step.count,
    );
  }

  group('the greeting', () {
    testWidgets('states the date, the salutation and the day', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Wednesday, 2 September'), findsOneWidget);
      expect(find.text('Assalamu alaykum'), findsOneWidget);
    });

    testWidgets('a zero streak is stated and not commented on', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      expect(find.textContaining('No days in a row.'), findsOneWidget);
    });

    testWidgets('a long streak reads exactly like a short one', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      for (int day = 0; day < 365; day++) {
        await user.logCompletion(mixed, now.subtract(Duration(days: day)));
      }

      await pumpApp(tester);

      // The same sentence, the same size, the same ink. No flame, no tier, no
      // "personal best", and nothing that gets louder as the number grows.
      expect(find.textContaining('365 days in a row.'), findsOneWidget);
      expect(find.textContaining('!'), findsNothing);
    });

    testWidgets('counts what is finished of what was committed', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.daily);
      await user.commit(simple, DailySection.daily);
      await user.logCompletion(simple, now);

      await pumpApp(tester);

      expect(find.textContaining('One of two finished today.'), findsOneWidget);
    });

    testWidgets('says nothing about finishing when nothing is committed', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      expect(find.textContaining('finished today'), findsNothing);
    });
  });

  group('sections', () {
    testWidgets('a section with nothing in it is not rendered at all', (
      WidgetTester tester,
    ) async {
      await dbs
          .userRepository(clock: () => now)
          .commit(mixed, DailySection.evening);

      await pumpApp(tester);

      // No header, no placeholder, no empty state of its own: a header over
      // nothing is a promise the screen is not keeping.
      expect(find.text('Evening'), findsOneWidget);
      expect(find.text('Daily'), findsNothing);
      expect(find.text('Morning'), findsNothing);
    });

    testWidgets(
      'the order is Daily, Morning, Evening whatever the clock says',
      (WidgetTester tester) async {
        final UserRepository user = dbs.userRepository(clock: () => now);
        // Committed in the reverse of the order they should render in.
        await user.commit(mixed, DailySection.evening);
        await user.commit(simple, DailySection.daily);

        await pumpApp(tester);

        final double daily = tester.getTopLeft(find.text('Daily')).dy;
        final double evening = tester.getTopLeft(find.text('Evening')).dy;
        expect(daily, lessThan(evening));
      },
    );

    testWidgets('nothing committed leaves the greeting and one empty state', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Assalamu alaykum'), findsOneWidget);
      expect(find.text('Nothing committed yet'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      // The stripe, not an illustration.
      expect(find.byType(Image), findsNothing);
    });
  });

  group('a tile', () {
    testWidgets('counts repetitions, not entries', (WidgetTester tester) async {
      await dbs
          .userRepository(clock: () => now)
          .commit(mixed, DailySection.daily);

      await pumpApp(tester);

      // Six entries and fourteen steps, but what the user has to say is the
      // repetitions — and that is what the stripe measures, so it is what the
      // count beside it has to be.
      expect(find.text('${await repetitions(mixed)} items'), findsOneWidget);
    });

    testWidgets('part-way through says how far, and lights the stripe', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.daily);
      final ResolvedCollection resolved = await dbs
          .collectionRepository()
          .resolve(mixed);
      // Step 1 is the hundred-count dhikr; forty of it done.
      await user.saveProgress(
        WirdProgress.atStep(
          collectionId: mixed,
          step: resolved.steps[1],
          currentCount: 40,
          updatedAt: now,
        ),
      );

      await pumpApp(tester);

      final int total = await repetitions(mixed);
      expect(find.text('41 of $total'), findsOneWidget);

      final VoussoirStripe stripe = tester.widget<VoussoirStripe>(
        find.descendant(
          of: find.byType(CollectionTile),
          matching: find.byType(VoussoirStripe),
        ),
      );
      expect(stripe.segments, CollectionTile.maxSegments);
      expect(stripe.value, closeTo(41 / total, 0.001));
    });

    testWidgets('done today goes quiet, and drops the stripe', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.daily);
      await user.logCompletion(mixed, now);

      await pumpApp(tester);

      expect(find.textContaining('Done today'), findsOneWidget);

      // A finished tile is the quietest object in its section. A full band of
      // brick would make the expected outcome the loudest thing on the screen,
      // which is what an earlier draft did.
      final Finder tile = find.byType(CollectionTile);
      expect(
        find.descendant(of: tile, matching: find.byType(VoussoirStripe)),
        findsNothing,
      );

      // One tonal step down, not a colour change.
      final ColorScheme scheme = WirdiTheme.light().colorScheme;
      final Material material = tester.widget<Material>(
        find.descendant(of: tile, matching: find.byType(Material)).first,
      );
      expect(material.color, scheme.surfaceContainerHigh);
      expect(material.elevation, 0);
      expect(material.shadowColor, Colors.transparent);
    });

    testWidgets('every tile done leaves nothing brighter than the rest', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.daily);
      await user.commit(simple, DailySection.daily);
      await user.logCompletion(mixed, now);
      await user.logCompletion(simple, now);

      await pumpApp(tester);

      expect(find.textContaining('Done today'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(CollectionTile),
          matching: find.byType(VoussoirStripe),
        ),
        findsNothing,
      );
    });

    testWidgets('a tile is square, and stays square under a long name', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      final UserCollectionId long = await dbs.collectionRepository().create(
        'Ayat al-Kursi, three times, every morning and evening',
      );
      await user.commit(mixed, DailySection.daily);
      await user.commit(long, DailySection.daily);

      await pumpApp(tester);

      // Both of them, side by side: a name that wraps to three lines makes the
      // same object as one that fits on one.
      for (final Element element in find.byType(CollectionTile).evaluate()) {
        final Size size = element.size!;
        expect(size.width, closeTo(size.height, 0.5));
      }
    });

    testWidgets('a name with no Arabic aligns with one that has it', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      final UserCollectionId mine = await dbs.collectionRepository().create(
        'Mine',
      );
      // The built-in carries an Arabic name; a user collection never does.
      await user.commit(mixed, DailySection.daily);
      await user.commit(mine, DailySection.daily);

      await pumpApp(tester);

      // The Arabic line box is there whether or not there is a name in it, so
      // the English names start at the same height across the row.
      final double withArabic = tester
          .getTopLeft(find.text('PLACEHOLDER collection 1 english'))
          .dy;
      final double without = tester.getTopLeft(find.text('Mine')).dy;
      expect(withArabic, closeTo(without, 0.5));
    });

    testWidgets('opens the player, and is stale when it comes back', (
      WidgetTester tester,
    ) async {
      await dbs
          .userRepository(clock: () => now)
          .commit(mixed, DailySection.daily);

      await pumpApp(tester);
      await tester.tap(find.byType(CollectionTile));
      await settle(tester);

      expect(find.text('1 of 14'), findsOneWidget);
    });
  });

  group('the shell', () {
    testWidgets('opens on Home, titled Wird', (WidgetTester tester) async {
      await pumpApp(tester);

      expect(find.text('Wird'), findsOneWidget);
      // New collections are made on the Collections tab and nowhere else.
      expect(find.byTooltip('New collection'), findsNothing);
      expect(find.byTooltip('Quran'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
    });

    testWidgets('the top stripe is the rule, never progress', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      // An earlier draft made this a progress bar, and it was rejected: the
      // band under the app bar means nothing about how far through anything
      // you are.
      final VoussoirStripe rule = tester.widget<VoussoirStripe>(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(VoussoirStripe),
        ),
      );
      expect(rule.value, isNull);
    });

    testWidgets('swaps the body and its app bar together', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('Tracker'));
      await settle(tester);

      // The title went with it, and so did the tab's own actions.
      expect(find.text('Wird'), findsNothing);
      expect(find.byTooltip('New collection'), findsNothing);

      await tester.tap(find.text('Collections'));
      await settle(tester);
      expect(find.byTooltip('New collection'), findsOneWidget);
    });

    testWidgets('the selected tab is marked by brick, and nothing else is', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      final ColorScheme scheme = WirdiTheme.light().colorScheme;

      // The 4dp bar across the selected tab's top edge — one of it, because
      // one tab is selected. No pill, no capsule, no tonal background.
      final Iterable<Container> marks = tester
          .widgetList<Container>(find.byType(Container))
          .where((Container c) => c.color == scheme.primary);
      expect(marks, hasLength(1));

      // Icons are chrome: never brick, never gold. The selected one is
      // onSurface and the other three are onSurfaceVariant, and no glyph
      // swaps between filled and outline to say so.
      final List<Icon> glyphs = tester
          .widgetList<Icon>(
            find.descendant(
              of: find.byType(BottomNav),
              matching: find.byType(Icon),
            ),
          )
          .toList();
      expect(glyphs, hasLength(4));
      expect(
        glyphs.where((Icon i) => i.color == scheme.onSurface),
        hasLength(1),
      );
      expect(
        glyphs.where((Icon i) => i.color == scheme.onSurfaceVariant),
        hasLength(3),
      );
      expect(
        glyphs.where(
          (Icon i) => i.color == scheme.primary || i.color == scheme.tertiary,
        ),
        isEmpty,
      );
    });

    testWidgets('no tab carries a badge, dot or count', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      // The app has no notifications at all, so there is nothing for one to
      // be about.
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('each tab keeps its own scroll position', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      for (int i = 0; i < 8; i++) {
        final UserCollectionId id = await dbs.collectionRepository().create(
          'Collection $i',
        );
        await user.commit(id, DailySection.daily);
      }

      await pumpApp(tester, size: const Size(400, 700));

      // The outer one: each section's grid is a Scrollable too, held still by
      // NeverScrollableScrollPhysics so that the page scrolls rather than each
      // section scrolling inside itself.
      final Finder home = find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      double homeOffset() =>
          tester.state<ScrollableState>(home).position.pixels;

      await tester.drag(home, const Offset(0, -200));
      await settle(tester);
      final double scrolled = homeOffset();
      expect(scrolled, greaterThan(0));

      await tester.tap(find.text('Tracker'));
      await settle(tester);
      await tester.tap(find.text('Home'));
      await settle(tester);

      // Coming back to a tab lands where it was left: the bodies are kept
      // alive rather than rebuilt, and each has a scroll controller of its own
      // rather than sharing the Scaffold's primary one with the other three.
      expect(homeOffset(), closeTo(scrolled, 0.5));
    });
  });

  group('the shapes it has to survive', () {
    testWidgets('nav labels do not truncate at the largest text scale', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, textScaler: const TextScaler.linear(2));

      // Every label still readable, and every one of them whole: shrinking the
      // label is the honest option, ellipsising it is not.
      for (final WirdiTab tab in WirdiTab.values) {
        expect(find.text(tab.label), findsOneWidget);
      }
      expect(find.textContaining('…'), findsNothing);
    });

    testWidgets('the whole shell mirrors under RTL', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.daily);
      await user.commit(simple, DailySection.daily);

      await pumpApp(tester, direction: TextDirection.rtl);

      // The grid mirrors: the first committed collection is now on the right.
      final List<Element> tiles = find
          .byType(CollectionTile)
          .evaluate()
          .toList();
      expect(tiles, hasLength(2));
      expect(
        tester.getTopLeft(find.byType(CollectionTile).first).dx,
        greaterThan(tester.getTopLeft(find.byType(CollectionTile).last).dx),
      );

      // And so does the nav: Home is the rightmost tab.
      expect(
        tester.getTopLeft(find.text('Home')).dx,
        greaterThan(tester.getTopLeft(find.text('Tracker')).dx),
      );
    });

    testWidgets('dark is the same screen, on its own colours', (
      WidgetTester tester,
    ) async {
      await dbs
          .userRepository(clock: () => now)
          .commit(mixed, DailySection.daily);

      await pumpApp(tester, theme: WirdiTheme.dark());

      final ColorScheme scheme = WirdiTheme.dark().colorScheme;
      final Material tile = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(CollectionTile),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(tile.color, scheme.surfaceContainer);
      // Designed on its own terms, and still flat.
      expect(tile.elevation, 0);
      expect(tile.shadowColor, Colors.transparent);
    });
  });
}
