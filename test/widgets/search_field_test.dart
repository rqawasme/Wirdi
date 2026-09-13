import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/search_field.dart';

/// The one field in the app that searches anything.
void main() {
  late TextEditingController controller;
  late List<String> changes;

  setUp(() {
    controller = TextEditingController();
    changes = <String>[];
  });

  tearDown(() => controller.dispose());

  Future<void> pumpField(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WirdiTheme.light(),
        home: Scaffold(
          body: SearchField(
            controller: controller,
            hintText: 'Search the Arabic or the translation',
            onChanged: changes.add,
          ),
        ),
      ),
    );
  }

  testWidgets('the hint names what is being matched', (
    WidgetTester tester,
  ) async {
    await pumpField(tester);

    // Not "Search". The hint is the only instruction the screen gives, so it
    // says what the query is compared against.
    expect(find.text('Search the Arabic or the translation'), findsOneWidget);
  });

  testWidgets('there is nothing to clear until there is something to clear', (
    WidgetTester tester,
  ) async {
    await pumpField(tester);
    expect(find.byTooltip('Clear the search'), findsNothing);

    await tester.enterText(find.byType(TextField), 'morning');
    await tester.pump();
    expect(find.byTooltip('Clear the search'), findsOneWidget);
  });

  testWidgets('clearing empties the controller and says so', (
    WidgetTester tester,
  ) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'morning');
    await tester.pump();
    changes.clear();

    await tester.tap(find.byTooltip('Clear the search'));
    await tester.pump();

    expect(controller.text, isEmpty);
    // The callback fires on the clear too: a listener that only hears about
    // typing would keep showing the filtered list after the field emptied.
    expect(changes, <String>['']);
    expect(find.byTooltip('Clear the search'), findsNothing);
  });

  testWidgets('typing reaches the callback', (WidgetTester tester) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'ev');
    await tester.pump();

    expect(changes, contains('ev'));
  });

  testWidgets('focus does not change the border', (WidgetTester tester) async {
    await pumpField(tester);

    // Focus is the caret and the keyboard. A field that also changes colour is
    // saying it twice, and the colour it would reach for is `primary`, which
    // this app keeps for the wird itself.
    final InputDecoration decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(decoration.focusedBorder, decoration.enabledBorder);
  });
}
