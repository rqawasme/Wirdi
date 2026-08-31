import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories.dart';
import '../theme/typography.dart';
import 'data_providers.dart';

/// The keys this app writes into `user.db`'s `settings` table.
///
/// Namespaced, and stable: these strings are persisted, so renaming one loses
/// whatever the user had chosen. Everything under `dev.` belongs to the
/// throwaway dev screen and goes when it does.
abstract final class SettingKeys {
  static const String arabicScale = 'text.arabic_scale';
  static const String translationScale = 'text.translation_scale';
  static const String themeMode = 'theme.mode';

  static const String devQuranInGold = 'dev.quran_in_gold';
  static const String devArabicFace = 'dev.arabic_face';
  static const String devDimBrackets = 'dev.dim_brackets';
}

/// Everything the app remembers between launches, resolved and typed.
///
/// Read as a whole rather than key by key, so a widget cannot rebuild against
/// half of a change.
@immutable
final class WirdiSettings {
  const WirdiSettings({
    this.arabicScale = 1,
    this.translationScale = 1,
    this.themeMode = ThemeMode.light,
    this.quranInGold = true,
    this.arabicFace = ArabicFace.quran,
    this.dimBrackets = true,
  });

  /// Multiplies [WirdiTypography.quranVerseSize], and the dhikr size with it.
  final double arabicScale;

  /// Multiplies [WirdiTypography.translationSize], and the dhikr caption with
  /// it.
  final double translationScale;

  final ThemeMode themeMode;

  /// Dev screen: Quran text in `tertiary` gold, or in `onSurface` cedar ink.
  final bool quranInGold;

  /// Dev screen: which face the Quran samples are set in.
  final ArabicFace arabicFace;

  /// Dev screen: whether the translation's bracketed interpolations are
  /// dimmed to `onSurfaceVariant`.
  final bool dimBrackets;

  /// The typography these settings resolve to.
  WirdiTypography get typography => WirdiTypography(
    arabicScale: arabicScale,
    translationScale: translationScale,
  );

  WirdiSettings copyWith({
    double? arabicScale,
    double? translationScale,
    ThemeMode? themeMode,
    bool? quranInGold,
    ArabicFace? arabicFace,
    bool? dimBrackets,
  }) {
    return WirdiSettings(
      arabicScale: arabicScale ?? this.arabicScale,
      translationScale: translationScale ?? this.translationScale,
      themeMode: themeMode ?? this.themeMode,
      quranInGold: quranInGold ?? this.quranInGold,
      arabicFace: arabicFace ?? this.arabicFace,
      dimBrackets: dimBrackets ?? this.dimBrackets,
    );
  }
}

/// Loads the settings once and writes changes back through [UserRepository].
///
/// Every setter takes a `commit` flag. A slider being dragged calls with
/// `commit: false` on each frame, so the change is visible immediately, and
/// once with `commit: true` when the thumb is released. Persisting on every
/// frame would put sixty writes a second through SQLite to store a value the
/// user has not finished choosing yet.
class SettingsController extends AsyncNotifier<WirdiSettings> {
  @override
  Future<WirdiSettings> build() async {
    final UserRepository repository = ref.watch(userRepositoryProvider);

    // Defaults come from the const constructor, so a key that has never been
    // written and a key that cannot be parsed behave the same way.
    const WirdiSettings defaults = WirdiSettings();
    return WirdiSettings(
      arabicScale:
          _double(await repository.setting(SettingKeys.arabicScale)) ??
          defaults.arabicScale,
      translationScale:
          _double(await repository.setting(SettingKeys.translationScale)) ??
          defaults.translationScale,
      themeMode:
          _themeMode(await repository.setting(SettingKeys.themeMode)) ??
          defaults.themeMode,
      quranInGold:
          _bool(await repository.setting(SettingKeys.devQuranInGold)) ??
          defaults.quranInGold,
      arabicFace:
          _arabicFace(await repository.setting(SettingKeys.devArabicFace)) ??
          defaults.arabicFace,
      dimBrackets:
          _bool(await repository.setting(SettingKeys.devDimBrackets)) ??
          defaults.dimBrackets,
    );
  }

  Future<void> setArabicScale(double value, {bool commit = true}) {
    return _set(
      SettingKeys.arabicScale,
      value.toStringAsFixed(4),
      (WirdiSettings s) => s.copyWith(arabicScale: value),
      commit: commit,
    );
  }

  Future<void> setTranslationScale(double value, {bool commit = true}) {
    return _set(
      SettingKeys.translationScale,
      value.toStringAsFixed(4),
      (WirdiSettings s) => s.copyWith(translationScale: value),
      commit: commit,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) {
    return _set(
      SettingKeys.themeMode,
      mode.name,
      (WirdiSettings s) => s.copyWith(themeMode: mode),
    );
  }

  Future<void> setQuranInGold(bool value) {
    return _set(
      SettingKeys.devQuranInGold,
      value.toString(),
      (WirdiSettings s) => s.copyWith(quranInGold: value),
    );
  }

  Future<void> setArabicFace(ArabicFace face) {
    return _set(
      SettingKeys.devArabicFace,
      face.name,
      (WirdiSettings s) => s.copyWith(arabicFace: face),
    );
  }

  Future<void> setDimBrackets(bool value) {
    return _set(
      SettingKeys.devDimBrackets,
      value.toString(),
      (WirdiSettings s) => s.copyWith(dimBrackets: value),
    );
  }

  /// Applies [update] to the current value immediately, then writes [value]
  /// under [key] unless this is an uncommitted step of a gesture.
  Future<void> _set(
    String key,
    String value,
    WirdiSettings Function(WirdiSettings) update, {
    bool commit = true,
  }) async {
    final WirdiSettings? current = state.value;
    // Nothing to update against: the load has not finished, and a write now
    // would be overwritten by it anyway.
    if (current == null) return;

    state = AsyncData<WirdiSettings>(update(current));
    if (!commit) return;
    await ref.read(userRepositoryProvider).setSetting(key, value);
  }

  static double? _double(String? raw) =>
      raw == null ? null : double.tryParse(raw);

  static bool? _bool(String? raw) => switch (raw) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  static ThemeMode? _themeMode(String? raw) {
    for (final ThemeMode mode in ThemeMode.values) {
      if (mode.name == raw) return mode;
    }
    return null;
  }

  static ArabicFace? _arabicFace(String? raw) {
    for (final ArabicFace face in ArabicFace.values) {
      if (face.name == raw) return face;
    }
    return null;
  }
}

final AsyncNotifierProvider<SettingsController, WirdiSettings>
settingsProvider = AsyncNotifierProvider<SettingsController, WirdiSettings>(
  SettingsController.new,
  name: 'settings',
);
