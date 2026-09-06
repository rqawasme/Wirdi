import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'voussoir_stripe.dart';

/// The voussoir motif, bent: a horseshoe arch drawn as a ring of discrete
/// wedges, alternating the way [VoussoirStripe] alternates along a line.
///
/// This is the same masonry the rest of the app is built from, in the one
/// posture the Mezquita is actually known for. **Nothing here is curved.**
/// Each voussoir is four straight edges — two radial, two chords — so the
/// arch is a polygon approximation and not a stroked arc, and the app's shape
/// language (squared, no stadiums, no ornament that could not be built out of
/// blocks) survives it. The curve is in the arrangement, not in any one piece.
///
/// The ring is continuous and one colour, and what makes it masonry is the
/// mortar: a joint of about a device pixel is taken out of each end of every
/// block, so the arch reads as courses butting against each other rather than
/// as a stroked line. Two things this is deliberately not. It is not the
/// stripe's two-tone alternation — [ColorScheme.outlineVariant] and
/// [ColorScheme.surfaceContainerHigh] are the same colour byte-for-byte in
/// dark, so an alternating arch would have a rhythm in one theme and none in
/// the other. And it is not every-other-block-omitted, which was the first
/// draft: at this contrast the eye cannot join eight fragments into an arch,
/// and a card ends up with confetti on it.
///
/// It is a watermark and nothing else: it carries no value, states nothing,
/// and is excluded from semantics. That is a deliberate exception to the rule
/// that this app does not decorate — see the note in `EmptyState` — and it
/// earns it by being the quietest thing on the surface it sits on:
/// `outlineVariant` is the faintest role in the scheme, and it is already
/// what the card draws its own border in.
///
/// It takes no notion of whether the card is finished. A finished card steps
/// its ground up to `surfaceContainerHigh`, which is most of the way to the
/// blocks in light and exactly equal to them in dark — so the arch fades on
/// a finished card, and vanishes in dark, by arithmetic rather than by a
/// special case.
///
/// Horseshoe, not semicircular: the arc sweeps past its own springing line by
/// [horseshoeSweep] before the legs drop, which is the whole visual signature
/// of the Cordoban arch. A semicircle reads as a tunnel.
class VoussoirArch extends StatelessWidget {
  const VoussoirArch({super.key, this.voussoirs = defaultVoussoirs});

  /// Blocks around the ring. Odd, so the arch has a keystone at its apex
  /// rather than a joint sitting on the centre line.
  static const int defaultVoussoirs = 13;

  /// How far past the horizontal the arc continues before the legs run
  /// straight down, as a fraction of a right angle. A true Cordoban horseshoe
  /// is about a third of the way past.
  static const double horseshoeSweep = 0.32;

  /// The ring's thickness, as a fraction of its outer radius.
  static const double thickness = 0.16;

  /// The outer radius, as a fraction of the width it is given. Under a half,
  /// so the widest point of the arch clears the card's side edges instead of
  /// being cut by them — an arch cut off at both haunches reads as a mistake,
  /// where an arch whose legs run off the bottom reads as a wall continuing.
  static const double span = 0.44;

  /// How much of [ColorScheme.outlineVariant] the blocks are painted in.
  ///
  /// The faintest role in the scheme is still a border colour, and a border is
  /// meant to be found. This is behind the text, so it is taken down again —
  /// far enough that the week strip in front of it reads cleanly, close enough
  /// that the arch is there when you look for it.
  static const double opacity = 0.45;

  /// The mortar line between one block and the next, in logical pixels of arc
  /// at the outer edge. A hairline's worth: enough to separate one course from
  /// the next, not enough to make the ring a dashed line.
  static const double jointWidth = 1;

  final int voussoirs;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _VoussoirArchPainter(
          block: scheme.outlineVariant.withValues(alpha: opacity),
          voussoirs: voussoirs,
        ),
      ),
    );
  }
}

class _VoussoirArchPainter extends CustomPainter {
  const _VoussoirArchPainter({required this.block, required this.voussoirs});

  final Color block;
  final int voussoirs;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || voussoirs <= 0) return;

    // As wide as the box, and standing on its bottom edge.
    final double outer = size.width * VoussoirArch.span;
    final double inner = outer * (1 - VoussoirArch.thickness);

    // Measured from the horizontal, anticlockwise: the arc starts below the
    // springing line on the right, passes through the apex, and ends the same
    // distance below it on the left.
    const double overshoot = VoussoirArch.horseshoeSweep * math.pi / 2;
    const double start = -overshoot;
    const double sweep = math.pi + 2 * overshoot;

    // The centre sits *above* the bottom edge by however far the ends fall
    // below it, so that the ends land on the edge and the horseshoe's own
    // signature — the arc narrowing again below its widest point — is on the
    // card. With the centre on the edge instead, everything below the widest
    // point is off it and the arch reads as a plain dome.
    final Offset centre = Offset(
      size.width / 2,
      size.height - outer * math.sin(overshoot),
    );
    final double step = sweep / voussoirs;
    // The joint as an angle: a fixed width of arc, so it stays a mortar line
    // at whatever size the card gives this rather than widening with the arch.
    final double joint = VoussoirArch.jointWidth / outer;

    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = block;

    for (int i = 0; i < voussoirs; i++) {
      // The joint is taken out of both ends of every block, so the blocks stay
      // equal and the rhythm does not drift around the ring.
      final double from = start + i * step + joint / 2;
      final double to = start + (i + 1) * step - joint / 2;
      if (to <= from) continue;

      canvas.drawPath(_voussoir(centre, inner, outer, from, to), paint);
    }
  }

  /// One block: out along the [from] radius, round to [to] as a chord, back
  /// down, and closed. Four straight edges, no arc.
  Path _voussoir(
    Offset centre,
    double inner,
    double outer,
    double from,
    double to,
  ) {
    Offset at(double radius, double angle) => Offset(
      centre.dx + radius * math.cos(angle),
      // Screen y grows downward and the angles are read the way they are
      // written on paper, so the sine is subtracted rather than added.
      centre.dy - radius * math.sin(angle),
    );

    return Path()
      ..moveTo(at(inner, from).dx, at(inner, from).dy)
      ..lineTo(at(outer, from).dx, at(outer, from).dy)
      ..lineTo(at(outer, to).dx, at(outer, to).dy)
      ..lineTo(at(inner, to).dx, at(inner, to).dy)
      ..close();
  }

  @override
  bool shouldRepaint(_VoussoirArchPainter old) =>
      old.block != block || old.voussoirs != voussoirs;
}
