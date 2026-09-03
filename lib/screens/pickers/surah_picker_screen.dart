import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collections/picked_item.dart';
import '../../domain/content.dart';
import '../../domain/content_ref.dart';
import '../../providers/reading.dart';
import '../../widgets/collection_dialogs.dart';
import '../../widgets/failure_screen.dart';
import '../../widgets/surah_row.dart';
import 'picker_scaffold.dart';

/// Pick a whole surah.
///
/// The same 114 rows as the mushaf's list, through the same [SurahRow], so
/// that finding Al-Mulk to add to a wird is the search you already know.
///
/// Pops with a one-item `List<PickedItem>`, or with nothing if backed out of.
class SurahPickerScreen extends ConsumerWidget {
  const SurahPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Surah>> surahs = ref.watch(surahsProvider);

    return PickerScaffold(
      title: 'Add a surah',
      body: switch (surahs) {
        AsyncError(:final Object error, :final StackTrace stackTrace) =>
          FailureScreen(
            title: 'Could not read the surah list',
            error: error,
            stackTrace: stackTrace,
          ),
        AsyncData(:final List<Surah> value) => ListView.builder(
          itemCount: value.length,
          itemBuilder: (BuildContext context, int index) => SurahRow(
            surah: value[index],
            onTap: () => _pick(context, value[index]),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _pick(BuildContext context, Surah surah) async {
    final ItemOptions? options = await showItemOptions(
      context,
      title: surah.nameTransliterated,
      subtitle:
          'Surah ${surah.number} · ${surah.ayahCount} '
          '${surah.ayahCount == 1 ? 'ayah' : 'ayahs'}',
      // A surah is read once unless told otherwise. Its ayahs are not
      // expanded here and are not counted here either.
      naturalCount: 1,
    );
    if (options == null || !context.mounted) return;
    Navigator.pop(context, <PickedItem>[
      PickedItem(
        ref: ContentRef.surah(surah.number),
        count: options.count,
        note: options.note,
      ),
    ]);
  }
}
