import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/wird_player_screen.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/ayah_block.dart';
import 'package:wirdi/widgets/collection_row.dart';
import 'package:wirdi/widgets/dhikr_block.dart';
import 'package:wirdi/widgets/voussoir_stripe.dart';

import '../support/fixtures.dart';

/// The player, rendering each of the three kinds of step.
///
/// The fixture collection exists for exactly this: dhikr, ayah and surah items
/// in one collection, with a repeat block in the middle of it. Nothing here
/// asserts on Quranic or dhikr text, because the fixtures contain none — the
/// strings are labels saying which row they are.
///
/// One mechanic across all three: the content area counts, the band names the
/// gesture, and there is no advance button anywhere.
void main() {
  late TestDatabases dbs;
  late WirdiData data;

  const CollectionId mixed = BuiltinCollectionId(mixedCollectionId);

  setUp(() async {
    dbs = await TestDatabases.open();
    data = WirdiData(content: dbs.content, user: dbs.user);
  });

  tearDown(() => dbs.close());

  /// Pumps a fixed run of frames rather than settling: a screen showing a
  /// [CircularProgressIndicator] while it loads never stops scheduling frames,
  /// and `pumpAndSettle` waits for it until the timeout.
  Future<void> settle(WidgetTester tester) async {
    for (int frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Opens the player at [stepIndex] by seeding the progress row, which is the
  /// same door a resume comes through.
  Future<void> openAt(
    WidgetTester tester,
    int stepIndex, {
    double height = 1400,
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    if (stepIndex > 0) {
      final ResolvedCollection resolved = await dbs
          .collectionRepository()
          .resolve(mixed);
      await dbs.userRepository().saveProgress(
        WirdProgress.atStep(
          collectionId: mixed,
          step: resolved.steps[stepIndex],
          currentCount: 0,
        ),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: MaterialApp(
          // The real theme: the reading widgets read the typography extension
          // and assert it is there.
          theme: WirdiTheme.light(),
          // The reduce-motion switch, as the OS hands it over: the real
          // media query with one flag turned, rather than a bare one that
          // would take the window's size out with it.
          home: Builder(
            builder: (BuildContext context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: const WirdPlayerScreen(collectionId: mixed),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  group('a dhikr step', () {
    testWidgets('shows the dhikr, its count and the collection position', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 0);

      expect(find.byType(DhikrBlock), findsOneWidget);
      expect(find.text('PLACEHOLDER dhikr 1001 arabic'), findsOneWidget);
      expect(find.text('PLACEHOLDER dhikr 1001 translation'), findsOneWidget);
      // Step one of fourteen: four loose items, nine steps of the repeat
      // block, and the trailing dhikr.
      expect(find.text('1 of 14'), findsOneWidget);
      // The header says what this is, and the plate says how many times —
      // including at one, where a plate that vanished would be worse.
      expect(find.text('Dhikr'), findsOneWidget);
      expect(find.text('×1'), findsOneWidget);
      // One unit said once and no repeat block: there is no position to state.
      expect(find.textContaining('Repeat'), findsNothing);
      // The band: the count, the word, and the gesture in words.
      expect(find.text('1'), findsWidgets);
      expect(find.text('left'), findsOneWidget);
      expect(find.text('Tap anywhere above to count'), findsOneWidget);
    });

    testWidgets('the position line counts the repetitions of the step', (
      WidgetTester tester,
    ) async {
      // Step two is the dhikr with a count override of 100.
      await openAt(tester, 1);

      expect(find.text('×100'), findsOneWidget);
      expect(find.text('Repeat 1 of 100'), findsOneWidget);

      await tester.tap(find.text('PLACEHOLDER dhikr 1002 translation'));
      await tester.pump();

      expect(find.text('Repeat 2 of 100'), findsOneWidget);
      // The count is stated once, in the band. The plate never carries it.
      expect(find.text('99'), findsOneWidget);
    });

    testWidgets('counts down on a tap anywhere in the content', (
      WidgetTester tester,
    ) async {
      // Step two is the dhikr with a count override of 100.
      await openAt(tester, 1);
      expect(find.text('100'), findsOneWidget);

      // The translation is not a button; the tap lands on the content area
      // that wraps it.
      await tester.tap(find.text('PLACEHOLDER dhikr 1002 translation'));
      await tester.pump();

      expect(find.text('99'), findsOneWidget);
      expect(find.text('2 of 14'), findsOneWidget, reason: 'same step');
    });

    testWidgets('has no advance button: the band names the gesture instead', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 1);

      // The content area counts and the band says so in words. A second
      // control for the same thing is a second place for the count to
      // disagree with itself.
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Tap anywhere above to count'), findsOneWidget);
      // Undo stays where it is, outside the counting area.
      expect(find.widgetWithText(OutlinedButton, 'Undo'), findsOneWidget);
    });

    testWidgets('the source and the per-collection note are shown', (
      WidgetTester tester,
    ) async {
      // The last step: dhikr 1003, which carries both.
      await openAt(tester, 13);

      expect(find.text('PLACEHOLDER item note'), findsOneWidget);
      expect(
        find.textContaining('PLACEHOLDER source 2 collection'),
        findsOneWidget,
      );
    });

    testWidgets('undo takes the last tap back', (WidgetTester tester) async {
      await openAt(tester, 1);

      await tester.tap(find.text('PLACEHOLDER dhikr 1002 translation'));
      await tester.pump();
      expect(find.text('99'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Undo'));
      await tester.pump();
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('undo steps back across a step boundary', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 0);

      // Nothing counted on the first step: there is nothing behind this.
      final Finder undo = find.widgetWithText(OutlinedButton, 'Undo');
      expect(tester.widget<OutlinedButton>(undo).onPressed, isNull);

      // A count of one, so this tap finishes the step and advances.
      await tester.tap(find.text('PLACEHOLDER dhikr 1001 translation'));
      await settle(tester);
      expect(find.text('2 of 14'), findsOneWidget);

      await tester.tap(undo);
      await settle(tester);

      // Back on the step the advancing tap moved off, at its full count —
      // nothing left of it, rather than back at the beginning of it.
      expect(find.text('1 of 14'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('an ayah step', () {
    testWidgets('shows the verse, its reference and the translation', (
      WidgetTester tester,
    ) async {
      // Step three is ayah 2:255.
      await openAt(tester, 2);

      expect(find.byType(AyahBlock), findsOneWidget);
      expect(
        find.textContaining('PLACEHOLDER ayah 2:255 uthmani'),
        findsOneWidget,
      );
      expect(find.text('PLACEHOLDER ayah 2:255 translation'), findsOneWidget);
      // The reference is the step's name, in the header, and said once.
      expect(
        find.text('PLACEHOLDER surah 2 transliterated 2:255'),
        findsOneWidget,
      );
      expect(find.text('Single ayah'), findsOneWidget);
      expect(find.text('3 of 14'), findsOneWidget);
    });

    testWidgets('counts on a tap, like a dhikr', (WidgetTester tester) async {
      await openAt(tester, 2);

      await tester.tap(find.text('PLACEHOLDER ayah 2:255 translation'));
      await settle(tester);

      // A count of one, so the tap finishes the step and moves on by itself.
      expect(find.text('4 of 14'), findsOneWidget);
    });
  });

  group('a surah step', () {
    testWidgets('shows one ayah at a time, under the surah it belongs to', (
      WidgetTester tester,
    ) async {
      // Step five is the first pass of the repeat block: surah 112, of four
      // ayahs, recited three times.
      await openAt(tester, 4);

      expect(find.text('5 of 14'), findsOneWidget);
      expect(find.text('PLACEHOLDER surah 112 transliterated'), findsOneWidget);
      expect(find.text('Surah 112 · 4 ayahs'), findsOneWidget);
      // Said once each time round the block, so the plate is x1 and the round
      // in the position line is the block's.
      expect(find.text('×1'), findsOneWidget);
      expect(find.text('Ayah 1 of 4 · round 1 of 3'), findsOneWidget);

      // One verse, not the whole surah.
      expect(find.byType(AyahBlock), findsOneWidget);
      expect(
        find.textContaining('PLACEHOLDER ayah 112:1 uthmani'),
        findsOneWidget,
      );
      expect(
        find.textContaining('PLACEHOLDER ayah 112:2 uthmani'),
        findsNothing,
      );

      // And it counts the same way everything else does.
      expect(find.byType(FilledButton), findsNothing);
      expect(
        find.text('Tap anywhere above to go to the next ayah'),
        findsOneWidget,
      );
      // One reading left, never four ayahs: what is left of a step is always
      // repetitions of it.
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a tap on the text moves to the next ayah', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 4);

      await tester.tap(find.text('PLACEHOLDER ayah 112:1 translation'));
      await settle(tester);

      // The same step, one unit further in.
      expect(find.text('5 of 14'), findsOneWidget);
      expect(find.text('Ayah 2 of 4 · round 1 of 3'), findsOneWidget);
      expect(
        find.textContaining('PLACEHOLDER ayah 112:2 uthmani'),
        findsOneWidget,
      );
      // Still one reading of the surah left: it is not finished until the
      // last ayah of it is.
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('the last ayah of the reading finishes the step', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 4);

      for (int tap = 0; tap < 3; tap++) {
        await tester.tap(find.byType(AyahBlock));
        await settle(tester);
      }
      expect(find.text('Ayah 4 of 4 · round 1 of 3'), findsOneWidget);
      expect(find.text('5 of 14'), findsOneWidget);

      // The tap that consumes the last unit completes the step and moves on by
      // itself, exactly as the tap that reaches a dhikr's count does.
      await tester.tap(find.byType(AyahBlock));
      await settle(tester);
      expect(find.text('6 of 14'), findsOneWidget);
    });

    testWidgets('undo steps back to the previous ayah', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 4);

      await tester.tap(find.byType(AyahBlock));
      await settle(tester);
      expect(find.text('Ayah 2 of 4 · round 1 of 3'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Undo'));
      await settle(tester);

      expect(find.text('Ayah 1 of 4 · round 1 of 3'), findsOneWidget);
    });

    testWidgets('the basmala heads the reading, and only its first ayah', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 4);

      // Taken from 1:1 with its verse number stripped, which is why the
      // fixture's surah 1 is seeded in full.
      expect(find.byType(BismillahHeading), findsOneWidget);

      await tester.tap(find.byType(AyahBlock));
      await settle(tester);

      // It heads a reading, not every verse of one.
      expect(find.byType(BismillahHeading), findsNothing);
      expect(find.text('Ayah 2 of 4 · round 1 of 3'), findsOneWidget);
    });

    testWidgets('the gesture and the position are both announced', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openAt(tester, 4);

      // The band is the live region, and it carries the unit as well as the
      // count and the step.
      expect(
        find.bySemanticsLabel('1 left, ayah 1 of 4, step 5 of 14'),
        findsOneWidget,
      );
      // And the content area says what tapping it does, rather than only
      // offering the tap.
      expect(find.bySemanticsLabel('Next ayah'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('in a repeat block the round is the block\'s', (
      WidgetTester tester,
    ) async {
      // Step eight is surah 112 again, on the second pass of the block.
      await openAt(tester, 7);

      expect(find.text('Ayah 1 of 4 · round 2 of 3'), findsOneWidget);
    });
  });

  group('moving between steps', () {
    testWidgets('a new step starts at the top of its own scroll', (
      WidgetTester tester,
    ) async {
      // A short screen, so the verse overflows and there is something to
      // scroll.
      await openAt(tester, 2, height: 380);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -120),
      );
      await tester.pump();
      expect(_offsetOf(tester), greaterThan(0));

      await tester.tap(find.byIcon(Icons.skip_next_outlined));
      await settle(tester);

      // A fresh subtree for the new step, so it does not arrive half way down
      // the page the last one was left on.
      expect(_offsetOf(tester), 0);
    });
  });

  group('the stripe', () {
    testWidgets('is cut into one segment per step of the collection', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 0);

      // Fourteen steps, fourteen segments — not the current step's count.
      expect(_stripe(tester).segments, 14);
      expect(_stripe(tester).value, 0);
    });

    testWidgets('measures the wird, not the step', (WidgetTester tester) async {
      // Step two of fourteen: a dhikr said a hundred times.
      await openAt(tester, 1);
      expect(_stripe(tester).value, closeTo(1 / 14, 0.0001));

      await tester.tap(find.text('PLACEHOLDER dhikr 1002 translation'));
      await tester.pump();

      // One tap of a hundred moves the stripe by a hundredth of one step's
      // share of the wird, and the counter by one.
      expect(find.text('99'), findsOneWidget);
      expect(_stripe(tester).value, closeTo(1.01 / 14, 0.0001));
    });

    testWidgets('is half way at the half way step', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 7);

      expect(_stripe(tester).value, closeTo(0.5, 0.0001));
    });
  });

  group('finishing', () {
    testWidgets('the last step logs the completion and shows the finished '
        'step, which closes on a tap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Resumed at the last step: the trailing dhikr, said three times.
      final ResolvedCollection resolved = await dbs
          .collectionRepository()
          .resolve(mixed);
      await dbs.userRepository().saveProgress(
        WirdProgress.atStep(
          collectionId: mixed,
          step: resolved.steps.last,
          currentCount: 0,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
          child: MaterialApp(
            theme: WirdiTheme.light(),
            onGenerateRoute: WirdiRouter.onGenerateRoute,
            initialRoute: Routes.shell,
          ),
        ),
      );
      await settle(tester);
      // The shell opens on Home; this collection is reached from the
      // collections list, which is a tab away.
      await tester.tap(find.text('Collections'));
      await settle(tester);
      // The row itself no longer opens anything — only its buttons do — so the
      // play button is found scoped to this row rather than by tapping the
      // name. The button beside it opens the contents, which is not the player.
      final Finder row = find.ancestor(
        of: find.text('PLACEHOLDER collection 1 english'),
        matching: find.byType(CollectionRow),
      );
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('Recite')),
      );
      await settle(tester);
      expect(find.text('14 of 14'), findsOneWidget);
      expect(find.text('Repeat 1 of 3'), findsOneWidget);

      final Finder text = find.text('PLACEHOLDER dhikr 1003 translation');
      await tester.tap(text);
      await tester.pump();
      await tester.tap(text);
      await tester.pump();
      await tester.tap(text);
      await tester.pump();

      // The finished step, shaped like every step before it: a header, a tap
      // target, and the band naming the gesture. The stripe is solid.
      expect(find.text('Wird complete'), findsOneWidget);
      expect(find.text('الْحَمْدُ لِلَّهِ'), findsOneWidget);
      expect(
        find.text('Consistency is the key. May it be accepted, Ameen.'),
        findsOneWidget,
      );
      expect(find.text('done'), findsOneWidget);
      expect(find.text('Tap anywhere above to close'), findsOneWidget);
      expect(_stripe(tester).value, 1);
      // Nothing has left on its own, and nothing is going to. Two seconds is
      // also well past the reveal, so what is on screen is the whole of it.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('الْحَمْدُ لِلَّهِ'), findsOneWidget);

      // The completion is logged the moment the wird ends, not when the step
      // is closed: the run of days it reports is read back from the table.
      expect(await dbs.userRepository().isCompletedToday(mixed), isTrue);
      expect(await dbs.userRepository().progress(mixed), isNull);
      await settle(tester);
      expect(find.text('A day begun.'), findsOneWidget);

      // A tap anywhere in the content area closes it, the same gesture that
      // counted every step.
      await tester.tap(find.text('الْحَمْدُ لِلَّهِ'));
      await tester.pump();

      // The screen comes apart first: part way through the run the route is
      // still there, in pieces, and the pop is what the end of it runs into.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('الْحَمْدُ لِلَّهِ'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await settle(tester);

      // Back on the list it was opened from, with the row marked.
      expect(find.textContaining('Done today'), findsOneWidget);
    });

    testWidgets('the tap that finished the wird does not close the step', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 13);
      expect(find.text('14 of 14'), findsOneWidget);

      final Finder text = find.text('PLACEHOLDER dhikr 1003 translation');
      await tester.tap(text);
      await tester.pump();
      await tester.tap(text);
      await tester.pump();
      await tester.tap(text);
      await tester.pump();

      // A tasbih is counted faster than a screen changes, and the tap after
      // the last one is already on its way down. It lands on the finished
      // step, which is not taking taps yet — so the reciter sees the end of
      // their wird instead of tapping straight through it.
      expect(_closeTap(tester), isNull);
      await tester.tap(find.text('الْحَمْدُ لِلَّهِ'));
      await tester.pump();
      expect(find.text('الْحَمْدُ لِلَّهِ'), findsOneWidget);

      // Still shut a beat in, which is where the words are still arriving:
      // the step is closed for as long as the reveal lasts, not for a timer
      // of its own.
      await tester.pump(const WirdiMotion.standardTiming().completion);
      expect(_closeTap(tester), isNull);

      // The reveal over, the whole content area is the way out, exactly as it
      // was the way forward on every step before this one.
      await tester.pump(const WirdiMotion.standardTiming().completionReveal);
      expect(_closeTap(tester), isNotNull);
    });

    testWidgets('the finished step arrives in three fades', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 13);

      final Finder text = find.text('PLACEHOLDER dhikr 1003 translation');
      await tester.tap(text);
      await tester.pump();
      await tester.tap(text);
      await tester.pump();
      await tester.tap(text);
      await tester.pump();

      const String praise = 'الْحَمْدُ لِلَّهِ';
      const String sentence =
          'Consistency is the key. May it be accepted, Ameen.';
      final Finder tally = find.textContaining('14 steps');

      // On the frame the wird ends the whole step is laid out and none of it
      // is inked in: it arrives, it does not appear.
      expect(_fade(tester, find.text(praise)), 0);
      expect(_fade(tester, find.text(sentence)), 0);
      expect(_fade(tester, tally), 0);

      // The praise first, alone.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_fade(tester, find.text(praise)), greaterThan(0));
      expect(_fade(tester, find.text(sentence)), 0);
      expect(_fade(tester, tally), 0);

      // Then the sentence under it, while the tally is still to come.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_fade(tester, find.text(sentence)), greaterThan(0));
      expect(_fade(tester, tally), 0);

      // Then what was recited.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_fade(tester, tally), greaterThan(0));

      // And at the end of it, three lines at full strength, in the order they
      // are read in.
      await tester.pump(const WirdiMotion.standardTiming().completionReveal);
      expect(_fade(tester, find.text(praise)), 1);
      expect(_fade(tester, find.text(sentence)), 1);
      expect(_fade(tester, tally), 1);
    });

    testWidgets('a reciter who has turned animations off gets the step whole', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 13, disableAnimations: true);

      final Finder text = find.text('PLACEHOLDER dhikr 1003 translation');
      await tester.tap(text);
      await tester.pump();
      await tester.tap(text);
      await tester.pump();
      await tester.tap(text);
      await tester.pump();

      // Nothing to wait for: the words are there on the frame the wird ends,
      // and the step takes the tap out straight away.
      expect(_fade(tester, find.text('الْحَمْدُ لِلَّهِ')), 1);
      expect(_closeTap(tester), isNotNull);
    });
  });

  group('start over', () {
    testWidgets('is in the overflow, and puts the player back at the top', (
      WidgetTester tester,
    ) async {
      await openAt(tester, 7);
      expect(find.text('8 of 14'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await settle(tester);
      await tester.tap(find.text('Start over'));
      await settle(tester);

      expect(find.text('1 of 14'), findsOneWidget);
      expect(await dbs.userRepository().progress(mixed), isNull);
    });
  });
}

/// What a tap on the finished step's content area does, or null while the step
/// is still ignoring taps.
VoidCallback? _closeTap(WidgetTester tester) {
  return tester
      .widgetList<GestureDetector>(
        find.ancestor(
          of: find.text('الْحَمْدُ لِلَّهِ'),
          matching: find.byType(GestureDetector),
        ),
      )
      .first
      .onTap;
}

/// How far in a line of the finished step is, 0 to 1.
///
/// The nearest [FadeTransition] over it, which is the one the reveal drives:
/// every line of the step has one and holds its place in the layout whatever
/// it reads.
double _fade(WidgetTester tester, Finder line) {
  return tester
      .widget<FadeTransition>(
        find.ancestor(of: line, matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;
}

/// Where the content area is scrolled to.
double _offsetOf(WidgetTester tester) {
  return tester
      .state<ScrollableState>(find.byType(Scrollable).last)
      .position
      .pixels;
}

/// The progress stripe under the app bar. There is one, and it is the counter's.
VoussoirStripe _stripe(WidgetTester tester) {
  return tester.widget<VoussoirStripe>(
    find.byWidgetPredicate(
      (Widget widget) => widget is VoussoirStripe && widget.value != null,
    ),
  );
}
