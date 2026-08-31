import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings.dart';
import '../theme/theme.dart';
import '../widgets/text_size_slider.dart';

/// The dev screen's controls, pinned below the samples.
///
/// Below rather than in a sheet on purpose: a modal would cover the text you
/// are trying to judge, and the sliders are only useful if the Quran is still
/// on screen while the thumb moves. Collapsible, because six controls take
/// enough room to matter on a phone.
///
/// Every control writes through [SettingsController], so all of it survives a
/// hot restart.
class DevControlPanel extends ConsumerStatefulWidget {
  const DevControlPanel({super.key, required this.settings});

  final WirdiSettings settings;

  @override
  ConsumerState<DevControlPanel> createState() => _DevControlPanelState();
}

class _DevControlPanelState extends ConsumerState<DevControlPanel> {
  bool _expanded = true;

  SettingsController get _controller => ref.read(settingsProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final WirdiSettings settings = widget.settings;

    return Material(
      color: scheme.surfaceContainer,
      // Echoes the bottom sheet: the panel arrives out of the bottom edge, so
      // it is rounded at the top and square where it meets it.
      borderRadius: WirdiMetrics.sheet,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // The hairline where the panel meets the samples above it.
            const Divider(height: 0),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: WirdiMetrics.space5,
                  vertical: WirdiMetrics.space3,
                ),
                child: Row(
                  children: <Widget>[
                    Text('Controls', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.expand_more : Icons.expand_less,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    WirdiMetrics.space5,
                    0,
                    WirdiMetrics.space5,
                    WirdiMetrics.space4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextSizeSlider(
                        label: 'Arabic',
                        // The slider shows pixels because that is what you are
                        // judging; what gets stored is the multiplier, so the
                        // choice survives the type scale moving underneath it.
                        nominalSize: WirdiTypography.quranVerseSize,
                        scale: settings.arabicScale,
                        min: 18,
                        max: 40,
                        onChanged: (double scale, {required bool commit}) =>
                            _controller.setArabicScale(scale, commit: commit),
                      ),
                      TextSizeSlider(
                        label: 'Translation',
                        nominalSize: WirdiTypography.translationSize,
                        scale: settings.translationScale,
                        min: 12,
                        max: 22,
                        onChanged: (double scale, {required bool commit}) =>
                            _controller.setTranslationScale(
                              scale,
                              commit: commit,
                            ),
                      ),
                      const SizedBox(height: WirdiMetrics.space2),
                      SettingChoice<ThemeMode>(
                        label: 'Theme',
                        value: settings.themeMode,
                        options: const <ThemeMode, String>{
                          ThemeMode.light: 'Light',
                          ThemeMode.dark: 'Dark',
                        },
                        onChanged: _controller.setThemeMode,
                      ),
                      const SizedBox(height: WirdiMetrics.space3),
                      SettingChoice<bool>(
                        label: 'Quran colour',
                        value: settings.quranInGold,
                        options: const <bool, String>{
                          false: 'Cedar ink',
                          true: 'Gold',
                        },
                        onChanged: _controller.setQuranInGold,
                      ),
                      const SizedBox(height: WirdiMetrics.space3),
                      SettingChoice<ArabicFace>(
                        label: 'Quran face',
                        value: settings.arabicFace,
                        options: const <ArabicFace, String>{
                          ArabicFace.notoNaskh: 'Noto Naskh',
                          ArabicFace.amiriQuran: 'Amiri Quran',
                        },
                        onChanged: _controller.setArabicFace,
                      ),
                      const SizedBox(height: WirdiMetrics.space3),
                      SettingChoice<bool>(
                        label: 'Bracketed words',
                        value: settings.dimBrackets,
                        options: const <bool, String>{
                          true: 'Dimmed',
                          false: 'Plain',
                        },
                        onChanged: _controller.setDimBrackets,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
