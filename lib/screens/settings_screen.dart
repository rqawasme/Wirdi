import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/content.dart';
import '../providers/reading.dart';
import '../providers/settings.dart';
import '../theme/theme.dart';
import '../widgets/ayah_block.dart';
import '../widgets/text_size_slider.dart';
import '../widgets/voussoir_stripe.dart';

/// Reading size, translation, theme.
///
/// The preview sits above the sliders so that a size change is visible without
/// leaving the screen, and it is the real [AyahBlock] the reading view uses
/// rather than a mock-up of one — a preview that is not the thing being
/// previewed is a way to ship a surprise.
///
/// Nothing else on this screen responds to the sliders. Labels, headers and the
/// controls themselves are chrome and follow the OS accessibility text scale
/// only, which falls out of the type scale rather than being special-cased
/// here: the two multipliers reach the reading styles and no others.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WirdiSettings settings =
        ref.watch(settingsProvider).value ?? const WirdiSettings();
    final SettingsController controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
        children: <Widget>[
          const _Preview(),
          const VoussoirStripe.rule(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WirdiMetrics.space5,
              WirdiMetrics.space5,
              WirdiMetrics.space5,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextSizeSlider(
                  label: 'Arabic',
                  nominalSize: WirdiTypography.quranVerseSize,
                  scale: settings.arabicScale,
                  min: 18,
                  max: 40,
                  onChanged: (double scale, {required bool commit}) =>
                      controller.setArabicScale(scale, commit: commit),
                ),
                TextSizeSlider(
                  label: 'Translation',
                  nominalSize: WirdiTypography.translationSize,
                  scale: settings.translationScale,
                  min: 12,
                  max: 22,
                  onChanged: (double scale, {required bool commit}) =>
                      controller.setTranslationScale(scale, commit: commit),
                ),
                const SizedBox(height: WirdiMetrics.space2),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show translation'),
                  subtitle: const Text(
                    'Off leaves the page to the Arabic alone',
                  ),
                  value: settings.showTranslation,
                  onChanged: controller.setShowTranslation,
                ),
                const SizedBox(height: WirdiMetrics.space4),
                SettingChoice<ThemeMode>(
                  label: 'Theme',
                  value: settings.themeMode,
                  options: const <ThemeMode, String>{
                    ThemeMode.light: 'Light',
                    ThemeMode.dark: 'Dark',
                  },
                  onChanged: controller.setThemeMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One verse at the current sizes.
class _Preview extends ConsumerWidget {
  const _Preview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Ayah> ayah = ref.watch(previewAyahProvider);
    final bool showTranslation =
        ref.watch(settingsProvider).value?.showTranslation ?? true;

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(
        horizontal: WirdiMetrics.readingColumnPadding,
        vertical: WirdiMetrics.space5,
      ),
      child: switch (ayah) {
        AsyncData(:final Ayah value) => AyahBlock(
          ayah: value,
          surahName: 'Al-Fatihah',
          showTranslation: showTranslation,
        ),
        // Never an error worth a screen: a missing preview verse means the
        // content database is broken, which startup already refused to get
        // past.
        _ => const SizedBox(height: WirdiMetrics.space6),
      },
    );
  }
}
