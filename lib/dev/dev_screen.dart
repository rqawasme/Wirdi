import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content_database.dart' show expectedContentSchemaVersion;
import '../data/sqlite_runtime.dart';
import '../domain/collection.dart';
import '../domain/content.dart';
import '../providers/settings.dart';
import '../theme/theme.dart';
import '../widgets/failure_screen.dart';
import '../widgets/translation_text.dart';
import '../widgets/voussoir_stripe.dart';
import 'dev_controls.dart';
import 'dev_samples.dart';

/// A rendering harness, not a screen.
///
/// Everything under `lib/dev/` is deleted before release. It exists to answer
/// two questions that cannot be answered from a spec — whether Quran text
/// should be gold or cedar ink, and whether Amiri Quran holds up against Noto
/// Naskh — by putting the real text, out of the real database, at every size
/// and in both faces, on a real device.
///
/// The controls write through the ordinary settings path, so what you choose
/// here survives a hot restart the same way it would survive a user closing
/// the app.
class DevScreen extends ConsumerWidget {
  const DevScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ResolvedSample>> samples = ref.watch(
      quranSamplesProvider,
    );
    final List<Dhikr> adhkar =
        ref.watch(dhikrSamplesProvider).value ?? const <Dhikr>[];
    final CollectionSummary? dhikrCollection = ref
        .watch(dhikrCollectionProvider)
        .value;
    final WirdiSettings settings =
        ref.watch(settingsProvider).value ?? const WirdiSettings();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Type check'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: switch (samples) {
        AsyncError(:final Object error, :final StackTrace stackTrace) =>
          FailureScreen(
            title: 'Could not read the samples',
            error: error,
            stackTrace: stackTrace,
          ),
        AsyncData(:final List<ResolvedSample> value) => _SampleList(
          samples: value,
          adhkar: adhkar,
          collection: dhikrCollection,
          settings: settings,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: DevControlPanel(settings: settings),
    );
  }
}

class _SampleList extends StatelessWidget {
  const _SampleList({
    required this.samples,
    required this.adhkar,
    required this.collection,
    required this.settings,
  });

  final List<ResolvedSample> samples;
  final List<Dhikr> adhkar;
  final CollectionSummary? collection;
  final WirdiSettings settings;

  @override
  Widget build(BuildContext context) {
    // Two extra leading items: the voussoir stripe in both of its modes, then
    // the dhikr samples.
    const int leading = 2;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
      itemCount: samples.length + leading,
      itemBuilder: (BuildContext context, int index) {
        return switch (index) {
          0 => const _VoussoirSection(),
          1 => _DhikrSection(adhkar: adhkar, collection: collection),
          _ => _SampleBlock(
            resolved: samples[index - leading],
            settings: settings,
          ),
        };
      },
    );
  }
}

/// The dhikr styles, against the only real adhkar in the database.
///
/// Set in Noto Naskh at [WirdiTypography.dhikrSizeRatio] of the Quran size, so
/// this is where the Arabic multiplier's effect on dhikr shows up, and where
/// the caption style under each one gets looked at.
class _DhikrSection extends StatelessWidget {
  const _DhikrSection({required this.adhkar, required this.collection});

  final List<Dhikr> adhkar;
  final CollectionSummary? collection;

  @override
  Widget build(BuildContext context) {
    if (adhkar.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const VoussoirStripe.rule(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WirdiMetrics.readingColumnPadding,
            vertical: WirdiMetrics.space5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Dhikr', style: theme.textTheme.titleLarge),
              if (collection case final CollectionSummary c) ...<Widget>[
                _Label(c.name),
                if (c.nameArabic case final String arabic) ...<Widget>[
                  const SizedBox(height: WirdiMetrics.space1),
                  // Arabic UI chrome: Noto Naskh 700, outside the reading
                  // multipliers, at the nav label size.
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(arabic, style: type.arabicChrome),
                  ),
                ],
              ],
              for (int i = 0; i < adhkar.length; i++) ...<Widget>[
                const SizedBox(height: WirdiMetrics.verseBlockSpacing),
                _Label(dhikrSamples[i].tests),
                const SizedBox(height: WirdiMetrics.space2),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(adhkar[i].textArabic, style: type.dhikr),
                ),
                const SizedBox(height: WirdiMetrics.space2),
                Text(adhkar[i].translation, style: type.translation),
                if (adhkar[i].transliteration case final String t) ...<Widget>[
                  const SizedBox(height: WirdiMetrics.space1),
                  Text(
                    t,
                    style: type.dhikrCaption.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The stripe in both modes, at a few fills, so the quantisation is visible.
class _VoussoirSection extends StatelessWidget {
  const _VoussoirSection();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.readingColumnPadding,
        WirdiMetrics.space6,
        WirdiMetrics.readingColumnPadding,
        WirdiMetrics.space6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _RuntimeInfo(),
          const SizedBox(height: WirdiMetrics.space6),
          Text('Voussoir stripe', style: theme.textTheme.titleLarge),
          const SizedBox(height: WirdiMetrics.space4),
          _Label('rule — ${VoussoirStripe.ruleHeight.toInt()}dp'),
          const SizedBox(height: WirdiMetrics.space2),
          const VoussoirStripe.rule(),
          const SizedBox(height: WirdiMetrics.space5),
          _Label('progress — ${VoussoirStripe.progressHeight.toInt()}dp'),
          for (final double value in <double>[
            0,
            0.25,
            0.5,
            0.75,
            1,
          ]) ...<Widget>[
            const SizedBox(height: WirdiMetrics.space2),
            VoussoirStripe.progress(value: value),
          ],
        ],
      ),
    );
  }
}

/// Which SQLite is actually underneath, read at runtime.
///
/// `package:sqlite3` is supposed to ship its own build on every platform; on
/// Android in particular, falling through to the system library means a SQLite
/// that trails by years and differs by device. `assertSupportedSqlite` fails
/// startup when that happens, but the version is worth being able to read off
/// a real device rather than inferred from a build log.
class _RuntimeInfo extends StatelessWidget {
  const _RuntimeInfo();

  @override
  Widget build(BuildContext context) {
    return _Label(
      'SQLite ${sqliteVersion.libVersion} '
      '(${sqliteVersion.versionNumber})  ·  '
      'content schema $expectedContentSchemaVersion',
    );
  }
}

class _SampleBlock extends StatelessWidget {
  const _SampleBlock({required this.resolved, required this.settings});

  final ResolvedSample resolved;
  final WirdiSettings settings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    final TextStyle arabic = type
        .quranVerseIn(settings.arabicFace)
        .copyWith(
          color: settings.quranInGold ? scheme.tertiary : scheme.onSurface,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const VoussoirStripe.rule(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WirdiMetrics.readingColumnPadding,
            vertical: WirdiMetrics.space5,
          ),
          // Stretch, not start: a Directionality only sets the direction of
          // the paragraph inside it. If the box it lays out in is only as wide
          // as the glyphs, right-to-left text still ends up parked against the
          // left margin, correctly ordered and in the wrong place.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SampleHeader(sample: resolved.sample),
              for (final Ayah ayah in resolved.ayahs) ...<Widget>[
                const SizedBox(height: WirdiMetrics.space4),
                // Genuinely right-to-left, not right-aligned: the shaper needs
                // the paragraph direction to order runs, place the ayah number
                // and break lines correctly. Aligning a left-to-right paragraph
                // to the right only moves the wrong answer across the page.
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(ayah.textUthmani, style: arabic),
                ),
                const SizedBox(height: WirdiMetrics.space3),
                TranslationText(
                  ayah.translation,
                  style: type.translation.copyWith(color: scheme.onSurface),
                  dimBracketedText: settings.dimBrackets,
                ),
                if (ayah != resolved.ayahs.last)
                  const SizedBox(
                    height:
                        WirdiMetrics.verseBlockSpacing - WirdiMetrics.space4,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SampleHeader extends StatelessWidget {
  const _SampleHeader({required this.sample});

  final QuranSample sample;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(sample.reference, style: theme.textTheme.titleMedium),
        const SizedBox(width: WirdiMetrics.space2),
        Expanded(
          child: Text(
            sample.tests,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
