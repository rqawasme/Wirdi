import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/bead_ring.dart';

/// What the ring paints: which beads are lit, in what order, and what the
/// marker bead says.
///
/// Read off the picture, for the stripe test's reason: which beads came out
/// lit is not a property of anything in the widget tree. Each bead is sampled
/// at its middle, where an antialiased edge, its rim and the thread behind it
/// cannot reach.
void main() {
  final ThemeData theme = WirdiTheme.light();
  final ColorScheme scheme = theme.colorScheme;
  final Color lit = scheme.primary;
  final Color unlit = scheme.surfaceContainerHighest;

  /// The middle of bead [index] of [beads], in the ring's own coordinates:
  /// slots of equal size round what the marker leaves, clockwise from the
  /// marker at the bottom.
  Offset beadAt(int index, int beads) {
    const double gap = BeadRing.markerGap * math.pi / 180;
    final double slot = (2 * math.pi - gap) / beads;
    final double angle = math.pi + gap / 2 + slot * (index + 0.5);
    return const Offset(BeadRing.diameter / 2, BeadRing.diameter / 2) +
        Offset(
          BeadRing.radius * math.sin(angle),
          -BeadRing.radius * math.cos(angle),
        );
  }

  const Offset markerAt = Offset(
    BeadRing.diameter / 2,
    BeadRing.diameter / 2 + BeadRing.radius,
  );

  /// Renders [ring] and reads the colour at each of [points].
  Future<List<Color>> sample(
    WidgetTester tester,
    BeadRing ring,
    List<Offset> points,
  ) async {
    const Key key = Key('ring');
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(key: key, child: ring),
          ),
        ),
      ),
    );
    await tester.pump();

    final RenderRepaintBoundary boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byKey(key));
    final List<Color> colours = <Color>[];
    // Both the rasterisation and the read have to happen inside runAsync;
    // toByteData never completes on the fake async zone.
    await tester.binding.runAsync<void>(() async {
      final ui.Image image = await boundary.toImage();
      final ByteData pixels = (await image.toByteData())!;
      for (final Offset point in points) {
        final int offset =
            (point.dy.floor() * image.width + point.dx.floor()) * 4;
        colours.add(
          Color.fromARGB(
            pixels.getUint8(offset + 3),
            pixels.getUint8(offset),
            pixels.getUint8(offset + 1),
            pixels.getUint8(offset + 2),
          ),
        );
      }
      image.dispose();
    });
    return colours;
  }

  /// Which of [beads] beads came out lit, by index.
  Future<List<int>> litBeads(
    WidgetTester tester,
    BeadRing ring,
    int beads,
  ) async {
    final List<Color> colours = await sample(tester, ring, <Offset>[
      for (int i = 0; i < beads; i++) beadAt(i, beads),
    ]);
    for (final Color colour in colours) {
      expect(colour, anyOf(lit, unlit), reason: 'a bead is lit or it is not');
    }
    return <int>[
      for (int i = 0; i < beads; i++)
        if (colours[i] == lit) i,
    ];
  }

  Future<Color> marker(WidgetTester tester, BeadRing ring) async =>
      (await sample(tester, ring, <Offset>[markerAt])).single;

  test('the first bead is the one just round from the marker, on the left', () {
    // Clockwise from the bottom: the order a thumb pulls them in.
    final Offset first = beadAt(0, 33);
    expect(first.dx, lessThan(BeadRing.diameter / 2));
    expect(first.dy, greaterThan(BeadRing.diameter / 2));
  });

  group('a counted ring', () {
    testWidgets('lights its beads in order from the marker', (
      WidgetTester tester,
    ) async {
      expect(
        await litBeads(tester, const BeadRing.counted(lit: 0, of: 33), 33),
        isEmpty,
      );
      expect(
        await litBeads(tester, const BeadRing.counted(lit: 5, of: 33), 33),
        <int>[0, 1, 2, 3, 4],
      );
    });

    testWidgets('fills the marker on the last bead, and not before', (
      WidgetTester tester,
    ) async {
      expect(
        await marker(tester, const BeadRing.counted(lit: 32, of: 33)),
        scheme.tertiaryContainer,
      );
      const BeadRing full = BeadRing.counted(lit: 33, of: 33);
      expect(await litBeads(tester, full, 33), hasLength(33));
      expect(await marker(tester, full), scheme.tertiary);
    });

    testWidgets('holds a hundred beads, each one its own', (
      WidgetTester tester,
    ) async {
      expect(
        await litBeads(tester, const BeadRing.counted(lit: 57, of: 100), 100),
        <int>[for (int i = 0; i < 57; i++) i],
      );
    });
  });

  group('a loose ring', () {
    testWidgets('lights nothing before the first tap', (
      WidgetTester tester,
    ) async {
      const BeadRing ring = BeadRing.loose(count: 0);
      expect(await litBeads(tester, ring, BeadRing.looseBeads), isEmpty);
      // No goal, so no gold: the marker is a bead like the others.
      expect(await marker(tester, ring), unlit);
    });

    testWidgets('lights the one bead under the thumb, and comes back round', (
      WidgetTester tester,
    ) async {
      expect(
        await litBeads(
          tester,
          const BeadRing.loose(count: 1),
          BeadRing.looseBeads,
        ),
        <int>[0],
      );
      expect(
        await litBeads(
          tester,
          const BeadRing.loose(count: 33),
          BeadRing.looseBeads,
        ),
        <int>[32],
      );
      expect(
        await litBeads(
          tester,
          const BeadRing.loose(count: 34),
          BeadRing.looseBeads,
        ),
        <int>[0],
      );
    });
  });
}
