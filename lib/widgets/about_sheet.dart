import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_version.dart';
import '../domain/content.dart';
import '../providers/reading.dart';
import '../theme/theme.dart';
import 'voussoir_stripe.dart';

/// Opens the about sheet.
///
/// A sheet rather than a screen. About is read once, on the way to nothing:
/// pushing a route for it puts it in the back stack of whatever the reader was
/// actually doing, and a sheet dismisses back to where they were.
Future<void> showAboutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController controller) =>
          AboutContent(controller: controller),
    ),
  );
}

/// Sources, credits and licences.
///
/// Required before release and easier to write now than to remember later. The
/// Quran source and translation edition are read out of `content.db`'s `meta`
/// table rather than written here, so a credit cannot drift from the database it
/// is crediting. The font licences are the actual bundled OFL files — the
/// licence requires that they travel with the fonts, so they are assets and
/// this shows them verbatim rather than paraphrasing.
class AboutContent extends ConsumerWidget {
  const AboutContent({super.key, this.controller});

  /// The sheet's own scroll controller, so dragging the list past its top
  /// drags the sheet rather than overscrolling inside it.
  final ScrollController? controller;

  /// The bundled licences, by the family they cover.
  static const Map<String, String> fontLicences = <String, String>{
    WirdiFonts.quran: 'assets/fonts/OFL-AmiriQuran.txt',
    WirdiFonts.naskh: 'assets/fonts/OFL-NotoNaskhArabic.txt',
    WirdiFonts.latin: 'assets/fonts/OFL-Inter.txt',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ContentMetadata> metadata = ref.watch(
      contentMetadataProvider,
    );

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.space5,
        WirdiMetrics.space5,
        WirdiMetrics.space5,
        WirdiMetrics.space6,
      ),
      children: <Widget>[
        const _Section(title: 'Wirdi'),
        _Entry(label: 'App version', value: appVersion),
        // Stated the same way as the versions above it, because it is the same
        // kind of fact. No logo, no link, no thanks-for-using-our-app.
        const _Entry(label: 'Developed by', value: 'Safi Solutions'),
        if (metadata.value case final ContentMetadata meta) ...<Widget>[
          _Entry(label: 'Content version', value: meta.contentVersion),
          _Entry(
            label: 'Content build',
            // The first eight characters are enough to tell two builds apart
            // and short enough to read out over a support conversation.
            value: meta.contentChecksum.isEmpty
                ? 'unknown'
                : meta.contentChecksum.substring(0, 8),
          ),
        ],

        const SizedBox(height: WirdiMetrics.space6),
        const _Section(title: 'Quran text'),
        if (metadata.value case final ContentMetadata meta)
          _Entry(label: 'Source', value: meta.quranSource),
        const _Body(
          'The Uthmani text and its juz, hizb and sajdah metadata are '
          'imported from the Quranic Universal Library (qul.tarteel.ai) and '
          'normalised without alteration. Consult QUL for the terms covering '
          'redistribution of the text.',
        ),

        const SizedBox(height: WirdiMetrics.space6),
        const _Section(title: 'Translation'),
        if (metadata.value case final ContentMetadata meta)
          _Entry(label: 'Edition', value: meta.translationEdition),
        // The name itself comes from the database above, which spells it
        // "Saheeh"; printing it again here in the other spelling would just
        // look like an error.
        const _Body('Published by Abul-Qasim Publishing House.'),

        const SizedBox(height: WirdiMetrics.space6),
        const _Section(title: 'Fonts'),
        const _Body(
          'All three are bundled with the app and licensed under the SIL Open '
          'Font License. Nothing is fetched at runtime.',
        ),
        const SizedBox(height: WirdiMetrics.space2),
        for (final MapEntry<String, String> entry in fontLicences.entries)
          _LicenceTile(family: entry.key, asset: entry.value),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: WirdiMetrics.space2),
          const VoussoirStripe.rule(),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: WirdiMetrics.space1),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Opens one font's licence in a bottom sheet.
class _LicenceTile extends StatelessWidget {
  const _LicenceTile({required this.family, required this.asset});

  final String family;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(family),
      subtitle: const Text('SIL Open Font License'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _show(context),
    );
  }

  void _show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (BuildContext context, ScrollController controller) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: WirdiMetrics.space5,
                    vertical: WirdiMetrics.space2,
                  ),
                  child: Text(family, style: theme.textTheme.titleLarge),
                ),
                const VoussoirStripe.rule(),
                Expanded(
                  child: FutureBuilder<String>(
                    future: rootBundle.loadString(asset),
                    builder:
                        (BuildContext context, AsyncSnapshot<String> snapshot) {
                          final String? text = snapshot.data;
                          if (text == null) {
                            return const SizedBox.shrink();
                          }
                          return SingleChildScrollView(
                            controller: controller,
                            padding: const EdgeInsets.all(WirdiMetrics.space5),
                            child: SelectableText(
                              text,
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
