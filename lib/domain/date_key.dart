/// A day, as `YYYY-MM-DD` in the device's local time.
///
/// Completions store this alongside their timestamp. It is denormalised
/// deliberately: streak queries run against it constantly, deriving local
/// dates from timestamps at query time is slow, and a timestamp-derived date
/// silently changes meaning when the user moves timezone. A `date_key` written
/// on the day it happened stays that day forever.
String dateKey(DateTime local) {
  final DateTime d = local.isUtc ? local.toLocal() : local;
  final String month = d.month.toString().padLeft(2, '0');
  final String day = d.day.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-$month-$day';
}

/// The `date_key` [days] before [from]'s local day.
String dateKeyDaysBefore(DateTime from, int days) {
  final DateTime local = from.isUtc ? from.toLocal() : from;
  // Step from local noon so that a DST shift cannot land the arithmetic on the
  // previous or next day.
  final DateTime noon = DateTime(local.year, local.month, local.day, 12);
  return dateKey(noon.subtract(Duration(days: days)));
}

/// The [DateTime] weekday constant — [DateTime.monday] .. [DateTime.sunday] —
/// of the day [key] names.
///
/// The one place a key is turned back into a weekday. It lives here because
/// this file owns the conversion in both directions, and because the parse has
/// a trap in it worth stating once rather than at every call site: the
/// [DateTime] it builds is local midnight, which is the correct instant to ask
/// a weekday of and the wrong one to do any arithmetic from. Stepping a day
/// from it lands on the same calendar date across a spring-forward, which is
/// what [dateKeyDaysBefore] exists to avoid. Ask this for the weekday; walk
/// days with that.
///
/// [key] is `YYYY-MM-DD` as [dateKey] writes it. Anything else is a caller bug
/// and throws, the same way [DateTime.parse] would.
int weekdayOf(String key) => DateTime.parse(key).weekday;
