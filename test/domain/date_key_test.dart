import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/domain/date_key.dart';

void main() {
  test('pads to YYYY-MM-DD', () {
    expect(dateKey(DateTime(2026, 3, 4, 23, 59)), '2026-03-04');
    expect(dateKey(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('is the local day, so a UTC instant is converted first', () {
    final DateTime utc = DateTime.utc(2026, 3, 14, 12);
    expect(dateKey(utc), dateKey(utc.toLocal()));
  });

  test('string order is date order, which is what streak queries rely on', () {
    final List<String> keys = <String>[
      dateKey(DateTime(2026, 1, 9)),
      dateKey(DateTime(2025, 12, 31)),
      dateKey(DateTime(2026, 1, 10)),
    ]..sort();
    expect(keys, <String>['2025-12-31', '2026-01-09', '2026-01-10']);
  });

  group('dateKeyDaysBefore', () {
    test('steps back a day', () {
      expect(dateKeyDaysBefore(DateTime(2026, 3, 14, 9), 1), '2026-03-13');
      expect(dateKeyDaysBefore(DateTime(2026, 3, 14, 9), 0), '2026-03-14');
    });

    test('crosses a month boundary', () {
      expect(dateKeyDaysBefore(DateTime(2026, 3, 1, 9), 1), '2026-02-28');
    });

    test('crosses a year boundary', () {
      expect(dateKeyDaysBefore(DateTime(2026, 1, 1, 9), 1), '2025-12-31');
    });

    test('handles a leap day', () {
      expect(dateKeyDaysBefore(DateTime(2028, 3, 1, 9), 1), '2028-02-29');
    });

    test('steps from local noon, so a DST shift cannot skip a day', () {
      // Whatever the device timezone, stepping back one day at a time from any
      // hour must produce consecutive dates with no repeats or gaps.
      for (int hour in <int>[0, 1, 2, 3, 12, 23]) {
        final DateTime from = DateTime(2026, 3, 14, hour, 30);
        final List<String> keys = <String>[
          for (int i = 0; i < 10; i++) dateKeyDaysBefore(from, i),
        ];
        expect(keys.toSet(), hasLength(10), reason: 'from hour $hour');
        expect(
          keys,
          List<String>.of(keys)..sort((String a, String b) => b.compareTo(a)),
        );
      }
    });
  });
}
