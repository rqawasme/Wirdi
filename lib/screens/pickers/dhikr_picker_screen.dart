import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collections/dhikr_search.dart';
import '../../collections/picked_item.dart';
import '../../domain/content.dart';
import '../../providers/editing.dart';
import '../../theme/theme.dart';
import '../../widgets/banded_row.dart';
import '../../widgets/collection_dialogs.dart';
import '../../widgets/dhikr_row.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/failure_screen.dart';
import '../../widgets/search_field.dart';
import 'picker_scaffold.dart';

/// Every dhikr in the content build, with a search over it.
///
/// Four hundred and ninety-six rows. The argument against this screen used to
/// be that a flat list of them had nothing to sort or filter it by, which was
/// true and is what the search field answers. The other picker — the one that
/// browses by the wird a dhikr comes from — stays, because knowing the wird and
/// not the words is a real way to arrive.
///
/// Arabic matches diacritic-insensitively: nobody types the harakat and the
/// text carries all of them, so a search that required them would find nothing
/// every time. See `ArabicText.simplify`.
///
/// Pops with a one-item `List<PickedItem>`.
class DhikrPickerScreen extends ConsumerStatefulWidget {
  const DhikrPickerScreen({super.key});

  @override
  ConsumerState<DhikrPickerScreen> createState() => _DhikrPickerScreenState();
}

class _DhikrPickerScreenState extends ConsumerState<DhikrPickerScreen> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _query
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  /// No debounce. The filter is a `contains` over strings that were folded when
  /// the list was read and have been in memory ever since — no query, no I/O,
  /// nothing to coalesce. A debounce would put latency in front of a
  /// synchronous operation and make the list lag the keyboard, which is the
  /// complaint debouncing exists to fix elsewhere. It becomes worth adding the
  /// day the match reaches the database, and not before.
  void _onQueryChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SearchableDhikr>> adhkar = ref.watch(
      searchableAdhkarProvider,
    );

    return PickerScaffold(
      title: 'Add a dhikr',
      // No autofocus. With the Arabic visible this list is a browse as much as
      // a search, and a keyboard covering two thirds of it before anybody asked
      // to type is the screen deciding for them.
      header: Padding(
        padding: const EdgeInsets.fromLTRB(
          WirdiMetrics.space4,
          WirdiMetrics.space3,
          WirdiMetrics.space4,
          WirdiMetrics.space3,
        ),
        child: SearchField(
          controller: _query,
          hintText: 'Search the Arabic or the translation',
        ),
      ),
      body: switch (adhkar) {
        AsyncError(:final Object error, :final StackTrace stackTrace) =>
          FailureScreen(
            title: 'Could not read the adhkar',
            error: error,
            stackTrace: stackTrace,
          ),
        AsyncData(:final List<SearchableDhikr> value) => _list(value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _list(List<SearchableDhikr> all) {
    final List<Dhikr> matches = searchAdhkar(all, _query.text);

    if (matches.isEmpty) {
      return const EmptyState(
        title: 'Nothing matches that',
        body:
            'The search looks at the Arabic and at the translation. '
            'Diacritics are ignored, so the bare letters are enough.',
      );
    }

    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (BuildContext context, int index) => BandedRow(
        index: index,
        child: DhikrRow(
          dhikr: matches[index],
          onTap: () => _pick(matches[index]),
        ),
      ),
    );
  }

  Future<void> _pick(Dhikr dhikr) async {
    final PickedItem? picked = await askDhikrOptions(context, dhikr);
    if (picked == null || !mounted) return;
    Navigator.pop(context, <PickedItem>[picked]);
  }
}
