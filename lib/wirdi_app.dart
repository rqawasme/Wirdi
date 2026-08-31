import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/settings.dart';
import 'routes.dart';
import 'theme/theme.dart';
import 'widgets/failure_screen.dart';

/// The app shell: both themes, and whatever the settings say to show.
///
/// The theme is built from the settings' typography, so the two user text
/// multipliers reach every screen through [Theme] rather than being threaded
/// down by hand.
class WirdiApp extends ConsumerWidget {
  const WirdiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WirdiSettings> settings = ref.watch(settingsProvider);
    // Falling back to the defaults rather than waiting means the first frame
    // is already themed correctly for a user who has never changed anything,
    // and only the multipliers snap into place once the read returns.
    final WirdiSettings resolved = settings.value ?? const WirdiSettings();
    final WirdiTypography typography = resolved.typography;

    // A settings read that fails is not something to run past on defaults:
    // it means user.db is unreadable, and everything the app remembers is
    // going to silently not work.
    if (settings case AsyncError(
      :final Object error,
      :final StackTrace stackTrace,
    )) {
      return MaterialApp(
        title: 'Wirdi',
        debugShowCheckedModeBanner: false,
        theme: WirdiTheme.light(),
        darkTheme: WirdiTheme.dark(),
        home: FailureScreen(
          title: 'Could not read settings',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }

    return MaterialApp(
      title: 'Wirdi',
      debugShowCheckedModeBanner: false,
      theme: WirdiTheme.light(typography: typography),
      darkTheme: WirdiTheme.dark(typography: typography),
      themeMode: resolved.themeMode,
      // A plain Navigator, no routing package — see Routes. There is no
      // loading gate: the theme falls back to the default typography for the
      // one frame the settings read takes, and the surah list shows its own
      // progress while the 114 rows arrive.
      initialRoute: Routes.surahList,
      onGenerateRoute: WirdiRouter.onGenerateRoute,
    );
  }
}

/// [FailureScreen] wrapped in its own [MaterialApp], for a failure that
/// happens before there is an app to put it in.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    super.key,
    required this.error,
    required this.stackTrace,
  });

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wirdi',
      debugShowCheckedModeBanner: false,
      theme: WirdiTheme.light(),
      darkTheme: WirdiTheme.dark(),
      home: FailureScreen(
        title: 'Wirdi could not start',
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}
