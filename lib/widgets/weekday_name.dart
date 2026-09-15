import 'package:flutter/material.dart';

/// The reader's own name for a [DateTime] weekday constant — "Friday".
///
/// Wanted in two places, and they have to agree: the home tile says "3
/// Fridays. Keep going." about a wird committed to Fridays, and the tracker
/// says "3 Fridays in a row" about the same wird. Two spellings of the same
/// day on two screens is the kind of thing nobody files a bug about and
/// everybody notices.
///
/// [MaterialLocalizations] has no standalone weekday-name lookup — the only
/// thing it exposes is [MaterialLocalizations.narrowWeekdays], which is a
/// single letter, and a full date format. So the name is read off a real date
/// with the weekday wanted: 5 January 2026 is a Monday, and
/// `formatFullDate` opens with the weekday in every locale Flutter ships,
/// which is what the split takes.
///
/// A locale that does not put the weekday first, or does not separate it with
/// a comma, gets the whole formatted date back rather than a wrong word. That
/// is a long label on a card, and it is still true, which is the right way for
/// this to fail.
String weekdayName(BuildContext context, int weekday) {
  final DateTime day = DateTime(2026, 1, 4 + weekday);
  return MaterialLocalizations.of(context).formatFullDate(day).split(',').first;
}
