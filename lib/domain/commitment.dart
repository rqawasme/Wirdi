import 'collection_id.dart';

/// Which part of the day a collection is committed to.
///
/// Three, and the order they are declared in is the order the home screen
/// renders them: [today] first because it is not tied to a time, then the two
/// that are, in the order they come round. The sections are not time-aware —
/// Morning does not move to the top at dawn — because a fixed order is a
/// screen you can learn the shape of, and one that rearranges itself is a
/// screen you have to re-read every time you open it.
enum DailySection {
  /// Not tied to a time of day. This is where a collection lands when what
  /// matters about it is the day rather than the hour — the Friday reading of
  /// al-Kahf sits here, on Fridays.
  today('Today'),
  morning('Morning'),
  evening('Evening');

  const DailySection(this.label);

  /// The section header, and the wording of the choice offered when
  /// committing. Sentence case like every other label in the app.
  final String label;
}

/// The days of the week a commitment falls on.
///
/// Orthogonal to [DailySection]: the section says where in the day something
/// sits, this says which days it is due at all. Most commitments are every
/// day and say nothing about it; the ones that are not are the reason this
/// exists — al-Kahf on Friday, and the collections authored for a particular
/// day of the week.
///
/// Stored as a seven-bit mask so a commitment stays one row. Bit 0 is Monday
/// through bit 6 Sunday, matching [DateTime.monday] .. [DateTime.sunday] less
/// one; the order is the ISO one rather than a locale's, because the mask is
/// storage and the display order is a question for the widget that draws it.
final class Weekdays {
  /// Takes the low seven bits of [mask] and ignores the rest.
  const Weekdays.fromMask(int mask) : mask = mask & _all;

  /// From [DateTime] weekday constants. Anything outside 1..7 is dropped
  /// rather than throwing: a day that is not a day cannot be selected in the
  /// UI, so one arriving here means a stored value went wrong, and losing it
  /// is better than failing to draw the home screen.
  factory Weekdays.of(Iterable<int> weekdays) {
    int mask = 0;
    for (final int weekday in weekdays) {
      if (weekday < DateTime.monday || weekday > DateTime.sunday) continue;
      mask |= 1 << (weekday - 1);
    }
    return Weekdays.fromMask(mask);
  }

  /// Every day. The default, and what the great majority of commitments are.
  static const Weekdays everyDay = Weekdays.fromMask(_all);

  static const int _all = 0x7F;

  final int mask;

  bool contains(int weekday) =>
      weekday >= DateTime.monday &&
      weekday <= DateTime.sunday &&
      mask & (1 << (weekday - 1)) != 0;

  bool get isEveryDay => mask == _all;

  /// No day at all. Not reachable from the UI — the picker refuses to leave a
  /// commitment with nothing selected — but a stored zero has to mean
  /// something, and it means the commitment never comes round.
  bool get isEmpty => mask == 0;

  /// The selected days as [DateTime] weekday constants, Monday first.
  List<int> get weekdays => <int>[
    for (int weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      if (contains(weekday)) weekday,
  ];

  Weekdays toggle(int weekday) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) return this;
    return Weekdays.fromMask(mask ^ (1 << (weekday - 1)));
  }

  @override
  bool operator ==(Object other) => other is Weekdays && other.mask == mask;

  @override
  int get hashCode => Object.hash(Weekdays, mask);

  @override
  String toString() => isEveryDay ? 'Weekdays.everyDay' : 'Weekdays$weekdays';
}

/// A collection the user has committed to doing, and when.
///
/// A collection with no commitment is not on the home screen. It is still in
/// the collections list and still openable — committing is about what the day
/// is meant to contain, not about what exists.
final class Commitment {
  Commitment({
    required this.collectionId,
    required this.section,
    required this.sortOrder,
    this.days = Weekdays.everyDay,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final CollectionId collectionId;

  final DailySection section;

  /// Which days of the week this comes round on.
  final Weekdays days;

  /// Position among the commitments, as committed. Tiles sit in the order the
  /// user committed them and nothing reorders itself as the day goes on — a
  /// finished tile stays exactly where it was.
  final int sortOrder;

  final DateTime createdAt;

  final DateTime updatedAt;

  /// Whether this commitment is due on the local day of [date].
  bool fallsOn(DateTime date) => days.contains(date.weekday);

  @override
  String toString() =>
      'Commitment(${collectionId.canonical} ${section.name} '
      '${days.isEveryDay ? 'every day' : days.weekdays.join(',')} @$sortOrder)';
}
