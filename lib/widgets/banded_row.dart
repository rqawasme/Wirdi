import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// One row of a list you are picking from, on an alternating background.
///
/// Even rows sit on [ColorScheme.surface]; odd rows sit on a course of the same
/// surface with a breath of brick washed into it — see [WirdiColorSchemes.band].
/// A long list of Arabic and translation has no natural boundary between one
/// row and the next, and two lines of text running into two more is the
/// complaint this answers.
///
/// **It was a rung of the neutral ladder first**, `surfaceContainerLow` under
/// the odd rows, on the argument that brick is how this app draws *data* and
/// should not be spent on saying "these are different rows". That was decided
/// before looking at it on a device, where the light rung turned out to be
/// fourteen points out of two hundred and fifty-five and the list still ran
/// together. The course is clay now.
///
/// What the original argument got right, and what still holds: the week strip
/// and the progress stripe use brick at **full** strength, and in both of them
/// something decides where the joints fall — the days in one, the count in the
/// other. This is a wash at eight percent, decided by nothing but whether a row
/// is odd, and it sits behind text rather than standing for anything. Brick and
/// stone alternating is the Mezquita's own pattern; used this faintly it is the
/// rhythm of it and not a second progress bar.
///
/// The watermark precedent in the README still applies, and is the thing to
/// measure this against: what killed the voussoir arch behind the home tile was
/// that it carried nothing *and looked like it*. A ground a shade off the page
/// does not have that problem — the moment it does, it is too loud, and
/// [WirdiColorSchemes.lightBandTint] is the dial.
///
/// **Applied per list, not inside the row.** `SurahRow` is shared between the
/// surah picker and the mushaf's reading list. A picker is a list you are
/// scanning for one row out of a hundred and fourteen; the mushaf list is a
/// table of contents you already know your way down, and a banded ground under
/// Quran headings is the ornament again. The picker bands and the mushaf does
/// not, and a band built into the row could not tell them apart.
///
/// Band on the row's *displayed* index, so the top of a filtered list keeps the
/// same shade as the filter narrows it.
class BandedRow extends StatelessWidget {
  const BandedRow({super.key, required this.index, required this.child});

  /// Where this row sits in the list as drawn, from zero.
  final int index;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // A Material and not a ColoredBox: every one of these rows is an InkWell,
    // and a splash paints onto the nearest enclosing Material. Without one here
    // the ripple would land on the surface beneath the band and disappear under
    // it. The collection editor's rows are wrapped for the same reason.
    //
    // No Semantics of any kind. The shade says which row is which to somebody
    // looking at the list; it is not information, and a screen reader announcing
    // it would be announcing the furniture.
    return Material(
      color: index.isEven ? scheme.surface : WirdiColorSchemes.band(scheme),
      child: child,
    );
  }
}
