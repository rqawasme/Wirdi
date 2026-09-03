import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'domain/collection_id.dart';
import 'dev/dev_screen.dart';
import 'screens/about_screen.dart';
import 'screens/collections_screen.dart';
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
  /// Home. The app is for doing a wird; the mushaf is a tap away from here
  /// rather than the other way round.
  static const String collections = '/';

  static const String player = '/player';
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
  static Route<void>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.collections:
        return _page(settings, (BuildContext _) => const CollectionsScreen());

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

  static MaterialPageRoute<void> _page(
    RouteSettings settings,
    WidgetBuilder builder,
  ) {
    return MaterialPageRoute<void>(builder: builder, settings: settings);
  }
}
