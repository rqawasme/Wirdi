import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/content.dart';
import '../domain/repositories.dart';
import '../providers/data_providers.dart';

/// One passage of Quran, chosen because it is hard to render.
@immutable
final class QuranSample {
  const QuranSample({
    required this.surah,
    required this.from,
    required this.tests,
    int? to,
  }) : to = to ?? from;

  final int surah;
  final int from;
  final int to;

  /// What this passage is here to expose.
  final String tests;

  String get reference => from == to ? '$surah:$from' : '$surah:$from-$to';
}

/// The known-hard cases for Uthmani rendering.
///
/// Not a sample of the mushaf — a list of the specific places where a font,
/// a shaper or a line height gives itself away. Between them they cover
/// elongation, the three special vocalisation signs, waqf marks in sequence,
/// the sajdah mark, and one ordinary short surah to see what all of that looks
/// like when nothing unusual is happening.
const List<QuranSample> quranSamples = <QuranSample>[
  QuranSample(surah: 2, from: 1, tests: 'Alif Lam Mim, elongation'),
  QuranSample(surah: 2, from: 255, tests: 'Ayat al-Kursi — long, dense marks'),
  QuranSample(surah: 11, from: 41, tests: 'imala'),
  QuranSample(surah: 12, from: 11, tests: 'ishmam'),
  QuranSample(surah: 7, from: 69, tests: 'saad with small seen'),
  QuranSample(surah: 68, from: 51, tests: 'saad-seen variant'),
  QuranSample(surah: 2, from: 245, tests: 'saad-seen variant'),
  QuranSample(surah: 18, from: 1, to: 2, tests: 'waqf marks in sequence'),
  QuranSample(surah: 7, from: 206, tests: 'sajdah mark'),
  QuranSample(surah: 30, from: 54, tests: 'multiple marks, weak letters'),
  QuranSample(surah: 1, from: 1, to: 7, tests: 'full short surah — baseline'),
];

/// The collection the dhikr samples come from.
///
/// Fetched rather than hard-coded so that the Arabic title is the one in
/// `content.db`, and so the dev screen exercises [WirdiTypography.arabicChrome]
/// — the only style in the scale that nothing else in the app reaches yet.
final FutureProvider<CollectionSummary?> dhikrCollectionProvider =
    FutureProvider<CollectionSummary?>((Ref ref) async {
      final List<CollectionSummary> all = await ref
          .watch(collectionRepositoryProvider)
          .all();
      for (final CollectionSummary summary in all) {
        if (summary.id == const BuiltinCollectionId(dhikrCollectionId)) {
          return summary;
        }
      }
      return null;
    }, name: 'dhikrCollection');

/// The Wird of Imam al-Nawawi, which the adhkar below belong to.
const int dhikrCollectionId = 2;

/// Adhkar chosen for length, from the Wird of Imam al-Nawawi.
///
/// The Quran samples exercise Amiri Quran and Noto Naskh against voweled
/// Uthmani text. These exercise the dhikr styles — a different face size, a
/// different line length, and a transliteration line under each — against the
/// only real adhkar in the database.
const List<DhikrSample> dhikrSamples = <DhikrSample>[
  DhikrSample(id: 2014, tests: 'three words, shortest in the wird'),
  DhikrSample(id: 2001, tests: 'one line'),
  DhikrSample(id: 2011, tests: 'wraps to two or three, repeated 3x'),
  DhikrSample(id: 2025, tests: 'long, many clauses'),
  DhikrSample(id: 2039, tests: 'compound, ends with the salawat'),
];

/// One dhikr, and what rendering it is meant to expose.
@immutable
final class DhikrSample {
  const DhikrSample({required this.id, required this.tests});

  final int id;
  final String tests;
}

/// [dhikrSamples], resolved against the real database.
final FutureProvider<List<Dhikr>> dhikrSamplesProvider =
    FutureProvider<List<Dhikr>>((Ref ref) async {
      final ContentRepository content = ref.watch(contentRepositoryProvider);
      return Future.wait(
        dhikrSamples.map((DhikrSample s) => content.dhikr(s.id)),
      );
    }, name: 'dhikrSamples');

/// A sample with its ayahs read out of `content.db`.
@immutable
final class ResolvedSample {
  const ResolvedSample({required this.sample, required this.ayahs});

  final QuranSample sample;
  final List<Ayah> ayahs;
}

/// [quranSamples], resolved against the real database.
///
/// Real rows, not literals. Rendering hand-typed Arabic would test the font
/// against text this repository is not allowed to author, and — more to the
/// point — would not test what actually ships: the exact codepoint sequence
/// the content pipeline puts in `ayahs.text_uthmani`, trailing ayah number and
/// all.
final FutureProvider<List<ResolvedSample>> quranSamplesProvider =
    FutureProvider<List<ResolvedSample>>((Ref ref) async {
      final ContentRepository content = ref.watch(contentRepositoryProvider);
      final List<ResolvedSample> resolved = <ResolvedSample>[];
      for (final QuranSample sample in quranSamples) {
        resolved.add(
          ResolvedSample(
            sample: sample,
            ayahs: await content.ayahRange(
              sample.surah,
              sample.from,
              sample.to,
            ),
          ),
        );
      }
      return resolved;
    }, name: 'quranSamples');
