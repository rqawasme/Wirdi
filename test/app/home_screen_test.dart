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
      await user.commit(mixed, DailySection.today);
      await user.commit(simple, DailySection.today);
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
      expect(find.text('Today'), findsNothing);
      expect(find.text('Morning'), findsNothing);
    });

    testWidgets(
      'the order is Today, Morning, Evening whatever the clock says',
      (WidgetTester tester) async {
        final UserRepository user = dbs.userRepository(clock: () => now);
        // Committed in the reverse of the order they should render in.
        await user.commit(mixed, DailySection.evening);
        await user.commit(simple, DailySection.today);

        await pumpApp(tester);

        final double today = tester.getTopLeft(find.text('Today')).dy;
        final double evening = tester.getTopLeft(find.text('Evening')).dy;
        expect(today, lessThan(evening));
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
          .commit(mixed, DailySection.today);

      await pumpApp(tester);

      // Six entries and fourteen steps, but what the user has to say is the
      // repetitions — and that is what the stripe measures, so it is what the
      // count beside it has to be. Nothing done yet, so the fraction opens at
      // zero rather than saying what is in there.
      expect(find.text('0/${await repetitions(mixed)}'), findsOneWidget);
    });

    testWidgets('part-way through says how far, and lights the stripe', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.today);
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
      expect(find.text('41/$total'), findsOneWidget);

      final VoussoirStripe stripe = tester.widget<VoussoirStripe>(
        find.descendant(
          of: find.byType(CollectionTile),
          matching: find.byType(VoussoirStripe),
        ),
      );
      expect(stripe.segments, CollectionTile.maxSegments);
      expect(stripe.value, closeTo(41 / total, 0.001));
    });

    testWidgets('done today fills the stripe, and quiets everything else', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.today);
      await user.logCompletion(mixed, now);

      await pumpApp(tester);

      expect(find.textContaining('Done today'), findsOneWidget);

      // A full band of brick, and off the completion rather than off the
      // counts: finishing clears the progress row, so a stripe reading the
      // counts here would be empty.
      final Finder tile = find.byType(CollectionTile);
      final VoussoirStripe stripe = tester.widget<VoussoirStripe>(
        find.descendant(of: tile, matching: find.byType(VoussoirStripe)),
      );
      expect(stripe.value, 1);

      // Everything else on the tile still steps down: one tonal step, and no
      // shadow, no badge and no second mark arriving to say the same thing.
      final ColorScheme scheme = WirdiTheme.light().colorScheme;
      final Material material = tester.widget<Material>(
        find.descendant(of: tile, matching: find.byType(Material)).first,
      );
      expect(material.color, scheme.surfaceContainerHigh);
      expect(material.elevation, 0);
      expect(material.shadowColor, Colors.transparent);
      expect(
        find.descendant(of: tile, matching: find.byType(Icon)),
        findsOneWidget,
        reason: 'the check in the meta line, and nothing else',
      );
    });

    testWidgets('every tile done leaves them all the same, not one louder', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.today);
      await user.commit(simple, DailySection.today);
      await user.logCompletion(mixed, now);
      await user.logCompletion(simple, now);

      await pumpApp(tester);

      expect(find.textContaining('Done today'), findsNWidgets(2));
      // Both full, and neither one more finished than the other.
      final Iterable<VoussoirStripe> stripes = tester
          .widgetList<VoussoirStripe>(
            find.descendant(
              of: find.byType(CollectionTile),
              matching: find.byType(VoussoirStripe),
            ),
          );
      expect(stripes, hasLength(2));
      expect(stripes.map((VoussoirStripe s) => s.value).toSet(), <double>{1});
    });

    testWidgets('every tile is the same shape, whatever its name', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      final UserCollectionId long = await dbs.collectionRepository().create(
        'Ayat al-Kursi, three times, every morning and evening',
      );
      await user.commit(mixed, DailySection.today);
      await user.commit(long, DailySection.today);

      await pumpApp(tester);

      // Both of them, side by side: a name that wraps to three lines makes the
      // same object as one that fits on one. Taller than wide, and one shape
      // rather than merely one ratio.
      final Set<Size> shapes = find
          .byType(CollectionTile)
          .evaluate()
          .map((Element element) => element.size!)
          .toSet();
      expect(shapes, hasLength(1));
      expect(
        shapes.single.width / shapes.single.height,
        closeTo(CollectionTile.aspectRatio, 0.01),
      );

      // And what a long name costs is its own opening line, not the strip or
      // the count: those sit at the same height on both tiles.
      final List<double> metaTops = find
          .textContaining('/')
          .evaluate()
          .map(
            (Element element) =>
                tester.getTopLeft(find.byWidget(element.widget)).dy,
          )
          .toList();
      expect(metaTops, hasLength(2));
      expect(metaTops.first, closeTo(metaTops.last, 0.5));
    });

    testWidgets('a name with no Arabic leaves no line box behind', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      final UserCollectionId mine = await dbs.collectionRepository().create(
        'Mine',
      );
      // The built-in carries an Arabic name; a user collection never does.
      await user.commit(mixed, DailySection.today);
      await user.commit(mine, DailySection.today);

      await pumpApp(tester);

      // No Arabic name, no line held open for one: the English name starts at
      // the top of the tile rather than under an empty gap.
      final Finder arabic = find.text('PLACEHOLDER collection 1 arabic');
      final double withArabic = tester
          .getTopLeft(find.text('PLACEHOLDER collection 1 english'))
          .dy;
      final double without = tester.getTopLeft(find.text('Mine')).dy;
      expect(without, lessThan(withArabic));
      expect(without, closeTo(tester.getTopLeft(arabic).dy, 0.5));

      // And the Arabic that is there sits against the right edge of its tile.
      final Rect tile = tester.getRect(
        find.ancestor(of: arabic, matching: find.byType(CollectionTile)),
      );
      expect(
        tester.getRect(arabic).right,
        closeTo(tile.right - WirdiMetrics.space3, 1),
      );
    });

    testWidgets('the strip marks the days this collection was done', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.today);
      await user.commit(simple, DailySection.today);

      // Not today, so the marks stay brick: yesterday, three days ago and six
      // days ago for one collection, and one other day for the other.
      for (final int back in <int>[1, 3, 6]) {
        await user.logCompletion(mixed, now.subtract(Duration(days: back)));
      }
      await user.logCompletion(simple, now.subtract(const Duration(days: 2)));

      await pumpApp(tester);

      final ColorScheme scheme = WirdiTheme.light().colorScheme;

      /// The marks of one tile, oldest first: true where it is brick.
      List<bool> strip(String name) => tester
          .widgetList<Container>(
            find.descendant(
              of: find.ancestor(
                of: find.text(name),
                matching: find.byType(CollectionTile),
              ),
              matching: find.byType(Container),
            ),
          )
          .map(
            (Container c) =>
                (c.decoration! as BoxDecoration).color == scheme.primary,
          )
          .toList();

      // Seven marks each, and the last of them is today.
      expect(strip('PLACEHOLDER collection 1 english'), <bool>[
        true, // six days ago
        false,
        false,
        true, // three days ago
        false,
        true, // yesterday
        false, // today
      ]);
      expect(strip('PLACEHOLDER collection 2 english'), <bool>[
        false,
        false,
        false,
        false,
        true, // two days ago
        false,
        false,
      ]);
    });

    testWidgets('a finished tile keeps its days in brick', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.today);
      await user.logCompletion(mixed, now.subtract(const Duration(days: 1)));
      await user.logCompletion(mixed, now);

      await pumpApp(tester);

      // Yesterday and today, both still brick. The marks are history, and
      // what a week held does not change because today is over.
      final ColorScheme scheme = WirdiTheme.light().colorScheme;
      final Iterable<Container> brick = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(CollectionTile),
              matching: find.byType(Container),
            ),
          )
          .where(
            (Container c) =>
                c.decoration is BoxDecoration &&
                (c.decoration! as BoxDecoration).color == scheme.primary,
          );
      expect(brick, hasLength(2));
    });

    testWidgets('says something about the run of days, and never a warning', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.today);
      await user.commit(simple, DailySection.today);
      // Three days up to yesterday, and not yet today: a run in progress.
      for (final int back in <int>[1, 2, 3]) {
        await user.logCompletion(mixed, now.subtract(Duration(days: back)));
      }

      await pumpApp(tester);

      expect(find.text('3 days. Keep going.'), findsOneWidget);
      // Nothing done ever, and it reads as an opening rather than as a zero.
      expect(find.text('A good day to begin.'), findsOneWidget);

      // The line encourages, which is a departure from the rest of the app,
      // but it never leans: no countdown, no warning, nothing about what a
      // missed day costs. This is the half of `StreakPanel`'s argument that
      // still holds here.
      final RegExp pressure = RegExp(
        r"don't|do not|risk|lose|lost|broke|about to|"
        r'before midnight|hours left|come back',
        caseSensitive: false,
      );
      for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(matches(pressure)));
      }
    });

    testWidgets('a finished run says so, and does not say it twice', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.today);
      await user.logCompletion(mixed, now.subtract(const Duration(days: 1)));
      await user.logCompletion(mixed, now);

      await pumpApp(tester);

      // Two days, counting today. The meta line below already says "Done
      // today", so the line above it does not.
      expect(find.text('2 days and counting.'), findsOneWidget);
      expect(find.textContaining('Done today'), findsOneWidget);
    });

    testWidgets('the run is this collection\'s own, not the app\'s', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.today);
      await user.commit(simple, DailySection.today);
      // Something was completed on each of the last three days, so the app's
      // streak is three — but neither collection has a run of its own.
      await user.logCompletion(mixed, now.subtract(const Duration(days: 3)));
      await user.logCompletion(simple, now.subtract(const Duration(days: 2)));
      await user.logCompletion(mixed, now.subtract(const Duration(days: 1)));

      await pumpApp(tester);

      // The greeting counts everything; the cards count themselves.
      expect(
        find.text('3 days in a row. Nothing finished today.'),
        findsOneWidget,
      );
      expect(find.text('One day. Keep going.'), findsNothing);
      expect(find.text('Day one. Keep going.'), findsOneWidget);
      expect(find.text('A good day to begin.'), findsOneWidget);
    });

    testWidgets('opens the player, and is stale when it comes back', (
      WidgetTester tester,
    ) async {
      await dbs
          .userRepository(clock: () => now)
          .commit(mixed, DailySection.today);

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
        await user.commit(id, DailySection.today);
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
      await user.commit(mixed, DailySection.today);
      await user.commit(simple, DailySection.today);

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
          .commit(mixed, DailySection.today);

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

  group('the days a commitment falls on', () {
    testWidgets('every day is the default, so it is on today', (
      WidgetTester tester,
    ) async {
      await dbs
          .userRepository(clock: () => now)
          .commit(mixed, DailySection.today);

      await pumpApp(tester);

      expect(find.byType(CollectionTile), findsOneWidget);
    });

    testWidgets('a collection for another day is not on the screen at all', (
      WidgetTester tester,
    ) async {
      // `now` is a Wednesday; this is committed to Fridays.
      await dbs
          .userRepository(clock: () => now)
          .commit(
            mixed,
            DailySection.today,
            days: Weekdays.of(<int>[DateTime.friday]),
          );

      await pumpApp(tester);

      // Not a greyed-out tile and not an empty section: the screen is what
      // today contains, and today does not contain this.
      expect(find.byType(CollectionTile), findsNothing);
      expect(find.text('Today'), findsNothing);
      expect(find.text('Nothing committed yet'), findsOneWidget);
    });

    testWidgets('and is on the screen on the day it falls on', (
      WidgetTester tester,
    ) async {
      await dbs
          .userRepository(clock: () => now)
          .commit(
            mixed,
            DailySection.today,
            days: Weekdays.of(<int>[DateTime.wednesday]),
          );

      await pumpApp(tester);

      expect(find.text('Today'), findsOneWidget);
      expect(find.byType(CollectionTile), findsOneWidget);
    });

    testWidgets('the greeting counts today\'s commitments, not all of them', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(mixed, DailySection.today);
      await user.commit(
        simple,
        DailySection.today,
        days: Weekdays.of(<int>[DateTime.friday]),
      );
      await user.logCompletion(mixed, now);

      await pumpApp(tester);

      // One of one, not one of two: the Friday commitment is not part of
      // today and saying otherwise would make the day look unfinished.
      expect(find.textContaining('One of one finished today.'), findsOneWidget);
    });

    testWidgets('days are orthogonal to the section', (
      WidgetTester tester,
    ) async {
      final UserRepository user = dbs.userRepository(clock: () => now);
      await user.commit(
        mixed,
        DailySection.morning,
        days: Weekdays.of(<int>[DateTime.wednesday]),
      );
      await user.commit(
        simple,
        DailySection.evening,
        days: Weekdays.of(<int>[DateTime.friday]),
      );

      await pumpApp(tester);

      // A Wednesday morning shows; a Friday evening does not. The section says
      // where in the day, the days say whether at all.
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Evening'), findsNothing);
    });
  });
}
