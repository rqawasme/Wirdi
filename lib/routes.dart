import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'domain/collection_id.dart';
import 'dev/dev_screen.dart';
import 'screens/about_screen.dart';
import 'screens/app_shell.dart';
import 'screens/collection_edit_screen.dart';
import 'screens/pickers/ayah_picker_screen.dart';
import 'screens/pickers/dhikr_picker_screen.dart';
import 'screens/pickers/surah_picker_screen.dart';
import 'screens/reading_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/surah_list_screen.dart';
import 'screens/wird_player_screen.dart';

/// The app's route names.
///
/// A plain [Navigator] with named routes, and no routing package. Six screens
/// and two arguments between them do not need one, and nothing here has to be
/// addressable from outside the app yet — when deep linking becomes a
/// requirement it will bring its own constraints, and choosing a router before
/// then is choosing without them.
abstract final class Routes {
  /// The four-tab shell: Home, Collections, Dhikr, Tracker. The app opens
  /// here, on Home. Every top-level screen is a tab of this one rather than a
  /// route of its own, so the navigation bar never appears over something
  /// pushed on top of it.
  ///
  /// The mushaf is a tap away in the app bar rather than a fifth tab: the app
  /// is for doing a wird, and four tabs is the ceiling.
  static const String shell = '/';

  static const String player = '/player';

  /// Editing one of the user's own collections.
  static const String collectionEdit = '/collection/edit';

  /// The three item pickers. Each is pushed to answer one question and popped
  /// with a `List<PickedItem>`, or with nothing if it was backed out of.
  static const String pickSurah = '/pick/surah';
  static const String pickAyah = '/pick/ayah';
  static const String pickDhikr = '/pick/dhikr';

  static const String surahList = '/quran';
  static const String reading = '/reading';
  static const String settings = '/settings';
  static const String about = '/about';

  /// The phase 3 rendering harness. Registered in debug builds only — see
  /// [WirdiRouter.onGenerateRoute].
  static const String dev = '/dev';
}

/// Which collection a [Routes.player] push is opening.
@immutable
final class PlayerArguments {
  const PlayerArguments({required this.collectionId});

  final CollectionId collectionId;
}

/// Which collection a [Routes.collectionEdit] push is editing.
///
/// A [UserCollectionId] and not a [CollectionId]: a built-in cannot be edited,
/// and the way to say that is to make it impossible to ask for.
@immutable
final class CollectionEditArguments {
  const CollectionEditArguments({required this.collectionId});

  final UserCollectionId collectionId;
}

/// Where a [Routes.reading] push is going.
@immutable
final class ReadingArguments {
  const ReadingArguments({required this.surahNumber, this.ayahNumber});

  final int surahNumber;

  /// The ayah to open at, or null to start at the top.
  final int? ayahNumber;
}

abstract final class WirdiRouter {
  /// Builds the route for [settings].
  ///
  /// Unknown names fall through to null, which makes [Navigator] throw with the
  /// name in the message — better than silently landing on the surah list and
  /// leaving a typo to be discovered by a user.
  static Route<Object?>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.shell:
        return _page(settings, (BuildContext _) => const AppShell());

      case Routes.player:
        final Object? arguments = settings.arguments;
        if (arguments is! PlayerArguments) {
          throw ArgumentError.value(
            arguments,
            'settings.arguments',
            'pushing ${Routes.player} needs PlayerArguments',
          );
        }
        return _page(
          settings,
          (BuildContext _) =>
              WirdPlayerScreen(collectionId: arguments.collectionId),
        );

      case Routes.collectionEdit:
        final Object? arguments = settings.arguments;
        if (arguments is! CollectionEditArguments) {
          throw ArgumentError.value(
            arguments,
            'settings.arguments',
            'pushing ${Routes.collectionEdit} needs CollectionEditArguments',
          );
        }
        return _page(
          settings,
          (BuildContext _) =>
              CollectionEditScreen(collectionId: arguments.collectionId),
        );

      case Routes.pickSurah:
        return _page(settings, (BuildContext _) => const SurahPickerScreen());

      case Routes.pickAyah:
        return _page(settings, (BuildContext _) => const AyahPickerScreen());

      case Routes.pickDhikr:
        return _page(settings, (BuildContext _) => const DhikrPickerScreen());

      case Routes.surahList:
        return _page(settings, (BuildContext _) => const SurahListScreen());

      case Routes.reading:
        final Object? arguments = settings.arguments;
        if (arguments is! ReadingArguments) {
          throw ArgumentError.value(
            arguments,
            'settings.arguments',
            'pushing ${Routes.reading} needs ReadingArguments',
          );
        }
        return _page(
          settings,
          (BuildContext _) => ReadingScreen(
            surahNumber: arguments.surahNumber,
            initialAyahNumber: arguments.ayahNumber,
          ),
        );

      case Routes.settings:
        return _page(settings, (BuildContext _) => const SettingsScreen());

      case Routes.about:
        return _page(settings, (BuildContext _) => const AboutScreen());

      // Not registered in a release build, so a stray push cannot reach it even
      // if a debug-only entry point were ever left on screen by accident.
      case Routes.dev when kDebugMode:
        return _page(settings, (BuildContext _) => const DevScreen());
    }
    return null;
  }

  /// Typed as `Object?` rather than `void` because the pickers pop with an
  /// answer. A route that returns nothing simply never pops with one.
  static MaterialPageRoute<Object?> _page(
    RouteSettings settings,
    WidgetBuilder builder,
  ) {
    return MaterialPageRoute<Object?>(builder: builder, settings: settings);
  }
}
