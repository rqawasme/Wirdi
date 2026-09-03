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

  Future<void> pumpList(WidgetTester tester, {bool withRouter = false}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: MaterialApp(
          theme: WirdiTheme.light(),
          home: withRouter ? null : const CollectionsScreen(),
          onGenerateRoute: withRouter ? WirdiRouter.onGenerateRoute : null,
          initialRoute: withRouter ? Routes.collections : null,
        ),
      ),
    );
    await settle(tester);
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

  testWidgets('a row opens the player', (WidgetTester tester) async {
    await pumpList(tester, withRouter: true);

    await tester.tap(find.text('PLACEHOLDER collection 1 english'));
    await settle(tester);

    expect(find.text('1 of 14'), findsOneWidget);
    expect(find.text('PLACEHOLDER dhikr 1001 arabic'), findsOneWidget);
  });
}
