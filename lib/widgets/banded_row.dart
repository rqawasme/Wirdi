import 'package:flutter/material.dart';

/// One row of a list you are picking from, on an alternating background.
///
/// A single tonal step — [ColorScheme.surface] under the even rows,
/// [ColorScheme.surfaceContainerLow] under the odd ones — and nothing else. A
/// long list of Arabic and translation has no natural boundary between one row
/// and the next, and two lines of text running into two more is the complaint
/// this answers.
///
/// **Not the voussoir motif**, and not called a stripe, because
/// `VoussoirStripe` is that and this is not. Brick and stone alternating across
/// a row is how this app draws *data*: the week strip on a home card lets the
/// days decide where the joints fall, and the progress stripe lets the count
/// decide. Spending that pattern on "these are different rows" would spend the
/// app's one figurative device on something a shade of the surface already
/// says — and the precedent is in the README, where a voussoir arch watermark
/// behind the home tile was drawn, looked at, and taken off again for being
/// ornament that carried nothing. What carries over is the rhythm; the accent
/// colour stays where it is earning its keep.
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
      color: index.isEven ? scheme.surface : scheme.surfaceContainerLow,
      child: child,
    );
  }
}
