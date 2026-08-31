import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/domain.dart';

/// `steps` is derived purely from `entries`, so it can be exercised without a
/// database.
ResolvedCollection collectionOf(List<CollectionEntry> entries) {
  return ResolvedCollection(
    collection: const CollectionSummary(
      id: BuiltinCollectionId(1),
      name: 'PLACEHOLDER',
      sortOrder: 1,
    ),
    entries: entries,
  );
}

Dhikr dhikrOf(int id, {int defaultCount = 1}) => Dhikr(
  id: id,
  textArabic: 'PLACEHOLDER dhikr $id arabic',
  translation: 'PLACEHOLDER dhikr $id translation',
  defaultCount: defaultCount,
);

DhikrItem itemOf(int id, {required int position, int count = 1}) => DhikrItem(
  entryId: 'entry-$id',
  position: position,
  count: count,
  dhikr: dhikrOf(id),
);

void main() {
  group('steps', () {
    test('a collection with no repeat groups is one step per entry', () {
      final ResolvedCollection resolved = collectionOf(<CollectionEntry>[
        itemOf(1001, position: 1),
        itemOf(1002, position: 2, count: 33),
        itemOf(1003, position: 3),
      ]);

      expect(resolved.steps.length, resolved.entries.length);
      expect(
        resolved.steps.map((PlaybackStep s) => s.ref).toList(),
        <ContentRef>[
          const ContentRef.dhikr(1001),
          const ContentRef.dhikr(1002),
          const ContentRef.dhikr(1003),
        ],
      );
      expect(resolved.steps.map((PlaybackStep s) => s.count), <int>[1, 33, 1]);
      for (final PlaybackStep step in resolved.steps) {
        expect(step.repetition, 1);
        expect(step.repetitionsTotal, 1);
        expect(step.isInRepeatBlock, isFalse);
      }
    });

    test('a block of 3 repeated 7 times produces 21 steps', () {
      final RepeatBlock block = RepeatBlock(
        group: 1,
        repeatCount: 7,
        entries: <CollectionItemEntry>[
          itemOf(1001, position: 1),
          itemOf(1002, position: 2),
          itemOf(1003, position: 3),
        ],
      );
      final ResolvedCollection resolved = collectionOf(<CollectionEntry>[
        block,
      ]);

      expect(resolved.entries, hasLength(1));
      expect(resolved.steps, hasLength(21));

      // Pass by pass, not item by item: the block is recited whole each round.
      expect(
        resolved.steps.take(6).map((PlaybackStep s) => s.ref.id).toList(),
        <int>[1001, 1002, 1003, 1001, 1002, 1003],
      );

      // repetition runs 1..7, three steps at a time; the total never moves.
      for (int i = 0; i < 21; i++) {
        final PlaybackStep step = resolved.steps[i];
        expect(step.index, i);
        expect(step.repetition, i ~/ 3 + 1);
        expect(step.repetitionsTotal, 7);
        expect(step.isInRepeatBlock, isTrue);
      }
      expect(resolved.steps.first.repetition, 1);
      expect(resolved.steps.last.repetition, 7);
    });

    test('a step points back at the entry it came from', () {
      final ResolvedCollection resolved = collectionOf(<CollectionEntry>[
        RepeatBlock(
          group: 1,
          repeatCount: 2,
          entries: <CollectionItemEntry>[itemOf(1001, position: 1)],
        ),
      ]);
      expect(resolved.steps.map((PlaybackStep s) => s.entryId), <String>[
        'entry-1001',
        'entry-1001',
      ]);
    });

    test('blocks and loose items interleave in order', () {
      final ResolvedCollection resolved = collectionOf(<CollectionEntry>[
        itemOf(1001, position: 1),
        RepeatBlock(
          group: 1,
          repeatCount: 3,
          entries: <CollectionItemEntry>[itemOf(1002, position: 2)],
        ),
        itemOf(1003, position: 3),
      ]);

      expect(resolved.steps.map((PlaybackStep s) => s.ref.id).toList(), <int>[
        1001,
        1002,
        1002,
        1002,
        1003,
      ]);
      expect(
        resolved.steps.map((PlaybackStep s) => s.repetitionsTotal).toList(),
        <int>[1, 3, 3, 3, 1],
      );
    });
  });

  group('resumableFrom', () {
    final ResolvedCollection resolved = collectionOf(<CollectionEntry>[
      itemOf(1001, position: 1),
      itemOf(1002, position: 2),
      itemOf(1003, position: 3),
    ]);

    WirdProgress progressAt(int index, ContentRef ref) => WirdProgress(
      collectionId: const BuiltinCollectionId(1),
      stepIndex: index,
      stepRef: ref,
      currentCount: 5,
      updatedAt: DateTime(2026, 3, 14),
    );

    test('null progress stays null', () {
      expect(resolved.resumableFrom(null), isNull);
    });

    test('a matching stepRef resumes', () {
      final WirdProgress progress = progressAt(1, const ContentRef.dhikr(1002));
      final WirdProgress? resumed = resolved.resumableFrom(progress);
      expect(resumed, same(progress));
      expect(resumed!.stepIndex, 1);
      expect(resumed.currentCount, 5);
    });

    test('a mismatched stepRef resets to the start', () {
      // The index is still in range, but a reorder or a content update moved
      // something else under it.
      expect(
        resolved.resumableFrom(progressAt(1, const ContentRef.dhikr(1003))),
        isNull,
      );
    });

    test('an index past the end resets to the start', () {
      expect(
        resolved.resumableFrom(progressAt(9, const ContentRef.dhikr(1002))),
        isNull,
      );
      expect(
        resolved.resumableFrom(progressAt(-1, const ContentRef.dhikr(1002))),
        isNull,
      );
    });
  });

  group('ContentRef canonical form', () {
    test('round-trips every type', () {
      for (final ContentRef ref in <ContentRef>[
        const ContentRef.dhikr(1001),
        const ContentRef.ayah(2255),
        const ContentRef.surah(112),
      ]) {
        expect(ContentRef.parse(ref.canonical), ref);
      }
      expect(const ContentRef.ayah(2255).canonical, 'ayah:2255');
      expect(ContentRef.ayahAt(2, 255), const ContentRef.ayah(2255));
    });

    test('rejects anything else', () {
      for (final String bad in <String>[
        '',
        'dhikr',
        'dhikr:',
        'nope:1',
        '1001',
      ]) {
        expect(ContentRef.tryParse(bad), isNull, reason: bad);
        expect(() => ContentRef.parse(bad), throwsFormatException);
      }
    });
  });
}
