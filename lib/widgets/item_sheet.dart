import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/item_labels.dart';
import '../domain/collection.dart';
import '../domain/content.dart';
import '../providers/reading.dart';
import '../theme/theme.dart';
import 'ayah_block.dart';
import 'dhikr_block.dart';
import 'plate.dart';

/// One item of a collection, in full: the Arabic, the translation, and what the
/// collection says about it.
///
/// What the contents screen opens when a row is tapped. A sheet and not a
/// dialog: this is reading — Arabic set at two-line leading in a reading column
/// — and a dialog is a box for a question. The height is capped rather than
/// free so that a 286-ayah surah cannot push it off the top of the screen.
Future<void> showItemSheet(
  BuildContext context, {
  required CollectionItemEntry item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => _ItemSheet(item: item),
  );
}

class _ItemSheet extends ConsumerWidget {
  const _ItemSheet({required this.item});

  /// The most of the screen the sheet may take. Short of the whole height, so
  /// the room behind it stays visible and the sheet reads as something over the
  /// list rather than as a screen that was pushed.
  static const double _maxHeightFraction = 0.85;

  final CollectionItemEntry item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (String title, String? kind) = itemHeading(
      item,
      surahName: (int number) => _surahName(ref, number),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * _maxHeightFraction,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Heading(title: title, kind: kind, count: item.count),
            Flexible(child: _Body(item: item)),
          ],
        ),
      ),
    );
  }
}

/// The transliterated surah name, for an ayah that names its surah.
///
/// Already loaded for the surah list, and only wanted for the name — so this
/// reads what is there rather than asking for a row of its own. The number is
/// the fallback: a name is nicer than "Surah 2" and not worth a spinner.
String _surahName(WidgetRef ref, int number) {
  final Surah? surah = ref
      .watch(surahsProvider)
      .value
      ?.where((Surah s) => s.number == number)
      .firstOrNull;
  return surah?.nameTransliterated ?? 'Surah $number';
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.kind,
    required this.count,
  });

  final String title;
  final String? kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? kind = this.kind;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.readingColumnPadding,
        WirdiMetrics.space2,
        WirdiMetrics.readingColumnPadding,
        WirdiMetrics.space3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium),
                if (kind != null) ...<Widget>[
                  const SizedBox(height: WirdiMetrics.space1),
                  Text(
                    kind,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (count > 1) ...<Widget>[
            const SizedBox(width: WirdiMetrics.space3),
            Plate(label: '×$count'),
          ],
        ],
      ),
    );
  }
}

/// The item's text, in the shape its kind wants.
///
/// **The translation is always shown here**, whatever the show-translation
/// setting says. That setting is about the surface you recite from — somebody
/// reciting from memory wants the page uninterrupted — and this sheet exists to
/// work out *which item this is*. Hiding half the answer would defeat the
/// screen.
class _Body extends ConsumerWidget {
  const _Body({required this.item});

  final CollectionItemEntry item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (item) {
      DhikrItem(:final Dhikr dhikr, :final Source? source) => _Scroll(
        children: <Widget>[
          DhikrBlock(dhikr: dhikr),
          _Note(note: item.note),
          _SourceLine(source: source, written: dhikr.reference),
        ],
      ),
      AyahItem(:final Ayah ayah) => _Scroll(
        children: <Widget>[
          AyahBlock(ayah: ayah, surahName: _surahName(ref, ayah.surahNumber)),
          _Note(note: item.note),
        ],
      ),
      SurahItem(:final Surah surah) => _Surah(surah: surah, note: item.note),
    };
  }
}

/// A whole surah, its ayahs fetched on the way in.
///
/// A [SurahItem] resolves to surah metadata only — Al-Baqarah alone is 286
/// verses and a collection list has no use for the text — so this is where the
/// expansion the domain defers actually happens.
///
/// A [ListView.builder] and not a column in a scroll view, for the same 286
/// verses: a column would lay out every one of them the moment the sheet
/// opened, and the sheet would hang instead of appearing. The [ConstrainedBox]
/// above it is what bounds this list; without it, a list inside a column inside
/// a sheet has no height to build against and throws.
class _Surah extends ConsumerWidget {
  const _Surah({required this.surah, required this.note});

  final Surah surah;
  final String? note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SurahReading> reading = ref.watch(
      surahReadingProvider(surah.number),
    );

    return switch (reading) {
      AsyncError() => const _Unreadable(),
      AsyncData(:final SurahReading value) => _list(value),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _list(SurahReading reading) {
    final String? bismillah = reading.bismillah;
    final bool hasHeading = reading.hasBismillahHeading;
    // The basmala when there is one, then the ayahs, then the note.
    final int count = (hasHeading ? 1 : 0) + reading.ayahs.length + 1;

    return ListView.builder(
      padding: WirdiMetrics.readingColumn,
      itemCount: count,
      itemBuilder: (BuildContext context, int index) {
        if (hasHeading && index == 0) {
          return BismillahHeading(text: bismillah!);
        }
        final int ayahIndex = hasHeading ? index - 1 : index;
        if (ayahIndex >= reading.ayahs.length) {
          return _Note(note: note);
        }
        return AyahBlock(
          ayah: reading.ayahs[ayahIndex],
          surahName: surah.nameTransliterated,
        );
      },
    );
  }
}

/// One item's worth of text, scrolled as a piece.
class _Scroll extends StatelessWidget {
  const _Scroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.readingColumnPadding,
        0,
        WirdiMetrics.readingColumnPadding,
        WirdiMetrics.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// What the sheet says when the surah's verses could not be read.
///
/// A line inside the sheet rather than a `FailureScreen`, which is a whole
/// [Scaffold] and has nowhere to stand in here.
class _Unreadable extends StatelessWidget {
  const _Unreadable();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: WirdiMetrics.readingColumn,
      child: Text(
        'The verses of this surah could not be read.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The per-collection rubric on an item: what this wird says about reciting
/// this one, as its author wrote it.
class _Note extends StatelessWidget {
  const _Note({required this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    final String? note = this.note;
    if (note == null || note.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: WirdiMetrics.space4),
      child: Container(
        padding: const EdgeInsets.all(WirdiMetrics.space3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: WirdiMetrics.card,
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: WirdiMetrics.hairline,
          ),
        ),
        child: Text(note, style: theme.textTheme.bodySmall),
      ),
    );
  }
}

/// Where a dhikr comes from. Always shown when there is one: sourcing is a
/// trust feature, and a reference you have to go looking for is a reference
/// nobody reads.
///
/// Two kinds, and they are not interchangeable. [source] is a `sources` row of
/// the content build, which carries a grading — a claim the pipeline stands
/// behind. [written] is what somebody typed about their own copy, and it is
/// marked as theirs so that a line in this position is never read as a grading
/// nobody gave. A dhikr has one or the other, never both.
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.source, this.written});

  final Source? source;

  /// [Dhikr.reference]: free text, and the user's own.
  final String? written;

  @override
  Widget build(BuildContext context) {
    final Source? source = this.source;
    final String? written = this.written;
    if (source == null && written == null) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final String line;
    if (source != null) {
      final String grading = source.grading == null
          ? ''
          : ' · ${source.grading}';
      line = '${source.collection} ${source.reference}$grading';
    } else {
      line = 'Your note on where it is from: $written';
    }

    return Padding(
      padding: const EdgeInsets.only(top: WirdiMetrics.space4),
      child: Text(
        line,
        style: type.dhikrCaption.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
