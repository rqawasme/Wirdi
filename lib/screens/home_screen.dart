import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/commitment.dart';
import '../providers/home.dart';
import '../providers/streak.dart';
import '../routes.dart';
import '../theme/theme.dart';
import '../widgets/collection_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/failure_screen.dart';

/// What the user committed to today, how far through each commitment they are,
/// and a way into one.
///
/// The app opens here. The collections list still exists — it is the
/// Collections tab — but it answers a different question: this screen is what
/// today contains, that one is what the app contains.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeView> home = ref.watch(homeViewProvider);

    return switch (home) {
      AsyncError(:final Object error, :final StackTrace stackTrace) =>
        FailureScreen(
          title: 'Could not read what you committed to',
          error: error,
          stackTrace: stackTrace,
        ),
      AsyncData(:final HomeView value) => _Home(view: value),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Home extends ConsumerWidget {
  const _Home({required this.view});

  final HomeView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
      children: <Widget>[
        _Greeting(view: view),
        if (view.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: WirdiMetrics.space6),
            child: EmptyState(
              title: 'Nothing committed yet',
              body:
                  'Commit a collection on the Collections tab and it will '
                  'appear here.',
            ),
          )
        else
          // Fixed order, and a section with nothing in it is not rendered at
          // all — no header, no placeholder, no empty state of its own. A
          // header over nothing is a promise the screen is not keeping.
          for (final DailySection section in DailySection.values)
            if (view.inSection(section)
                case final List<CommittedCollection> tiles
                when tiles.isNotEmpty)
              _Section(section: section, tiles: tiles),
      ],
    );
  }
}

/// The date, the salutation, and one quiet line about the day.
///
/// Three facts, stated and not commented on. The streak sentence reads the
/// same at three hundred and sixty-five days as at two: no flame, no tier, no
/// "don't break it", and nothing that gets louder as the number grows.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.view});

  final HomeView view;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final TextStyle quiet = type.caption.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space6,
        WirdiMetrics.space4,
        WirdiMetrics.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_date(view.today), style: quiet),
          const SizedBox(height: WirdiMetrics.space2),
          Text('Assalamu alaykum', style: type.sectionHeader),
          const SizedBox(height: WirdiMetrics.space2),
          Text(_day(view), style: quiet),
        ],
      ),
    );
  }

  /// `Wednesday, 3 September`.
  ///
  /// Written out here rather than taken from [MaterialLocalizations], whose
  /// full date is "Wednesday, September 3, 2026": the year is noise on a
  /// screen about today, and the month-first order is one locale's habit
  /// rather than the neutral one. The app ships no localisations yet — when it
  /// does, this is one of the strings that has to go through them.
  static String _date(DateTime day) =>
      '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}';

  /// The streak, and what is left of the day. Two sentences at most, and each
  /// one is a number stated flatly.
  static String _day(HomeView view) {
    final StringBuffer line = StringBuffer(_streak(view.streak));
    if (!view.isEmpty) {
      line.write(' ${_finished(view.finishedToday, view.committed.length)}');
    }
    return line.toString();
  }

  static String _streak(int days) => switch (days) {
    0 => 'No days in a row.',
    1 => '1 day in a row.',
    _ => '$days days in a row.',
  };

  static String _finished(int done, int total) {
    if (done == 0) return 'Nothing finished today.';
    return '${_capitalise(_word(done))} of ${_word(total)} finished today.';
  }

  /// Numbers inside a sentence are words; the streak's own number is a
  /// numeral. That is not an inconsistency — "One of six finished today" is a
  /// sentence about the day, and "2 days in a row" is a count being reported.
  ///
  /// Above twenty it falls back to the numeral, which is where spelling out
  /// stops helping anybody read the line faster. Nobody commits to twenty-one
  /// collections, but the line still has to render if they do.
  static String _word(int n) =>
      n >= 0 && n < _numbers.length ? _numbers[n] : '$n';

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static const List<String> _numbers = <String>[
    'none',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'eleven',
    'twelve',
    'thirteen',
    'fourteen',
    'fifteen',
    'sixteen',
    'seventeen',
    'eighteen',
    'nineteen',
    'twenty',
  ];

  static const List<String> _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}

/// A header, then the tiles under it, two up.
class _Section extends ConsumerWidget {
  const _Section({required this.section, required this.tiles});

  final DailySection section;
  final List<CommittedCollection> tiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WirdiMetrics.space4,
            WirdiMetrics.space5,
            WirdiMetrics.space4,
            WirdiMetrics.space3,
          ),
          child: Text(section.label, style: type.sectionHeader),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WirdiMetrics.space4),
          child: GridView.count(
            // Inside a ListView: the grid is as tall as its rows and the page
            // scrolls, rather than each section scrolling on its own.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: WirdiMetrics.space3,
            mainAxisSpacing: WirdiMetrics.space3,
            childAspectRatio: 1,
            children: <Widget>[
              for (final CommittedCollection tile in tiles)
                CollectionTile(
                  name: tile.name,
                  nameArabic: tile.nameArabic,
                  totalCount: tile.totalCount,
                  doneCount: tile.doneCount,
                  completedToday: tile.completedToday,
                  onTap: () => _open(context, ref, tile),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    CommittedCollection tile,
  ) async {
    await Navigator.pushNamed(
      context,
      Routes.player,
      arguments: PlayerArguments(collectionId: tile.id),
    );
    // The player is where progress and completions happen, so every tile on
    // this screen is stale the moment it comes back.
    if (context.mounted) {
      ref.invalidate(homeViewProvider);
      ref.invalidate(streakViewProvider);
    }
  }
}
