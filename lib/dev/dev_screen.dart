import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content_database.dart' show expectedContentSchemaVersion;
import '../data/sqlite_runtime.dart';
import '../domain/content.dart';
import '../providers/settings.dart';
import '../theme/theme.dart';
import '../widgets/failure_screen.dart';
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
          settings: settings,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: DevControlPanel(settings: settings),
    );
  }
}

class _SampleList extends StatelessWidget {
  const _SampleList({required this.samples, required this.settings});

  final List<ResolvedSample> samples;
  final WirdiSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
      // One extra leading item: the voussoir stripe in both of its modes.
      itemCount: samples.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) return const _VoussoirSection();
        return _SampleBlock(resolved: samples[index - 1], settings: settings);
      },
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                _Translation(text: ayah.translation, settings: settings),
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

/// The translation, with the Saheeh International bracket convention either
/// dimmed or left plain.
///
/// Just over half of the 6,236 translations carry at least one bracketed span:
/// they are the interpolated words, the ones not in the Arabic. Whether that
/// should be visible in the typography at all is one of the things this screen
/// is for.
class _Translation extends StatelessWidget {
  const _Translation({required this.text, required this.settings});

  final String text;
  final WirdiSettings settings;

  static final RegExp _bracketed = RegExp(r'\[[^\]]*\]');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final TextStyle style = type.translation.copyWith(
      color: theme.colorScheme.onSurface,
    );

    if (!settings.dimBrackets) {
      return Text(text, style: style);
    }
    return Text.rich(
      TextSpan(children: _spans(theme.colorScheme.onSurfaceVariant)),
      style: style,
    );
  }

  List<InlineSpan> _spans(Color dim) {
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final RegExpMatch match in _bracketed.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match[0],
          style: TextStyle(color: dim),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
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
