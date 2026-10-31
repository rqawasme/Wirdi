import 'package:flutter/material.dart';

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';
import '../providers/collections.dart';
import 'collection_row.dart';

/// A work recited in parts, as one row in the Library: its name, how many
/// parts, and whether any of them is on Home.
///
/// Dala'il al-Khayrat is eleven collections, and as eleven rows it was half
/// the Library — the same name over and over, differing by a weekday in
/// brackets or the name of a supplication. As one row the name is said once,
/// and the row opens a page of the parts.
///
/// It is the same shape as every row around it, on purpose. It was a week
/// strip once, with today filled in brick and the supplications as lines
/// above and below it: a dozen things to tap in one row of a list where every
/// other row is one, and a calendar on the tab that is about what the app
/// contains rather than what today does.
class CollectionSeriesRow extends StatelessWidget {
  const CollectionSeriesRow({
    super.key,
    required this.series,
    required this.parts,
    required this.commitments,
    required this.onTap,
  });

  final CollectionSeries series;

  /// Every part, in list order.
  final List<CollectionListing> parts;

  /// Every commitment by collection; a part absent from it is not on Home.
  final Map<CollectionId, Commitment> commitments;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String count = '${parts.length} parts';
    // Which parts are on Home is the series page's to say, part by part; the
    // row only says that some are.
    final bool onHome = parts.any(
      (CollectionListing p) => commitments.containsKey(p.id),
    );

    return CollectionRowFrame(
      name: series.name,
      nameArabic: series.nameArabic,
      semanticLabel: <String>[
        series.name,
        count,
        if (onHome) 'On Home',
      ].join(', '),
      onTap: onTap,
      meta: CollectionMeta(
        items: count,
        completedToday: false,
        inProgress: false,
        home: onHome ? 'On Home' : null,
      ),
    );
  }
}

/// [name] without the series' name in front of it: "Part 1 (Monday)" out of
/// "Dala'il al-Khayrat — Part 1 (Monday)". The whole name when it does not
/// start with the series', which is still true, only longer.
String partName(CollectionSeries series, String name) {
  if (!name.startsWith(series.name)) return name;
  final String rest = name
      .substring(series.name.length)
      .replaceFirst(RegExp(r'^[\s—–:-]+'), '');
  return rest.isEmpty ? name : rest;
}
