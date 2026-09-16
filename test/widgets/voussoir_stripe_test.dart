import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/voussoir_stripe.dart';

/// What the stripe actually paints, which is the only place its arithmetic is
/// visible.
///
/// This file exists because a stripe can hold the right numbers and draw the
/// wrong picture. `VoussoirStripe.progress` is given a fraction and quantises
/// it back to whole segments, and `k / n * n` is not reliably `k` in binary
/// floating point: at fifty-one steps the thirty-first arrives as
/// 30.999999999999996, so the stripe painted thirty lit segments on the step
/// where thirty-one were done. Nothing in the widget tree was wrong — the value
/// and the segment count both read exactly as intended — and the count of lit
/// segments is not a property of anything, so the picture is what has to be
/// asserted on.
void main() {
  final ThemeData theme = WirdiTheme.light();
  final Color filled = theme.colorScheme.primary;

  /// Renders [stripe] and counts the segments that came out lit.
  ///
  /// A width that divides evenly by the segment count, so a segment boundary
  /// is never inside a pixel and the count is exact.
  Future<int> litSegments(
    WidgetTester tester,
    VoussoirStripe stripe, {
    required int segments,
    double width = 510,
  }) async {
    const Key key = Key('stripe');
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(width: width, child: stripe),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final RenderRepaintBoundary boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byKey(key));
    int lit = 0;
    // Both the rasterisation and the read have to happen inside runAsync;
    // toByteData never completes on the fake async zone.
    await tester.binding.runAsync<void>(() async {
      final ui.Image image = await boundary.toImage();
      final ByteData pixels = (await image.toByteData())!;
      final int y = image.height ~/ 2;
      for (int segment = 0; segment < segments; segment++) {
        // The middle of the segment, so an antialiased edge cannot be read as
        // the segment itself.
        final int x = ((segment + 0.5) * image.width / segments).floor();
        final int offset = (y * image.width + x) * 4;
        final int r = pixels.getUint8(offset);
        final int g = pixels.getUint8(offset + 1);
        final int b = pixels.getUint8(offset + 2);
        if (r == filled.r * 255 && g == filled.g * 255 && b == filled.b * 255) {
          lit++;
        }
      }
      image.dispose();
    });
    return lit;
  }

  group('a counted stripe', () {
    testWidgets('lights exactly the segments it was given', (
      WidgetTester tester,
    ) async {
      expect(
        await litSegments(
          tester,
          const VoussoirStripe.counted(lit: 0, of: 17),
          segments: 17,
        ),
        0,
      );
      expect(
        await litSegments(
          tester,
          const VoussoirStripe.counted(lit: 9, of: 17),
          segments: 17,
        ),
        9,
      );
      expect(
        await litSegments(
          tester,
          const VoussoirStripe.counted(lit: 17, of: 17),
          segments: 17,
        ),
        17,
      );
    });

    testWidgets('moves on every count, including the ones a fraction rounds '
        'short', (WidgetTester tester) async {
      // 29, 57 and 58 hundredths are the counts where `k / 100 * 100` lands
      // below k. A counted stripe never does that arithmetic.
      for (final int count in <int>[28, 29, 30, 56, 57, 58, 59]) {
        expect(
          await litSegments(
            tester,
            VoussoirStripe.counted(lit: count, of: 100),
            segments: 100,
            width: 500,
          ),
          count,
          reason: 'count $count',
        );
      }
    });
  });

  group('a progress stripe', () {
    testWidgets('quantises down, so nearly full does not look finished', (
      WidgetTester tester,
    ) async {
      expect(
        await litSegments(
          tester,
          const VoussoirStripe.progress(value: 0.96, segments: 10),
          segments: 10,
        ),
        9,
      );
    });

    testWidgets('lights a segment for a step that is exactly done', (
      WidgetTester tester,
    ) async {
      // The wird stripe's own case: step thirty-one of fifty-one, arriving as
      // a fraction. Without the slack in the painter this is thirty.
      expect(
        await litSegments(
          tester,
          const VoussoirStripe.progress(value: 31 / 51, segments: 51),
          segments: 51,
          width: 510,
        ),
        31,
      );
    });
  });
}
