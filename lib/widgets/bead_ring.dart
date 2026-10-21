import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A string of prayer beads, drawn as a ring: the tasbih tab's picture of a
/// round.
///
/// The beads run clockwise from the marker bead at the bottom — the long bead
/// a misbaha's tassel hangs from — up the left, over the top and down the
/// right, back round to the marker. That is the order a thumb pulls them in,
/// and it puts the end of a round where the string itself ends.
///
/// Flat, like everything else in the app: a bead is a disc of colour, not a
/// lit sphere. A counted bead is [ColorScheme.primary], one not yet counted is
/// [ColorScheme.surfaceContainerHighest] ringed in [ColorScheme.outline], and
/// the thread between them is the outline too. The marker bead and the tassel
/// are [ColorScheme.tertiary] — gold, which is the goal's colour and nothing
/// else's: see `WirdiColorSchemes`.
///
/// It has two modes, one per kind of tasbih.
///
///   * [BeadRing.counted], with a goal: [lit] of [beads] are counted, the way
///     `VoussoirStripe.counted` lights segments. The marker bead fills on the
///     tap that lights the last of them.
///   * [BeadRing.loose], with no goal: a string of [looseBeads] with one lit —
///     the bead under the thumb — which moves on a bead a tap and comes back
///     round to the first. Nothing on the string says where a round ends,
///     because without a goal there is no round.
///
/// **Nothing animates.** The beads are painted where they are on the frame the
/// count changes, for the reason `VoussoirStripe` gives: a counter that eases
/// into position is a counter that is lying about where it is. The screen
/// swells the whole ring when a goal is reached, from outside it.
///
/// The ring is drawn at one size — [diameter] across, and [height] with the
/// tassel — and a screen with less room than that scales it down whole, so the
/// beads, the thread and the number inside stay in proportion. [child] sits in
/// the middle of the ring, laid out in a [hole] that clears the beads at any
/// count.
///
/// Excluded from semantics: the tasbih's tap target announces the round, and
/// a picture of the same number is not a second thing to read.
class BeadRing extends StatelessWidget {
  /// A goal's round: [lit] of [of] beads counted.
  ///
  /// [of] is at most [maxBeads]; a goal larger than that shares its taps out
  /// between them, which is the caller's arithmetic — see [maxBeads].
  const BeadRing.counted({
    super.key,
    required int this.lit,
    required int of,
    this.child,
  }) : beads = of,
       thumb = null,
       assert(of > 0 && of <= maxBeads, 'a ring has 1 to $maxBeads beads'),
       assert(lit >= 0 && lit <= of, 'lit is a position in 0..of');

  /// No goal: [looseBeads] beads, with the one under the thumb lit.
  ///
  /// [count] is the tasbih's count. At zero nothing is lit — nothing has been
  /// counted — and from the first tap the lit bead is the one that tap moved.
  const BeadRing.loose({super.key, required int count, this.child})
    : beads = looseBeads,
      lit = null,
      thumb = count == 0 ? null : (count - 1) % looseBeads,
      assert(count >= 0, 'a count is never negative');

  /// The most beads a ring holds: a hundred, so that the goal of a hundred —
  /// the adhkar the hadith count in hundreds — is one bead a tap, the same as
  /// thirty-three is.
  ///
  /// Past it a bead stands for a share of the round, quantised down, so a
  /// goal of a thousand lights a bead every tenth tap and the last one lights
  /// on the goal and not a tap before it. The number in the middle moves on
  /// every tap whatever the beads are doing. A hundred is also about as many
  /// as the ring can hold and still read as beads rather than as a dotted
  /// line.
  static const int maxBeads = 100;

  /// The beads on a string with no goal: thirty-three, the tasbih said after
  /// prayer, which is the string most hands know.
  static const int looseBeads = 33;

  /// Across the ring, and the width of the whole drawing.
  static const double diameter = 320;

  /// From the middle of the ring to the middle of a bead: the thread.
  static const double radius = 136;

  /// The tassel hangs this far below the ring's square.
  static const double tasselLength = 52;

  /// The whole drawing, tassel and all.
  static const double height = diameter + tasselLength;

  /// The middle of the ring, as an alignment within [height]: where the screen
  /// centres the swell, so the ring grows about itself rather than about a
  /// point between it and its tassel.
  static const Alignment centre = Alignment(0, diameter / height - 1);

  /// Where [child] is laid out: the largest box that sits inside the ring
  /// with room to spare round the biggest beads. A child larger than this is
  /// the caller's to scale down.
  static const Size hole = Size(200, 120);

  /// The largest a bead gets. With thirty-three on the string they are a
  /// little under this; with fewer they stop here, so that a goal of three is
  /// three beads and not three plates.
  static const double maxBeadSize = 22;

  /// How much of the circle the marker bead takes, in degrees. The beads are
  /// spaced round the rest.
  static const double markerGap = 20;

  /// How many beads are on the string.
  final int beads;

  /// How many beads are counted, with a goal. Null on a loose string.
  final int? lit;

  /// Which bead is under the thumb, on a loose string, counting from the
  /// first after the marker. Null with a goal, and at zero.
  final int? thumb;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int? lit = this.lit;
    return SizedBox(
      width: diameter,
      height: height,
      child: CustomPaint(
        painter: _BeadRingPainter(
          filled: scheme.primary,
          unfilled: scheme.surfaceContainerHighest,
          thread: scheme.outline,
          gold: scheme.tertiary,
          paleGold: scheme.tertiaryContainer,
          beads: beads,
          lit: lit,
          thumb: thumb,
          marker: switch (lit) {
            null => _Marker.loose,
            final int lit when lit == beads => _Marker.reached,
            _ => _Marker.goal,
          },
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox.square(
            dimension: diameter,
            child: Center(
              child: SizedBox.fromSize(
                size: hole,
                child: ExcludeSemantics(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the marker bead says: nothing, with no goal; that there is one; that
/// it has been reached.
enum _Marker { loose, goal, reached }

class _BeadRingPainter extends CustomPainter {
  const _BeadRingPainter({
    required this.filled,
    required this.unfilled,
    required this.thread,
    required this.gold,
    required this.paleGold,
    required this.beads,
    required this.lit,
    required this.thumb,
    required this.marker,
  });

  /// The share of a bead's slot that is bead, so neighbours never touch.
  static const double _beadFill = 0.8;

  static const double _threadWidth = 1.5;
  static const double _rimWidth = 1;

  /// The marker bead: long, and on end, the way it hangs.
  static const Size _markerSize = Size(16, 26);
  static const double _markerRim = 1.5;

  static const double _cordWidth = 2;
  static const double _cordLength = 12;
  static const double _knotRadius = 5;

  /// The tassel: a fan of strands, narrow under the knot and wide at the end.
  static const double _tasselTop = 9;
  static const double _tasselBottom = 32;
  static const double _tasselLength = 40;
  static const double _strandWidth = 1.5;
  static const double _strandPitch = 3;

  final Color filled;
  final Color unfilled;
  final Color thread;
  final Color gold;
  final Color paleGold;
  final int beads;
  final int? lit;
  final int? thumb;
  final _Marker marker;

  @override
  void paint(Canvas canvas, Size size) {
    const Offset centre = Offset(BeadRing.diameter / 2, BeadRing.diameter / 2);
    const double radius = BeadRing.radius;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _threadWidth
        ..color = thread,
    );

    // Each bead gets an equal slot of what the marker leaves, and sits in the
    // middle of it. Angles run clockwise from the top, so the first slot
    // starts just past the marker at the bottom.
    final double slot = (2 * math.pi - _radians(BeadRing.markerGap)) / beads;
    final double bead = math.min(
      BeadRing.maxBeadSize,
      radius * slot * _beadFill,
    );
    final double start = math.pi + _radians(BeadRing.markerGap) / 2;
    final Paint fill = Paint()..style = PaintingStyle.fill;
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _rimWidth
      ..color = thread;

    for (int i = 0; i < beads; i++) {
      final double angle = start + slot * (i + 0.5);
      final Offset at =
          centre + Offset(radius * math.sin(angle), -radius * math.cos(angle));
      final bool counted = switch (lit) {
        final int lit => i < lit,
        null => i == thumb,
      };
      canvas.drawCircle(
        at,
        bead / 2,
        fill..color = counted ? filled : unfilled,
      );
      // Inside the bead's own edge, so a ringed bead is no bigger than a
      // counted one beside it.
      if (!counted) canvas.drawCircle(at, (bead - _rimWidth) / 2, rim);
    }

    // The marker bead, over the thread where the string closes.
    final Offset markerAt = centre + const Offset(0, radius);
    final RRect markerBead = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: markerAt,
        width: _markerSize.width,
        height: _markerSize.height,
      ),
      Radius.circular(_markerSize.width / 2),
    );
    final (Color markerFill, Color markerRim) = switch (marker) {
      _Marker.loose => (unfilled, thread),
      _Marker.goal => (paleGold, gold),
      _Marker.reached => (gold, gold),
    };
    canvas.drawRRect(markerBead, fill..color = markerFill);
    canvas.drawRRect(
      markerBead.deflate(_markerRim / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _markerRim
        ..color = markerRim,
    );

    // The tassel: a cord, a knot, and the strands fanning out under it.
    final Paint goldFill = Paint()..color = gold;
    final double cordTop = markerAt.dy + _markerSize.height / 2;
    canvas.drawRect(
      Rect.fromLTWH(
        centre.dx - _cordWidth / 2,
        cordTop,
        _cordWidth,
        _cordLength,
      ),
      goldFill,
    );
    final double knotY = cordTop + _cordLength + _knotRadius - 1;
    canvas.drawCircle(Offset(centre.dx, knotY), _knotRadius, goldFill);

    final double tasselY = knotY + _knotRadius - 1;
    final Path fan = Path()
      ..moveTo(centre.dx - _tasselTop / 2, tasselY)
      ..lineTo(centre.dx + _tasselTop / 2, tasselY)
      ..lineTo(centre.dx + _tasselBottom / 2, tasselY + _tasselLength)
      ..lineTo(centre.dx - _tasselBottom / 2, tasselY + _tasselLength)
      ..close();
    canvas.save();
    canvas.clipPath(fan);
    for (
      double x = centre.dx - _tasselBottom / 2;
      x < centre.dx + _tasselBottom / 2;
      x += _strandPitch
    ) {
      canvas.drawRect(
        Rect.fromLTWH(x, tasselY, _strandWidth, _tasselLength),
        goldFill,
      );
    }
    canvas.restore();
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(_BeadRingPainter oldDelegate) {
    return oldDelegate.filled != filled ||
        oldDelegate.unfilled != unfilled ||
        oldDelegate.thread != thread ||
        oldDelegate.gold != gold ||
        oldDelegate.paleGold != paleGold ||
        oldDelegate.beads != beads ||
        oldDelegate.lit != lit ||
        oldDelegate.thumb != thumb ||
        oldDelegate.marker != marker;
  }
}
