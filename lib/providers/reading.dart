import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Family provider types live in misc.dart rather than the main library, the
// same way Override does.
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../domain/content.dart';
import '../domain/progress.dart';
import '../domain/repositories.dart';
import '../quran/uthmani_text.dart';
import 'data_providers.dart';

/// All 114 surahs, in mushaf order.
final FutureProvider<List<Surah>> surahsProvider = FutureProvider<List<Surah>>(
  (Ref ref) => ref.watch(contentRepositoryProvider).surahs(),
  name: 'surahs',
);

/// What the content build is and where it came from. For the About screen.
final FutureProvider<ContentMetadata> contentMetadataProvider =
    FutureProvider<ContentMetadata>(
      (Ref ref) => ref.watch(contentRepositoryProvider).metadata(),
      name: 'contentMetadata',
    );

/// One surah, ready to render.
@immutable
final class SurahReading {
  const SurahReading({
    required this.surah,
    required this.ayahs,
    required this.bismillah,
  });

  final Surah surah;

  /// Every ayah of the surah, in order.
  ///
  /// The whole surah at once. Al-Baqarah is 286 rows and the longest ayah is
  /// under half a kilobyte, so this is well under a megabyte even for the worst
  /// case; [ListView.builder] virtualises the widgets, which is the part that
  /// actually costs anything.
  final List<Ayah> ayahs;

  /// The basmala to set as a heading above the first verse, or null when there
  /// is none to set.
  ///
  /// Three cases, and the database decides which:
  ///
  ///   * **At-Tawbah** has no basmala. `surahs.has_bismillah` is 0 for surah 9
  ///     and 1 for the other 113.
  ///   * **Al-Fatiha** has it as ayah 1 — it is a numbered verse of the surah,
  ///     and renders as one. So no heading, or it would appear twice.
  ///   * **Everything else** has it as a heading and not as a verse. It is not
  ///     in `ayahs` at all for those surahs, so the text comes from 1:1 with
  ///     its verse number stripped.
  final String? bismillah;

  bool get hasBismillahHeading => bismillah != null;
}

/// [SurahReading] for a surah number.
final FutureProviderFamily<SurahReading, int> surahReadingProvider =
    FutureProvider.family<SurahReading, int>((Ref ref, int surahNumber) async {
      final ContentRepository content = ref.watch(contentRepositoryProvider);
      final Surah surah = await content.surah(surahNumber);
      final List<Ayah> ayahs = await content.ayahsForSurah(surahNumber);

      String? bismillah;
      if (surah.hasBismillah && surah.number != _alFatiha) {
        // Taken from the one place it exists as text rather than written out
        // here: 1:1 is the basmala, and its verse number comes off because it
        // is being set as a heading, not as Al-Fatiha's first verse.
        final Ayah opening = await content.ayah(_alFatiha, 1);
        bismillah = UthmaniText.withoutAyahNumber(opening.textUthmani);
      }

      return SurahReading(surah: surah, ayahs: ayahs, bismillah: bismillah);
    }, name: 'surahReading');

const int _alFatiha = 1;

/// The verse the settings screen previews.
///
/// Al-Fatiha 1:1 — short enough not to dominate the screen, and the one verse
/// every reader recognises at a glance, which is what makes it useful for
/// judging a size rather than reading.
final FutureProvider<Ayah> previewAyahProvider = FutureProvider<Ayah>(
  (Ref ref) => ref.watch(contentRepositoryProvider).ayah(_alFatiha, 1),
  name: 'previewAyah',
);

/// Where the user last was, for the surah list's resume affordance.
final FutureProvider<ReadingPosition?> lastReadingPositionProvider =
    FutureProvider<ReadingPosition?>(
      (Ref ref) => ref.watch(userRepositoryProvider).lastPosition(),
      name: 'lastReadingPosition',
    );

/// Records the reading position, at most once every [debounce].
///
/// Scrolling produces a position on every frame and none of them are worth a
/// write. What matters is the last one, so writes are coalesced and the pending
/// value is flushed when the reading screen goes away — closing a surah is
/// exactly when the position needs to be durable, and it is also when nothing
/// further will arrive to trigger the timer.
///
/// The stored value is an **ayah number, never a scroll offset.** Text size is
/// user-adjustable, so an offset points at a different verse the moment the
/// slider moves.
class ReadingPositionRecorder {
  ReadingPositionRecorder({
    required UserRepository repository,
    required void Function() onSaved,
  }) : _repository = repository,
       _onSaved = onSaved;

  /// Held directly rather than read through a [Ref] on each write.
  ///
  /// The last write this object makes happens while it is being disposed, and a
  /// [Ref] is not usable then — which is exactly the moment the position most
  /// needs to be saved.
  final UserRepository _repository;

  /// Called after a write lands, so the surah list's resume affordance can
  /// refresh. Guarded by the provider, since a flush during teardown must not
  /// touch a disposed [Ref].
  final void Function() _onSaved;

  static const Duration debounce = Duration(seconds: 1);

  Timer? _timer;
  ReadingPosition? _pending;
  ReadingPosition? _written;
  bool _disposed = false;

  /// Notes that [ayahNumber] of [surahNumber] is the topmost visible verse.
  void record(int surahNumber, int ayahNumber) {
    if (_disposed) return;
    final ReadingPosition position = ReadingPosition(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
    );
    if (_isSamePlace(position, _written) || _isSamePlace(position, _pending)) {
      return;
    }
    _pending = position;
    _timer ??= Timer(debounce, _write);
  }

  /// Writes whatever is pending, now.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    return _write();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    // The write is started and not awaited — dispose cannot be async. It is a
    // single upsert against a local database, and the database outlives this
    // object, so it lands. Losing it would cost one resume position.
    unawaited(_write(notify: false));
    _disposed = true;
  }

  Future<void> _write({bool notify = true}) async {
    _timer = null;
    final ReadingPosition? position = _pending;
    if (position == null) return;
    _pending = null;
    _written = position;
    await _repository.saveLastPosition(position);
    if (notify && !_disposed) _onSaved();
  }

  static bool _isSamePlace(ReadingPosition a, ReadingPosition? b) =>
      b != null &&
      a.surahNumber == b.surahNumber &&
      a.ayahNumber == b.ayahNumber;
}

final Provider<ReadingPositionRecorder> readingPositionRecorderProvider =
    Provider<ReadingPositionRecorder>((Ref ref) {
      final ReadingPositionRecorder recorder = ReadingPositionRecorder(
        repository: ref.watch(userRepositoryProvider),
        onSaved: () {
          // The surah list is not mounted while this is scrolling, so this
          // costs nothing and means the resume affordance is right the moment
          // it comes back. Guarded because a flush can outlive the provider.
          if (ref.mounted) ref.invalidate(lastReadingPositionProvider);
        },
      );
      ref.onDispose(recorder.dispose);
      return recorder;
    }, name: 'readingPositionRecorder');
