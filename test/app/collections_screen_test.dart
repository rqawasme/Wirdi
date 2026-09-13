import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/collections_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/collection_row.dart';

import '../support/fixtures.dart';

/// The collections list: what a row says, and where it goes.
void main() {
  late TestDatabases dbs;
  late WirdiData data;

  const CollectionId mixed = BuiltinCollectionId(mixedCollectionId);

  setUp(() async {
    dbs = await TestDatabases.open();
    data = WirdiData(content: dbs.content, user: dbs.user);
  });

  tearDown(() => dbs.close());

  Future<void> settle(WidgetTester tester) async {
    for (int frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpList(
    WidgetTester tester, {
    bool withRouter = false,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          // The body on its own for what a row says, and the whole shell for
          // where a row goes. CollectionsScreen has no Scaffold of its own any
          // more — the app bar and the navigation bar belong to AppShell — so
          // the bare pump supplies one.
          home: withRouter ? null : const Scaffold(body: CollectionsScreen()),
          onGenerateRoute: withRouter ? WirdiRouter.onGenerateRoute : null,
          initialRoute: withRouter ? Routes.shell : null,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
        ),
      ),
    );
    await settle(tester);
    if (withRouter) {
      // The shell opens on Home. The collections list is a tab away.
      await tester.tap(find.text('Collections'));
      await settle(tester);
    }
  }

  testWidgets('lists the built-ins with their item counts', (
    WidgetTester tester,
  ) async {
    await pumpList(tester);

    expect(find.text('PLACEHOLDER collection 1 english'), findsOneWidget);
    expect(find.text('PLACEHOLDER collection 2 english'), findsOneWidget);
    // Items as the collection is written: four loose items, one repeat block
    // and a trailing dhikr. The block's nine playback steps are the player's
    // business, not the list's.
    expect(find.text('6 items'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('says nothing about a collection that has not been started', (
    WidgetTester tester,
  ) async {
    await pumpList(tester);

    expect(find.textContaining('Done today'), findsNothing);
    expect(find.textContaining('Part-way'), findsNothing);
  });

  testWidgets('marks a collection completed today, quietly', (
    WidgetTester tester,
  ) async {
    await dbs.userRepository().logCompletion(mixed, DateTime.now());

    await pumpList(tester);

    // The mark is part of the meta line rather than a component of its own,
    // so this is the same paragraph as the item count.
    expect(find.textContaining('Done today'), findsOneWidget);
    // A small check in the same colour as the item count beside it, and no
    // other mark: a daily habit finished is the expected outcome.
    final Icon check = tester.widget<Icon>(find.byIcon(Icons.check));
    expect(check.color, WirdiTheme.light().colorScheme.onSurfaceVariant);
  });

  testWidgets('shows a collection that is part-way through', (
    WidgetTester tester,
  ) async {
    final ResolvedCollection resolved = await dbs
        .collectionRepository()
        .resolve(mixed);
    await dbs.userRepository().saveProgress(
      WirdProgress.atStep(
        collectionId: mixed,
        step: resolved.steps[3],
        currentCount: 0,
      ),
    );

    await pumpList(tester);

    expect(find.textContaining('Part-way through'), findsOneWidget);
  });

  testWidgets('a position at the very beginning is not progress', (
    WidgetTester tester,
  ) async {
    final ResolvedCollection resolved = await dbs
        .collectionRepository()
        .resolve(mixed);
    await dbs.userRepository().saveProgress(
      WirdProgress.atStep(
        collectionId: mixed,
        step: resolved.steps.first,
        currentCount: 0,
      ),
    );

    await pumpList(tester);

    // Nobody has done anything yet, and a row that says otherwise is a lie the
    // user cannot clear.
    expect(find.textContaining('Part-way through'), findsNothing);
  });

  testWidgets('a stale saved position does not show as progress', (
    WidgetTester tester,
  ) async {
    await dbs.userRepository().saveProgress(
      WirdProgress(
        collectionId: mixed,
        stepIndex: 8,
        // Not what sits at index 8 any more.
        stepRef: const ContentRef.dhikr(9999),
        currentCount: 2,
      ),
    );

    await pumpList(tester);

    // Validated through the same resumableFrom check the player makes, so the
    // list cannot promise a resume the player will then discard.
    expect(find.textContaining('Part-way through'), findsNothing);
  });

  /// The row itself opens nothing — only its buttons do — so a button is found
  /// scoped to its own row rather than by tapping the name.
  Future<void> tapRowButton(WidgetTester tester, String tooltip) async {
    final Finder row = find.ancestor(
      of: find.text('PLACEHOLDER collection 1 english'),
      matching: find.byType(CollectionRow),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip(tooltip)),
    );
    await settle(tester);
  }

  testWidgets("a row's contents button opens what is in the collection", (
    WidgetTester tester,
  ) async {
    await pumpList(tester, withRouter: true);
    await tapRowButton(tester, 'See what is in it');

    // The contents, not the player: no step counter, and the whole collection
    // on one screen rather than one item of it.
    expect(find.text('1 of 14'), findsNothing);
    expect(find.text('PLACEHOLDER dhikr 1001 arabic'), findsOneWidget);
    expect(find.text('Repeated 3 times'), findsOneWidget);
  });

  testWidgets("a row's play button opens the player", (
    WidgetTester tester,
  ) async {
    await pumpList(tester, withRouter: true);
    await tapRowButton(tester, 'Recite');

    expect(find.text('1 of 14'), findsOneWidget);
    expect(find.text('PLACEHOLDER dhikr 1001 arabic'), findsOneWidget);
  });

  testWidgets('a description is shown when there is one, and not when there '
      'is not', (WidgetTester tester) async {
    await pumpList(tester);

    expect(find.text('PLACEHOLDER collection 1 description'), findsOneWidget);
    // The second fixture carries none, the way nine of the fourteen real
    // built-ins do. Nothing is drawn in its place.
    expect(find.text('PLACEHOLDER collection 2 description'), findsNothing);
  });

  group('the shapes a row has to survive', () {
    testWidgets('a described row keeps its four buttons and its meta line at '
        'the largest text scale', (WidgetTester tester) async {
      // The row changed shape for the fourth button: names, description and
      // meta each take the full width now, and the buttons share the bottom
      // line with the meta. This is the scale that decides whether that was
      // enough.
      await pumpList(tester, textScaler: const TextScaler.linear(2));
      expect(tester.takeException(), isNull);

      final Finder row = find.ancestor(
        of: find.text('PLACEHOLDER collection 1 english'),
        matching: find.byType(CollectionRow),
      );

      // All four still there and still distinguishable.
      for (final String tooltip in <String>[
        'See what is in it',
        'Recite',
        'Commit to my practice',
        'More',
      ]) {
        expect(
          find.descendant(of: row, matching: find.byTooltip(tooltip)),
          findsOneWidget,
          reason: '$tooltip went missing at 2x',
        );
      }

      // And the row still says what state it is in. The description is capped
      // at two lines precisely so it cannot push this off the bottom.
      expect(
        find.descendant(of: row, matching: find.textContaining('items')),
        findsOneWidget,
      );
    });

    testWidgets('a long description is clipped rather than unbounded', (
      WidgetTester tester,
    ) async {
      await pumpList(tester);

      final Text description = tester.widget<Text>(
        find.text('PLACEHOLDER collection 1 description'),
      );
      expect(description.maxLines, 2);
      expect(description.overflow, TextOverflow.ellipsis);
    });
  });
}
