import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/content.dart';
import '../domain/progress.dart';
import '../providers/reading.dart';
import '../routes.dart';
import '../theme/theme.dart';
import '../widgets/failure_screen.dart';
import '../widgets/surah_row.dart';
import '../widgets/voussoir_stripe.dart';

/// All 114 surahs, and a way back to wherever you were.
class SurahListScreen extends ConsumerWidget {
  const SurahListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Surah>> surahs = ref.watch(surahsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran'),
        actions: <Widget>[
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.science_outlined),
              tooltip: 'Type check (debug)',
              onPressed: () => Navigator.pushNamed(context, Routes.dev),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, Routes.settings),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () => Navigator.pushNamed(context, Routes.about),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: switch (surahs) {
        AsyncError(:final Object error, :final StackTrace stackTrace) =>
          FailureScreen(
            title: 'Could not read the surah list',
            error: error,
            stackTrace: stackTrace,
          ),
        AsyncData(:final List<Surah> value) => _SurahList(surahs: value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SurahList extends ConsumerWidget {
  const _SurahList({required this.surahs});

  final List<Surah> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The resume tile is a leading item rather than a separate header, so it
    // scrolls away with the list instead of taking a permanent strip of a
    // screen whose whole job is scanning 114 rows.
    final ReadingPosition? position = ref
        .watch(lastReadingPositionProvider)
        .value;

    final int leading = position == null ? 0 : 1;

    return ListView.builder(
      itemCount: surahs.length + leading,
      itemBuilder: (BuildContext context, int index) {
        if (position != null && index == 0) {
          return _ResumeTile(position: position, surahs: surahs);
        }
        final Surah surah = surahs[index - leading];
        return SurahRow(
          surah: surah,
          onTap: () => Navigator.pushNamed(
            context,
            Routes.reading,
            arguments: ReadingArguments(surahNumber: surah.number),
          ),
        );
      },
    );
  }
}

/// Back to where the reader left off.
class _ResumeTile extends StatelessWidget {
  const _ResumeTile({required this.position, required this.surahs});

  final ReadingPosition position;
  final List<Surah> surahs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Surah? surah = surahs
        .where((Surah s) => s.number == position.surahNumber)
        .firstOrNull;
    // A saved position naming a surah that does not exist means the database
    // was replaced by an incompatible one. Nothing to resume to, so say nothing.
    if (surah == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        WirdiMetrics.space4,
        WirdiMetrics.space2,
      ),
      child: Card(
        child: InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            Routes.reading,
            arguments: ReadingArguments(
              surahNumber: surah.number,
              ayahNumber: position.ayahNumber,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(WirdiMetrics.space4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Continue reading',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: WirdiMetrics.space1),
                      Text(
                        '${surah.nameTransliterated} '
                        '${position.surahNumber}:${position.ayahNumber}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
