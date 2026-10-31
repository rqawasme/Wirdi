import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';
import '../providers/adhkar.dart';
import '../providers/collections.dart';
import '../providers/home.dart';
import '../quran/arabic_text.dart';
import '../routes.dart';
import '../theme/theme.dart';
import '../widgets/banded_row.dart';
import '../widgets/collection_row.dart';
import '../widgets/collection_series_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/failure_screen.dart';
import '../widgets/search_field.dart';
import 'collection_actions.dart';

/// Every collection there is, on two shelves: the Library the app ships, and
/// Yours — the collections and the adhkar the user made.
///
/// This is the tab about what the app *contains*. Home is the tab about what
/// today contains, and it shows only what was committed from here.
///
/// It was three stacked lists — the user's collections, a row for the user's
/// adhkar, and the built-ins — with four icon buttons on every row. Now there
/// are two shelves behind a switch, and a row is one tap that opens its
/// collection; the collection page is where reciting, committing, copying and
/// editing are, with their names on them.
///
/// A body rather than a screen with its own [Scaffold]: the app bar and the
/// navigation bar belong to [AppShell], which swaps this body for another
/// without either of them moving.
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CollectionListing>> listings = ref.watch(
      collectionListingsProvider,
    );

    return switch (listings) {
      AsyncError(:final Object error, :final StackTrace stackTrace) =>
        FailureScreen(
          title: 'Could not read the collections',
          error: error,
          stackTrace: stackTrace,
        ),
      AsyncData(:final List<CollectionListing> value) => _Shelves(
        listings: value,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// The switch, and whichever shelf it is set to.
class _Shelves extends ConsumerStatefulWidget {
  const _Shelves({required this.listings});

  final List<CollectionListing> listings;

  @override
  ConsumerState<_Shelves> createState() => _ShelvesState();
}

class _ShelvesState extends ConsumerState<_Shelves> {
  final TextEditingController _search = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<CollectionListing> listings = widget.listings;
    final List<CollectionListing> mine = <CollectionListing>[
      for (final CollectionListing l in listings)
        if (!l.summary.isBuiltin) l,
    ];
    final List<CollectionListing> builtin = <CollectionListing>[
      for (final CollectionListing l in listings)
        if (l.summary.isBuiltin) l,
    ];
    final Map<CollectionId, Commitment> commitments =
        ref.watch(commitmentsProvider).value ??
        const <CollectionId, Commitment>{};

    // Until somebody picks, Yours once they have made something and the
    // Library before: what somebody made is what they come back for.
    final CollectionShelf shelf =
        ref.watch(collectionShelfProvider) ??
        (mine.isEmpty ? CollectionShelf.library : CollectionShelf.yours);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WirdiMetrics.space4,
            WirdiMetrics.space3,
            WirdiMetrics.space4,
            WirdiMetrics.space2,
          ),
          child: SegmentedButton<CollectionShelf>(
            segments: <ButtonSegment<CollectionShelf>>[
              for (final CollectionShelf s in CollectionShelf.values)
                ButtonSegment<CollectionShelf>(value: s, label: Text(s.label)),
            ],
            selected: <CollectionShelf>{shelf},
            showSelectedIcon: false,
            onSelectionChanged: (Set<CollectionShelf> chosen) => ref
                .read(collectionShelfProvider.notifier)
                .select(chosen.single),
          ),
        ),
        Expanded(
          child: switch (shelf) {
            CollectionShelf.library => _library(builtin, commitments),
            CollectionShelf.yours => _yours(mine, commitments),
          },
        ),
      ],
    );
  }

  Widget _library(
    List<CollectionListing> builtin,
    Map<CollectionId, Commitment> commitments,
  ) {
    final List<_Entry> entries = _filter(_group(builtin), _query);

    return ListView(
      // Its own key so each shelf keeps its own place: back to the Library
      // half way down is back half way down.
      key: const PageStorageKey<CollectionShelf>(CollectionShelf.library),
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WirdiMetrics.space4,
            WirdiMetrics.space2,
            WirdiMetrics.space4,
            WirdiMetrics.space3,
          ),
          child: SearchField(
            controller: _search,
            hintText: 'Search the library',
            onChanged: (String value) => setState(() => _query = value),
          ),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(WirdiMetrics.space4),
            child: Text(
              'Nothing in the library matches “${_query.trim()}”.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        // Banded as the pickers band theirs, on the displayed index, so the
        // top of a filtered list keeps the shade it had unfiltered.
        for (int i = 0; i < entries.length; i++)
          BandedRow(
            index: i,
            child: switch (entries[i]) {
              _Single(:final CollectionListing listing) => CollectionRow(
                listing: listing,
                commitment: commitments[listing.id],
                onTap: () => openCollection(context, ref, listing.id),
              ),
              _Series(
                :final CollectionSeries series,
                :final List<CollectionListing> parts,
              ) =>
                CollectionSeriesRow(
                  series: series,
                  parts: parts,
                  commitments: commitments,
                  onTap: () => openSeries(context, series.name),
                ),
            },
          ),
      ],
    );
  }

  Widget _yours(
    List<CollectionListing> mine,
    Map<CollectionId, Commitment> commitments,
  ) {
    return ListView(
      key: const PageStorageKey<CollectionShelf>(CollectionShelf.yours),
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
      children: <Widget>[
        const _GroupLabel('Collections'),
        if (mine.isEmpty)
          const _NoneOfYourOwn()
        else ...<Widget>[
          for (int i = 0; i < mine.length; i++)
            BandedRow(
              index: i,
              child: CollectionRow(
                listing: mine[i],
                commitment: commitments[mine[i].id],
                onTap: () => openCollection(context, ref, mine[i].id),
              ),
            ),
          _AddRow(
            label: 'New collection',
            onPressed: () => newCollection(context, ref),
          ),
        ],
        const _GroupLabel('Adhkar you wrote'),
        const _YourAdhkarRow(),
        _AddRow(
          label: 'Write a dhikr',
          // The form refreshes what a save touches on its own way out.
          onPressed: () => Navigator.pushNamed(context, Routes.dhikrEdit),
        ),
      ],
    );
  }
}

/// One line of the Library: a collection, or a series of them drawn as one.
sealed class _Entry {
  const _Entry();
}

final class _Single extends _Entry {
  const _Single(this.listing);

  final CollectionListing listing;
}

final class _Series extends _Entry {
  const _Series(this.series, this.parts);

  final CollectionSeries series;
  final List<CollectionListing> parts;
}

/// The built-ins in list order, with each series gathered into one entry at
/// the place its first part would have taken.
List<_Entry> _group(List<CollectionListing> builtin) {
  final Map<String, List<CollectionListing>> parts =
      <String, List<CollectionListing>>{};
  for (final CollectionListing l in builtin) {
    if (l.summary.series case final CollectionSeries series) {
      parts.putIfAbsent(series.name, () => <CollectionListing>[]).add(l);
    }
  }

  final Set<String> placed = <String>{};
  return <_Entry>[
    for (final CollectionListing l in builtin)
      if (l.summary.series case final CollectionSeries series) ...<_Entry>[
        if (placed.add(series.name)) _Series(series, parts[series.name]!),
      ] else
        _Single(l),
  ];
}

/// [entries] whose name, or Arabic name, holds [query].
///
/// A series is kept whole when its own name or any of its parts' does: a
/// search for "Tuesday" is a search for the series' Tuesday, and the row that
/// has it is the series.
List<_Entry> _filter(List<_Entry> entries, String query) {
  final String latin = query.trim().toLowerCase();
  if (latin.isEmpty) return entries;
  // A query of nothing but harakat folds to nothing, and every string
  // contains nothing; see `searchAdhkar` for the same guard.
  final String arabic = ArabicText.simplify(query.trim());

  bool matches(String name, String? nameArabic) =>
      name.toLowerCase().contains(latin) ||
      (arabic.isNotEmpty &&
          nameArabic != null &&
          ArabicText.simplify(nameArabic).contains(arabic));

  return <_Entry>[
    for (final _Entry entry in entries)
      if (switch (entry) {
        _Single(:final CollectionListing listing) => matches(
          listing.name,
          listing.summary.nameArabic,
        ),
        _Series(
          :final CollectionSeries series,
          :final List<CollectionListing> parts,
        ) =>
          matches(series.name, series.nameArabic) ||
              parts.any(
                (CollectionListing p) => matches(p.name, p.summary.nameArabic),
              ),
      })
        entry,
  ];
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space5,
        WirdiMetrics.space4,
        WirdiMetrics.space2,
      ),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: type.caption.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// "New collection", "Write a dhikr": the way to add one more to the group
/// above it, at the foot of the group, in words.
class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WirdiMetrics.space2),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: Text(label),
        ),
      ),
    );
  }
}

/// The way through to the adhkar the user wrote, saying how many there are.
///
/// One row rather than the adhkar themselves: writing, editing and deleting a
/// dhikr — and being told what a deletion takes out of which collection — is
/// the adhkar screen's, and a second copy of it here would be two places to
/// keep in step.
class _YourAdhkarRow extends ConsumerWidget {
  const _YourAdhkarRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final int? count = ref.watch(userAdhkarProvider).value?.length;

    return ListTile(
      leading: const Icon(Icons.edit_note_outlined),
      title: Text(switch (count) {
        null => 'Your adhkar',
        0 => 'None written yet',
        1 => '1 dhikr',
        final int n => '$n adhkar',
      }),
      subtitle: const Text('Your own duas, to put in your collections'),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: () => Navigator.pushNamed(context, Routes.adhkar),
    );
  }
}

/// What the Yours shelf says before the user has made a collection.
class _NoneOfYourOwn extends ConsumerWidget {
  const _NoneOfYourOwn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: WirdiMetrics.space4),
      child: EmptyState(
        title: 'Nothing of your own yet',
        // The second sentence is the path that matters, and it is the one
        // people reach for: al-Haddad's wird with two more adhkar in it.
        body:
            'Start an empty collection, or open one in the Library and make '
            'a copy to change.',
        action: FilledButton(
          onPressed: () => newCollection(context, ref),
          child: const Text('New collection'),
        ),
      ),
    );
  }
}
