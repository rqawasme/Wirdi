import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/domain.dart';
import 'package:wirdi/reminders/reminder_plan.dart';

/// Laying reminders out, which is all arithmetic over the calendar and needs
/// no platform: what is scheduled, for when, and what is left out.
void main() {
  const CollectionId morning = BuiltinCollectionId(1);
  const CollectionId kahf = BuiltinCollectionId(2);
  final CollectionId mine = UserCollectionId('u1');

  final Map<CollectionId, CollectionSummary> collections =
      <CollectionId, CollectionSummary>{
        morning: const CollectionSummary(
          id: morning,
          name: 'PLACEHOLDER morning',
          nameArabic: 'PLACEHOLDER morning arabic',
          sortOrder: 1,
        ),
        kahf: const CollectionSummary(
          id: kahf,
          name: 'PLACEHOLDER kahf',
          nameArabic: 'PLACEHOLDER kahf arabic',
          sortOrder: 2,
        ),
        mine: CollectionSummary(id: mine, name: 'Mine', sortOrder: 3),
      };

  /// A Wednesday morning, before anything is due.
  final DateTime wednesday = DateTime(2026, 9, 2, 5);

  Commitment commitment(
    CollectionId id, {
    ReminderTime? reminder,
    Weekdays days = Weekdays.everyDay,
    int sortOrder = 1,
  }) => Commitment(
    collectionId: id,
    section: DailySection.morning,
    days: days,
    reminder: reminder,
    sortOrder: sortOrder,
  );

  List<PlannedReminder> plan(
    List<Commitment> commitments, {
    DateTime? now,
    Set<CollectionId> completedToday = const <CollectionId>{},
    int days = reminderHorizonDays,
    int limit = maxPendingReminders,
  }) => planReminders(
    commitments: commitments,
    collections: collections,
    completedToday: completedToday,
    now: now ?? wednesday,
    days: days,
    limit: limit,
  );

  test('an every-day reminder is laid out once a day, at its time', () {
    final List<PlannedReminder> planned = plan(<Commitment>[
      commitment(morning, reminder: const ReminderTime(6, 30)),
    ], days: 3);

    expect(planned.map((PlannedReminder r) => r.at), <DateTime>[
      DateTime(2026, 9, 2, 6, 30),
      DateTime(2026, 9, 3, 6, 30),
      DateTime(2026, 9, 4, 6, 30),
    ]);
  });

  test('it says the name of the wird and nothing else', () {
    final PlannedReminder reminder = plan(<Commitment>[
      commitment(morning, reminder: const ReminderTime(6, 30)),
    ], days: 1).single;

    expect(reminder.title, 'Time for PLACEHOLDER morning');
    expect(reminder.body, 'PLACEHOLDER morning arabic');
    expect(reminder.collectionId, morning);
  });

  test('a collection with no Arabic name has no body', () {
    final PlannedReminder reminder = plan(<Commitment>[
      commitment(mine, reminder: const ReminderTime(9, 0)),
    ], days: 1).single;

    expect(reminder.title, 'Time for Mine');
    expect(reminder.body, isNull);
  });

  test('a commitment without a reminder is not reminded of', () {
    expect(plan(<Commitment>[commitment(morning)]), isEmpty);
  });

  test('only on the days it falls on', () {
    // Al-Kahf on Fridays: the first two Fridays after a Wednesday.
    final List<PlannedReminder> planned = plan(<Commitment>[
      commitment(
        kahf,
        reminder: const ReminderTime(10, 0),
        days: Weekdays.of(<int>[DateTime.friday]),
      ),
    ], days: 14);

    expect(planned.map((PlannedReminder r) => r.at), <DateTime>[
      DateTime(2026, 9, 4, 10),
      DateTime(2026, 9, 11, 10),
    ]);
  });

  test('not today once its time has passed', () {
    final List<PlannedReminder> planned = plan(
      <Commitment>[commitment(morning, reminder: const ReminderTime(6, 30))],
      now: DateTime(2026, 9, 2, 6, 30),
      days: 2,
    );

    // The minute itself counts as passed: a reminder cannot be scheduled for
    // a moment that is already here.
    expect(planned.single.at, DateTime(2026, 9, 3, 6, 30));
  });

  test('not today once it is done today, and tomorrow all the same', () {
    final List<PlannedReminder> planned = plan(
      <Commitment>[
        commitment(morning, reminder: const ReminderTime(6, 30)),
        commitment(kahf, reminder: const ReminderTime(7, 0), sortOrder: 2),
      ],
      completedToday: <CollectionId>{morning},
      days: 2,
    );

    expect(
      planned.map((PlannedReminder r) => (r.collectionId, r.at)),
      <(CollectionId, DateTime)>[
        // Today's is gone for the one that is finished, and only for it.
        (kahf, DateTime(2026, 9, 2, 7)),
        (morning, DateTime(2026, 9, 3, 6, 30)),
        (kahf, DateTime(2026, 9, 3, 7)),
      ],
    );
  });

  test('a commitment whose collection is gone is not reminded of', () {
    expect(
      plan(<Commitment>[
        commitment(
          UserCollectionId('deleted'),
          reminder: const ReminderTime(6, 30),
        ),
      ]),
      isEmpty,
    );
  });

  test('soonest first, and in home-screen order within a minute', () {
    final List<PlannedReminder> planned = plan(<Commitment>[
      commitment(kahf, reminder: const ReminderTime(7, 0), sortOrder: 2),
      commitment(mine, reminder: const ReminderTime(6, 0), sortOrder: 3),
      commitment(morning, reminder: const ReminderTime(7, 0), sortOrder: 1),
    ], days: 1);

    expect(planned.map((PlannedReminder r) => r.collectionId), <CollectionId>[
      mine,
      morning,
      kahf,
    ]);
  });

  test('past the limit, the soonest are kept', () {
    final List<PlannedReminder> planned = plan(<Commitment>[
      commitment(morning, reminder: const ReminderTime(6, 0)),
      commitment(kahf, reminder: const ReminderTime(18, 0), sortOrder: 2),
    ], limit: 5);

    // Two a day, so five runs to the morning of the third day — the horizon
    // shortens rather than today's being the ones dropped.
    expect(planned, hasLength(5));
    expect(planned.first.at, DateTime(2026, 9, 2, 6));
    expect(planned.last.at, DateTime(2026, 9, 4, 6));
  });

  test('the default limit is what iOS will keep', () {
    final List<PlannedReminder> planned = plan(<Commitment>[
      commitment(morning, reminder: const ReminderTime(6, 0)),
      commitment(kahf, reminder: const ReminderTime(12, 0), sortOrder: 2),
      commitment(mine, reminder: const ReminderTime(18, 0), sortOrder: 3),
    ]);

    expect(planned, hasLength(64));
  });

  test('the horizon runs across a month end on the calendar', () {
    final List<PlannedReminder> planned = plan(
      <Commitment>[commitment(morning, reminder: const ReminderTime(6, 0))],
      now: DateTime(2026, 9, 30, 12),
      days: 3,
    );

    expect(planned.map((PlannedReminder r) => r.at), <DateTime>[
      DateTime(2026, 10, 1, 6),
      DateTime(2026, 10, 2, 6),
    ]);
  });

  group('ReminderTime', () {
    test('is stored as minutes after midnight', () {
      expect(const ReminderTime(6, 30).minutes, 390);
      expect(ReminderTime.tryFromMinutes(390), const ReminderTime(6, 30));
      expect(ReminderTime.tryFromMinutes(0), const ReminderTime(0, 0));
      expect(ReminderTime.tryFromMinutes(1439), const ReminderTime(23, 59));
    });

    test('anything that is not a minute of the day is no time', () {
      expect(ReminderTime.tryFromMinutes(null), isNull);
      expect(ReminderTime.tryFromMinutes(-1), isNull);
      expect(ReminderTime.tryFromMinutes(1440), isNull);
    });

    test('falls on the clock time of the day it is given', () {
      expect(
        const ReminderTime(17, 45).on(DateTime(2026, 3, 29, 23, 10)),
        DateTime(2026, 3, 29, 17, 45),
      );
    });
  });
}
