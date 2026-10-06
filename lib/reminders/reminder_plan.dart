import 'package:flutter/foundation.dart' show immutable;

import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';

/// How many days ahead reminders are laid out.
///
/// Each reminder is scheduled as a single notification for a single day rather
/// than as a repeating one, because a repeating notification cannot skip one
/// day: a wird already finished this morning would still be reminded of this
/// evening. The cost of that is a horizon. Everything is laid out afresh each
/// time the app is opened, so this is only how long reminders keep coming for
/// somebody who stops opening it.
const int reminderHorizonDays = 28;

/// The most reminders scheduled at once.
///
/// iOS keeps at most 64 pending notifications per app and silently drops the
/// rest. The soonest are the ones kept, so a long list of reminders shortens
/// the horizon rather than losing today's.
const int maxPendingReminders = 64;

/// One notification, as it will be scheduled.
@immutable
final class PlannedReminder {
  const PlannedReminder({
    required this.collectionId,
    required this.at,
    required this.title,
    this.body,
  });

  final CollectionId collectionId;

  /// Local time.
  final DateTime at;

  final String title;

  final String? body;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.collectionId == collectionId &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(collectionId, at, title, body);

  @override
  String toString() => 'PlannedReminder(${collectionId.canonical} $at)';
}

/// What a reminder says.
///
/// The collection's name and nothing else: no count, no streak, nothing about
/// what happens if it is not done. A reminder is the phone saying the time has
/// come round, not the app applying pressure — see the note on the streak
/// panel for why that line is held everywhere.
String reminderTitle(CollectionSummary collection) =>
    'Time for ${collection.name}';

/// Every reminder due in the [days] days from [now], soonest first, at most
/// [limit] of them.
///
/// A commitment is reminded on the days it falls on, at its own time. Three
/// things leave a reminder out:
///
/// - its collection is gone. Commitments outlive the collections they name,
///   as completions do, and a reminder for something that no longer opens is
///   worse than none;
/// - its time today has already passed;
/// - it is for today and the collection was already completed today — the
///   point of laying reminders out one day at a time. [completedToday] is the
///   collections finished on [now]'s local day.
List<PlannedReminder> planReminders({
  required Iterable<Commitment> commitments,
  required Map<CollectionId, CollectionSummary> collections,
  required Set<CollectionId> completedToday,
  required DateTime now,
  int days = reminderHorizonDays,
  int limit = maxPendingReminders,
}) {
  final List<(Commitment, CollectionSummary, ReminderTime)> reminded =
      <(Commitment, CollectionSummary, ReminderTime)>[
        for (final Commitment c in commitments)
          if ((c.reminder, collections[c.collectionId]) case (
            final ReminderTime time,
            final CollectionSummary collection,
          ))
            (c, collection, time),
      ];

  final List<(PlannedReminder, int)> planned = <(PlannedReminder, int)>[];
  for (int offset = 0; offset < days; offset++) {
    // Calendar arithmetic rather than adding 24-hour durations, which lands an
    // hour off across a daylight-saving change.
    final DateTime date = DateTime(now.year, now.month, now.day + offset);
    for (final (Commitment c, CollectionSummary collection, ReminderTime time)
        in reminded) {
      if (!c.fallsOn(date)) continue;
      if (offset == 0 && completedToday.contains(c.collectionId)) continue;
      final DateTime at = time.on(date);
      if (!at.isAfter(now)) continue;
      planned.add((
        PlannedReminder(
          collectionId: c.collectionId,
          at: at,
          title: reminderTitle(collection),
          body: collection.nameArabic,
        ),
        c.sortOrder,
      ));
    }
  }

  // Two reminders at the same minute arrive in the order the commitments sit
  // on the home screen.
  planned.sort(
    ((PlannedReminder, int) a, (PlannedReminder, int) b) =>
        switch (a.$1.at.compareTo(b.$1.at)) {
          0 => a.$2.compareTo(b.$2),
          final int order => order,
        },
  );
  return <PlannedReminder>[
    for (final (PlannedReminder reminder, int _) in planned.take(limit))
      reminder,
  ];
}
