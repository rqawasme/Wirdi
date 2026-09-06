import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/theme/theme.dart';
import 'package:wirdi/widgets/voussoir_arch.dart';

/// The arch is the one shape in this app that is not a rectangle, and the
/// terms it was allowed in are geometric: it is built out of blocks with
/// straight edges, and it is quieter than anything it sits behind. Neither is
/// visible in a widget test that only asks whether it rendered, so this asks
/// the canvas what was actually drawn.
/// Everything the painter asked the canvas to do, in order.
final class _Recorder implements Canvas {
  final List<Path> paths = <Path>[];
  final List<Color> colours = <Color>[];
  final List<Symbol> calls = <Symbol>[];

  @override
  void drawPath(Path path, Paint paint) {
    paths.add(path);
    colours.add(paint.color);
    calls.add(#drawPath);
  }

  /// Anything else the painter reaches for is recorded and not performed,
  /// which is how a stroked arc or a rounded rectangle shows up here as a
  /// failure rather than as a picture nobody looked at.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName);
    return null;
  }
}

void main() {
  Future<_Recorder> paint(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Center(
          child: SizedBox(width: 174, height: 240, child: VoussoirArch()),
        ),
      ),
    );
    // MaterialApp lerps from one theme to the next, so the frame a pump leaves
    // behind is still part-way there when this is called twice.
    await tester.pumpAndSettle();

    final CustomPaint widget = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(VoussoirArch),
        matching: find.byType(CustomPaint),
      ),
    );
    final _Recorder recorder = _Recorder();
    widget.painter!.paint(recorder, const Size(174, 240));
    return recorder;
  }

  testWidgets('is drawn as blocks, and never as a curve', (
    WidgetTester tester,
  ) async {
    final _Recorder recorder = await paint(tester, WirdiTheme.light());

    // One path per voussoir, and nothing else asked of the canvas. This is the
    // constraint the whole widget exists under: the app's shape language is
    // masonry, so the curve is in how the blocks are arranged and never in a
    // block. An arc, an oval or a rounded rect here is the design being lost.
    expect(recorder.calls, hasLength(VoussoirArch.defaultVoussoirs));
    expect(recorder.calls.toSet(), <Symbol>{#drawPath});

    for (final Path path in recorder.paths) {
      // Four corners and the close: a quadrilateral, with no control points
      // between them.
      final List<ui.PathMetric> metrics = path.computeMetrics().toList();
      expect(metrics, hasLength(1));
      expect(path.getBounds().isEmpty, isFalse);
    }
  });

  testWidgets('stands on the bottom of the box, and inside its sides', (
    WidgetTester tester,
  ) async {
    final _Recorder recorder = await paint(tester, WirdiTheme.light());

    Rect union = recorder.paths.first.getBounds();
    for (final Path path in recorder.paths) {
      union = union.expandToInclude(path.getBounds());
    }

    // Centred, standing on the bottom edge, and in the lower half of the card
    // — the text lives above it.
    expect(union.center.dx, closeTo(174 / 2, 1));
    expect(union.bottom, closeTo(240, 1));
    expect(union.top, greaterThan(240 * 0.35));
    // Clear of both side edges, so the arch is never cut off at the haunches.
    expect(union.left, greaterThan(0));
    expect(union.right, lessThan(174));
  });

  testWidgets('is painted in the faintest role there is, in both themes', (
    WidgetTester tester,
  ) async {
    for (final ThemeData theme in <ThemeData>[
      WirdiTheme.light(),
      WirdiTheme.dark(),
    ]) {
      final _Recorder recorder = await paint(tester, theme);
      final ColorScheme scheme = theme.colorScheme;

      expect(recorder.colours.toSet(), hasLength(1), reason: 'one course');
      final Color painted = recorder.colours.first;

      // outlineVariant, taken down further still. Never brick, which is
      // licensed for progress and selection and nothing else, and never gold.
      expect(painted, isNot(scheme.primary));
      expect(painted, isNot(scheme.tertiary));
      expect(painted, isNot(scheme.onSurface));
      expect(painted.a, lessThan(1));
      expect(
        painted.withValues(alpha: 1),
        isSameColorAs(scheme.outlineVariant.withValues(alpha: 1)),
      );
    }
  });
}
