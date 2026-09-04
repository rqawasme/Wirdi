import 'package:flutter/material.dart';

import '../providers/collections.dart';
import '../theme/theme.dart';

/// One collection, as a row in a list about *managing* collections.
///
/// This is the form the collections list and the dhikr list use. Its opposite
/// number is `CollectionTile`, the square form on the home screen: a tile is
/// for doing today's wird and says how far through it you are, a row is for
/// finding, copying, editing and deleting a collection and says what is in it.
/// Neither substitutes for the other.
///
/// The completed-today mark is deliberately quiet — a small check in
/// [ColorScheme.onSurfaceVariant], on the same line as the item count and in
/// the same colour as it. Finishing a daily wird is the expected outcome, not
/// an achievement, and a row that congratulates you every evening stops
/// meaning anything by the third day.
class CollectionRow extends StatelessWidget {
  const CollectionRow({
    super.key,
    required this.listing,
    required this.onTap,
    this.trailing,
  });

  /// The most of a row the Arabic name may take before it starts wrapping.
  static const double arabicShare = 0.45;

  final CollectionListing listing;

  final VoidCallback onTap;

  /// What sits at the trailing edge, outside the row's own semantics: the
  /// overflow menu in the collections list, and nothing at all in a list that
  /// offers no actions.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    final String? nameArabic = listing.summary.nameArabic;
    final Widget? trailing = this.trailing;

    final String items =
        '${listing.itemCount} ${listing.itemCount == 1 ? 'item' : 'items'}';
    final String state = listing.completedToday
        ? 'done today'
        : listing.inProgress
        ? 'part-way through'
        : 'not started today';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Semantics(
            container: true,
            button: true,
            label: '${listing.name}, $items, $state',
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  WirdiMetrics.space4,
                  WirdiMetrics.space4,
                  trailing == null ? WirdiMetrics.space4 : 0,
                  WirdiMetrics.space4,
                ),
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      LayoutBuilder(
                        builder:
                            (
                              BuildContext context,
                              BoxConstraints constraints,
                            ) => Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    listing.name,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                if (nameArabic != null) ...<Widget>[
                                  const SizedBox(width: WirdiMetrics.space4),
                                  // Capped rather than given a flex share: an
                                  // Arabic name that needs a third of the row
                                  // should not take half of it and wrap the
                                  // English name that would otherwise have
                                  // fitted.
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          constraints.maxWidth * arabicShare,
                                    ),
                                    child: Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: Text(
                                        nameArabic,
                                        style: type.arabicTitle,
                                        locale: const Locale('ar'),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                      ),
                      const SizedBox(height: WirdiMetrics.space2),
                      // On its own line under both names, so it has the width
                      // to say what it has to say however long the collection
                      // is called.
                      _Meta(listing: listing, items: items, colour: quiet),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Outside the row's own semantics rather than inside it: a menu that
        // opens the only way to copy a built-in should not be something a
        // screen reader has to find inside a button.
        ?trailing,
      ],
    );
  }
}

/// The item count, and what state the collection is in today.
class _Meta extends StatelessWidget {
  const _Meta({
    required this.listing,
    required this.items,
    required this.colour,
  });

  final CollectionListing listing;
  final String items;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colour);

    // One paragraph rather than a row of boxes: the check is an inline glyph
    // in the sentence, so a long name or a large accessibility text scale
    // wraps the line instead of overflowing it.
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: items),
          if (listing.completedToday) ...<InlineSpan>[
            const TextSpan(text: ' · '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                Icons.check,
                size: WirdiMetrics.space4,
                color: colour,
              ),
            ),
            const TextSpan(text: ' Done today'),
          ] else if (listing.inProgress)
            const TextSpan(text: ' · Part-way through'),
        ],
      ),
      style: style,
    );
  }
}
