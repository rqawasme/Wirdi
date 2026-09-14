import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/data/wirdi_data.dart';
import 'package:wirdi/providers/data_providers.dart';
import 'package:wirdi/routes.dart';
import 'package:wirdi/screens/settings_screen.dart';
import 'package:wirdi/theme/theme.dart';

import '../support/fixtures.dart';

/// Android's three-button navigation bar is drawn on top of the app, and the
/// window reports it as bottom padding. A scroll view given an explicit
/// `padding` opts out of the padding [MediaQuery] would otherwise have applied
/// for it, so every such list has to add that inset back — see
/// [WirdiMetrics.withSystemBottom].
///
/// Settings is the screen it was noticed on: About Wirdi is the last thing on
/// it, and the buttons sat over the button.
void main() {
  /// A three-button navigation bar, in the units [FlutterView] reports.
  const double navigationBar = 48;

  group('WirdiMetrics.withSystemBottom', () {
    testWidgets('adds what the system draws over the bottom edge', (
      WidgetTester tester,
    ) async {
      late EdgeInsets padded;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: navigationBar),
          ),
          child: Builder(
            builder: (BuildContext context) {
              padded = WirdiMetrics.withSystemBottom(
                context,
                const EdgeInsets.fromLTRB(1, 2, 3, WirdiMetrics.space6),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // The bottom, and only the bottom.
      expect(
        padded,
        const EdgeInsets.fromLTRB(1, 2, 3, WirdiMetrics.space6 + navigationBar),
      );
    });

    testWidgets('adds nothing where there is nothing over the edge', (
      WidgetTester tester,
    ) async {
      // Gesture navigation with no handle, a desktop window, a screen whose
      // bottom bar has already taken the inset: the constant is the whole
      // padding, and the call site is no worse off for having asked.
      late EdgeInsets padded;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (BuildContext context) {
              padded = WirdiMetrics.withSystemBottom(
                context,
                const EdgeInsets.only(bottom: WirdiMetrics.space6),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(padded, const EdgeInsets.only(bottom: WirdiMetrics.space6));
    });
  });

  group('settings', () {
    late TestDatabases dbs;
    late WirdiData data;

    setUp(() async {
      dbs = await TestDatabases.open();
      data = WirdiData(content: dbs.content, user: dbs.user);
    });

    tearDown(() => dbs.close());

    Future<void> settle(WidgetTester tester) async {
      for (int frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('About Wirdi clears the three-button navigation bar', (
      WidgetTester tester,
    ) async {
      // Short enough that the screen scrolls, so that scrolling to the end is
      // the case under test rather than a list with room to spare.
      const double height = 800;
      tester.view.physicalSize = const Size(400, height);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: navigationBar);
      tester.view.viewPadding = const FakeViewPadding(bottom: navigationBar);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
          child: MaterialApp(
            theme: WirdiTheme.light(),
            home: const SettingsScreen(),
            onGenerateRoute: WirdiRouter.onGenerateRoute,
          ),
        ),
      );
      await settle(tester);

      // All the way down, and not merely far enough to have brought the button
      // on screen: under the navigation bar is exactly where the end of an
      // unpadded list puts it.
      final ScrollableState list = tester.state(
        find.byType(Scrollable, skipOffstage: false).first,
      );
      list.position.jumpTo(list.position.maxScrollExtent);
      await settle(tester);

      expect(
        tester.getRect(find.text('About Wirdi')).bottom,
        lessThanOrEqualTo(height - navigationBar),
        reason: 'the navigation bar is drawn over the bottom 48dp',
      );
    });
  });
}
