import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/player/player_haptics.dart';
import 'package:wirdi/player/wird_player.dart';

import '../support/fixtures.dart';

/// The counter, without a widget in sight.
///
/// Everything the player does to its position is here rather than in the
/// screen, which is what lets counting, undo across a step boundary, resume
/// and completion be checked by calling methods instead of by finding pixels.
void main() {
  late TestDatabases dbs;
  late CountingUserRepository user;
  late RecordedHaptics haptics;
  late DateTime now;
  final List<WirdPlayer> opened = <WirdPlayer>[];

  setUp(() async {
    dbs = await TestDatabases.open();
    now = DateTime(2026, 3, 14, 9);
    user = CountingUserRepository(dbs.userRepository(clock: () => now));
    haptics = RecordedHaptics();
  });

  tearDown(() async {
    for (final WirdPlayer player in opened) {
      // Drained before the databases go: a write still in flight when the
      // connection closes fails, and that failure is the test's doing rather
      // than the player's. In the app both databases outlive every player.
      await player.flush();
      player.dispose();
    }
    opened.clear();
    await dbs.close();
  });

  /// A player over [collection], registered for disposal.
  WirdPlayer playerFor(
    ResolvedCollection collection, {
    WirdProgress? resumeFrom,
  }) {
    final WirdPlayer player = WirdPlayer(
      collection: collection,
      user: user,
      haptics: haptics.haptics,
      resumeFrom: resumeFrom,
      clock: () => now,
    );
    opened.add(player);
    return player;
  }

  Future<WirdPlayer> openPlayer(CollectionId id) async {
    final WirdPlayer player = await WirdPlayer.open(
      id: id,
      collections: dbs.collectionRepository(clock: () => now),
      user: user,
      haptics: haptics.haptics,
      clock: () => now,
    );
    opened.add(player);
    return player;
  }

  group('counting', () {
    test('counts through a single step and advances at the target', () {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 3),
          dhikrItem(1002, position: 2, count: 1),
        ]),
      );

      player.increment();
      expect(player.stepIndex, 0);
      expect(player.currentCount, 1);
      expect(player.remaining, 2);

      player.increment();
      expect(player.currentCount, 2);
      expect(player.remaining, 1);

      // The tap that reaches the target advances on its own: asking for a
      // separate "next" tap makes a tasbih of thirty-three take thirty-four.
      player.increment();
      expect(player.stepIndex, 1);
      expect(player.currentCount, 0);
      expect(player.finished, isFalse);
    });

    test('the heavier haptic marks the end of a step, not every tap', () {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 3),
          dhikrItem(1002, position: 2, count: 1),
        ]),
      );

      player.increment();
      player.increment();
      expect(haptics.impacts, 0);
      expect(haptics.selections, 2);

      player.increment();
      expect(haptics.impacts, 1);
      // The completing tap fires one effect, not two: two haptics on one tap
      // read as one muddy buzz rather than as an ending.
      expect(haptics.selections, 2);
    });

    test('a block of 3 repeated 7 times counts out 21 steps in order', () {
      final List<CollectionItemEntry> members = <CollectionItemEntry>[
        dhikrItem(1001, position: 1),
        dhikrItem(1002, position: 2),
        dhikrItem(1003, position: 3),
      ];
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          RepeatBlock(group: 1, repeatCount: 7, entries: members),
        ]),
      );

      final List<String> visited = <String>[];
      for (int tap = 0; tap < 21; tap++) {
        visited.add(
          '${player.step.ref.id} round ${player.step.repetition}'
          '/${player.step.repetitionsTotal}',
        );
        player.increment();
      }

      expect(visited, <String>[
        for (int round = 1; round <= 7; round++) ...<String>[
          '1001 round $round/7',
          '1002 round $round/7',
          '1003 round $round/7',
        ],
      ]);
      // The block is recited whole each time round, not item by item.
      expect(player.finished, isTrue);
    });

    test('a step inside a block knows which round it is on', () {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          RepeatBlock(
            group: 1,
            repeatCount: 7,
            entries: <CollectionItemEntry>[
              dhikrItem(1001, position: 1),
              dhikrItem(1002, position: 2),
              dhikrItem(1003, position: 3),
            ],
          ),
        ]),
      );

      // Four steps in is the first item of the second round.
      for (int tap = 0; tap < 3; tap++) {
        player.increment();
      }
      expect(player.step.ref, const ContentRef.dhikr(1001));
      expect(player.step.repetition, 2);
      expect(player.step.repetitionsTotal, 7);
      expect(player.step.isInRepeatBlock, isTrue);
    });
  });

  group('undo', () {
    test('takes back one repetition', () {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[dhikrItem(1001, position: 1, count: 5)]),
      );

      player.increment();
      player.increment();
      player.decrement();

      expect(player.currentCount, 1);
      expect(player.stepIndex, 0);
    });

    test('at count zero it steps back to the previous step at its full '
        'count', () {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 3),
          dhikrItem(1002, position: 2, count: 10),
        ]),
      );

      player.increment();
      player.increment();
      player.increment();
      expect(player.stepIndex, 1);
      expect(player.currentCount, 0);

      player.decrement();

      // The state the advancing tap moved off, so undo undoes that tap rather
      // than throwing away the step it completed.
      expect(player.stepIndex, 0);
      expect(player.currentCount, 3);
      expect(player.remaining, 0);

      // And one more tap completes it again.
      player.increment();
      expect(player.stepIndex, 1);
      expect(player.currentCount, 0);
    });

    test('at the first step with nothing counted it does nothing', () {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 3),
          dhikrItem(1002, position: 2, count: 3),
        ]),
      );

      expect(player.canUndo, isFalse);
      player.decrement();

      expect(player.stepIndex, 0);
      expect(player.currentCount, 0);
      expect(user.saves, 0);
    });
  });

  group('skipping', () {
    test('leaves the skipped step incomplete', () async {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 5),
          dhikrItem(1002, position: 2, count: 5),
        ]),
      );

      player.increment();
      player.increment();
      player.skipForward();
      expect(player.stepIndex, 1);
      expect(player.currentCount, 0);

      // Nothing was credited to the step that was skipped past: coming back to
      // it, it is at zero rather than at the count it was left at or the count
      // it would have had if it had been finished.
      player.skipBackward();
      expect(player.stepIndex, 0);
      expect(player.currentCount, 0);
      expect(player.remaining, 5);
    });

    test('off the end of the last step does not finish the wird', () async {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 2),
          dhikrItem(1002, position: 2, count: 2),
        ]),
      );

      player.skipForward();
      expect(player.stepIndex, 1);
      expect(player.canSkipForward, isFalse);

      player.skipForward();
      await player.flush();

      // A wird is finished by reciting it, not by paging past it.
      expect(player.finished, isFalse);
      expect(user.completions, 0);
      expect(
        await user.isCompletedToday(const BuiltinCollectionId(1)),
        isFalse,
      );
    });
  });

  group('completion', () {
    test(
      'the last step logs a completion and clears the progress row',
      () async {
        const CollectionId id = BuiltinCollectionId(1);
        final WirdPlayer player = playerFor(
          collectionOf(<CollectionEntry>[
            dhikrItem(1001, position: 1, count: 2),
            dhikrItem(1002, position: 2, count: 2),
          ]),
        );

        player.increment();
        await player.flush();
        expect(await user.progress(id), isNotNull, reason: 'part-way through');

        player.increment();
        player.increment();
        player.increment();
        await player.flush();

        expect(player.finished, isTrue);
        // Not zero: the stripe holds solid for the completion beat.
        expect(player.currentCount, 2);
        expect(player.remaining, 0);
        expect(user.completions, 1);
        expect(await user.isCompletedToday(id), isTrue);
        expect(await user.progress(id), isNull);
      },
    );

    test(
      'a count written just before the end cannot resurrect the session',
      () async {
        const CollectionId id = BuiltinCollectionId(1);
        final WirdPlayer player = playerFor(
          collectionOf(<CollectionEntry>[
            dhikrItem(1001, position: 1, count: 3),
          ]),
        );

        // A debounced write is sitting behind the timer when the wird finishes.
        player.increment();
        expect(player.hasPendingSave, isTrue);
        player.increment();
        player.increment();
        await player.flush();

        expect(player.hasPendingSave, isFalse);
        expect(await user.progress(id), isNull);
      },
    );

    test('further taps after the end do nothing', () async {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[dhikrItem(1001, position: 1, count: 1)]),
      );

      player.increment();
      player.increment();
      player.increment();
      await player.flush();

      expect(user.completions, 1);
      expect(player.canUndo, isFalse);
    });
  });

  group('resume', () {
    test('a matching step ref restores the position silently', () async {
      const CollectionId id = BuiltinCollectionId(mixedCollectionId);
      final ResolvedCollection resolved = await dbs
          .collectionRepository()
          .resolve(id);
      // Step 8 is the second surah of the second round of the repeat block.
      final PlaybackStep step = resolved.steps[8];
      await user.saveProgress(
        WirdProgress.atStep(
          collectionId: id,
          step: step,
          currentCount: 0,
          updatedAt: now,
        ),
      );

      final WirdPlayer player = await openPlayer(id);

      expect(player.stepIndex, 8);
      expect(player.step.ref, step.ref);
      expect(player.step.repetition, 2);
      expect(await user.progress(id), isNotNull, reason: 'still there');
    });

    test('a mismatched ref starts fresh and clears the stale row', () async {
      const CollectionId id = BuiltinCollectionId(mixedCollectionId);
      await user.saveProgress(
        WirdProgress(
          collectionId: id,
          stepIndex: 8,
          // Whatever was at index 8 when this was written, it was not this.
          stepRef: const ContentRef.dhikr(9999),
          currentCount: 2,
          updatedAt: now,
        ),
      );

      final WirdPlayer player = await openPlayer(id);

      expect(player.stepIndex, 0);
      expect(player.currentCount, 0);
      // A row that does not survive validation is deleted rather than left to
      // fail the same way tomorrow.
      expect(await user.progress(id), isNull);
      expect(user.clears, 1);
    });

    test('an index past the end starts fresh', () async {
      const CollectionId id = BuiltinCollectionId(simpleCollectionId);
      await user.saveProgress(
        WirdProgress(
          collectionId: id,
          stepIndex: 99,
          stepRef: const ContentRef.dhikr(1004),
          currentCount: 1,
          updatedAt: now,
        ),
      );

      final WirdPlayer player = await openPlayer(id);

      expect(player.stepIndex, 0);
      expect(await user.progress(id), isNull);
    });

    test('a count past the step target is clamped rather than trusted', () {
      final ResolvedCollection collection = collectionOf(<CollectionEntry>[
        dhikrItem(1001, position: 1, count: 3),
      ]);
      final WirdPlayer player = playerFor(
        collection,
        resumeFrom: WirdProgress.atStep(
          collectionId: collection.id,
          step: collection.steps.first,
          currentCount: 99,
          updatedAt: now,
        ),
      );

      expect(player.currentCount, 3);
      expect(player.remaining, 0);
    });

    test('nothing stored starts at the beginning and writes nothing', () async {
      final WirdPlayer player = await openPlayer(
        const BuiltinCollectionId(mixedCollectionId),
      );

      expect(player.stepIndex, 0);
      expect(player.currentCount, 0);
      expect(user.clears, 0, reason: 'there was no stale row to clear');
      expect(user.saves, 0);
    });
  });

  group('writing progress', () {
    test('is not written on every increment', () async {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 100),
        ]),
      );

      for (int tap = 0; tap < 12; tap++) {
        player.increment();
      }
      await player.writes;

      // Twelve taps, no write: they are behind the debounce, which has not
      // fired because the test has not waited for it.
      expect(user.saves, 0);
      expect(player.hasPendingSave, isTrue);

      await player.flush();
      expect(user.saves, 1);
      expect((await user.progress(player.id))!.currentCount, 12);
    });

    test('a step advance is written immediately, not debounced', () async {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 2),
          dhikrItem(1002, position: 2, count: 2),
        ]),
      );

      player.increment();
      player.increment();

      // Awaiting the queued writes rather than flushing: the write is there
      // because advancing queued it, not because the timer fired.
      await player.writes;
      expect(player.hasPendingSave, isFalse);
      expect(user.saves, 1);
      expect((await user.progress(player.id))!.stepIndex, 1);
    });

    test(
      'the debounce is a rate limiter, so a long run is written through',
      () async {
        final WirdPlayer player = playerFor(
          collectionOf(<CollectionEntry>[
            dhikrItem(1001, position: 1, count: 100),
          ]),
          // Short enough to wait for, long enough to still be a window.
        );

        player.increment();
        // The timer is running; taps inside the window ride along with it rather
        // than pushing it further out.
        await Future<void>.delayed(WirdPlayer.defaultSaveDebounce * 1.5);
        player.increment();
        await player.writes;

        expect(user.saves, 1, reason: 'the first window wrote once');
        expect(
          player.hasPendingSave,
          isTrue,
          reason: 'the second tap is queued',
        );
      },
    );

    test('starting over forgets the saved position', () async {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 2),
          dhikrItem(1002, position: 2, count: 2),
        ]),
      );

      player.increment();
      player.increment();
      await player.flush();
      expect(await user.progress(player.id), isNotNull);

      player.startOver();
      await player.writes;

      expect(player.stepIndex, 0);
      expect(player.currentCount, 0);
      // The row goes rather than being rewritten at step zero: a position
      // nobody has reached is not progress, and it would show the collection
      // as part-way through a session that has not started.
      expect(await user.progress(player.id), isNull);
    });

    test('disposing writes what is pending', () async {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 100),
        ]),
      );

      player.increment();
      player.increment();
      player.dispose();
      opened.remove(player);
      await player.writes;

      expect(user.saves, 1);
      expect((await user.progress(player.id))!.currentCount, 2);
    });
  });

  group('a collection with nothing in it', () {
    test('is safe to open and to tap at', () async {
      final WirdPlayer player = playerFor(collectionOf(<CollectionEntry>[]));

      expect(player.isEmpty, isTrue);
      player.increment();
      player.decrement();
      player.skipForward();
      await player.flush();

      expect(player.finished, isFalse);
      expect(user.saves, 0);
      expect(user.completions, 0);
    });
  });

  group('the stripe', () {
    test('is one segment per step, up to thirty-three', () {
      final WirdPlayer short = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 33),
          dhikrItem(1002, position: 2, count: 100),
          dhikrItem(1003, position: 3, count: 3),
        ]),
      );
      expect(short.stripeSegments, 3, reason: 'three steps, three segments');

      final WirdPlayer long = playerFor(
        collectionOf(<CollectionEntry>[
          RepeatBlock(
            group: 1,
            repeatCount: 20,
            entries: <CollectionItemEntry>[
              dhikrItem(1001, position: 1),
              dhikrItem(1002, position: 2),
            ],
          ),
        ]),
      );
      expect(long.steps, hasLength(40));
      expect(long.stripeSegments, WirdPlayer.maxStripeSegments);
    });

    test('measures the wird, not the step', () {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 4),
          dhikrItem(1002, position: 2, count: 1),
        ]),
      );

      expect(player.collectionProgress, 0);

      player.increment();
      // A quarter of the way through the first of two steps.
      expect(player.stepProgress, 0.25);
      expect(player.collectionProgress, closeTo(0.125, 0.0001));

      player.increment();
      player.increment();
      player.increment();
      // The step is done and the stripe is half way, whatever the new step's
      // own count is.
      expect(player.stepIndex, 1);
      expect(player.stepProgress, 0);
      expect(player.collectionProgress, 0.5);
    });

    test(
      'is full when the wird is done, and empty after starting over',
      () async {
        final WirdPlayer player = playerFor(
          collectionOf(<CollectionEntry>[
            dhikrItem(1001, position: 1, count: 1),
            dhikrItem(1002, position: 2, count: 1),
          ]),
        );

        player.increment();
        player.increment();
        expect(player.finished, isTrue);
        expect(player.collectionProgress, 1);

        player.startOver();
        await player.writes;
        expect(player.collectionProgress, 0);
      },
    );

    test('goes backwards with undo and with a skip back', () {
      final WirdPlayer player = playerFor(
        collectionOf(<CollectionEntry>[
          dhikrItem(1001, position: 1, count: 2),
          dhikrItem(1002, position: 2, count: 2),
        ]),
      );

      player.increment();
      player.increment();
      expect(player.collectionProgress, 0.5);

      player.decrement();
      // Back on the first step at its full count: half way, from the other
      // side of the boundary.
      expect(player.collectionProgress, 0.5);

      player.decrement();
      expect(player.collectionProgress, 0.25);
    });
  });
}

/// A [ResolvedCollection] built in Dart, the way `playback_steps_test` does:
/// `steps` is derived purely from `entries`, so counting can be exercised
/// without a database behind it.
ResolvedCollection collectionOf(
  List<CollectionEntry> entries, {
  CollectionId id = const BuiltinCollectionId(1),
}) {
  return ResolvedCollection(
    collection: CollectionSummary(id: id, name: 'PLACEHOLDER', sortOrder: 1),
    entries: entries,
  );
}

DhikrItem dhikrItem(
  int id, {
  required int position,
  int count = 1,
  String? note,
}) {
  return DhikrItem(
    entryId: 'entry-$id-$position',
    position: position,
    count: count,
    note: note,
    dhikr: Dhikr(
      id: id,
      textArabic: 'PLACEHOLDER dhikr $id arabic',
      translation: 'PLACEHOLDER dhikr $id translation',
      defaultCount: count,
    ),
  );
}

/// [PlayerHaptics] with the two effects counted instead of sent, and a clock
/// that does not move — so a test that means to check the throttle has to say
/// so, and every other test is unaffected by how fast it runs.
class RecordedHaptics {
  RecordedHaptics() {
    haptics = PlayerHaptics(
      selection: () => selections++,
      impact: () => impacts++,
      // Every effect at the same instant would be thrown away by the throttle,
      // so the clock steps a second on each read.
      clock: () => DateTime(2026).add(Duration(seconds: _reads++)),
    );
  }

  late final PlayerHaptics haptics;
  int selections = 0;
  int impacts = 0;
  int _reads = 0;
}

/// A [UserRepository] that forwards everything and counts the writes.
///
/// Counting them is the point: "not on every tap" is a claim about how many
/// times the database was touched, and it cannot be checked by looking at what
/// ended up in it.
class CountingUserRepository implements UserRepository {
  CountingUserRepository(this._inner);

  final UserRepository _inner;

  int saves = 0;
  int clears = 0;
  int completions = 0;

  @override
  Future<void> saveProgress(WirdProgress progress) {
    saves++;
    return _inner.saveProgress(progress);
  }

  @override
  Future<void> clearProgress(CollectionId id) {
    clears++;
    return _inner.clearProgress(id);
  }

  @override
  Future<void> logCompletion(CollectionId id, DateTime at) {
    completions++;
    return _inner.logCompletion(id, at);
  }

  @override
  Future<WirdProgress?> progress(CollectionId id) => _inner.progress(id);

  @override
  Future<bool> isCompletedToday(CollectionId id) => _inner.isCompletedToday(id);

  @override
  Future<List<String>> completionDates({DateTime? from, DateTime? to}) =>
      _inner.completionDates(from: from, to: to);

  @override
  Future<int> currentStreak() => _inner.currentStreak();

  @override
  Future<List<Commitment>> commitments() => _inner.commitments();

  @override
  Future<void> commit(
    CollectionId id,
    DailySection section, {
    Weekdays days = Weekdays.everyDay,
  }) => _inner.commit(id, section, days: days);

  @override
  Future<void> uncommit(CollectionId id) => _inner.uncommit(id);

  @override
  Future<ReadingPosition?> lastPosition() => _inner.lastPosition();

  @override
  Future<void> saveLastPosition(ReadingPosition position) =>
      _inner.saveLastPosition(position);

  @override
  Future<String?> setting(String key) => _inner.setting(key);

  @override
  Future<void> setSetting(String key, String value) =>
      _inner.setSetting(key, value);
}
