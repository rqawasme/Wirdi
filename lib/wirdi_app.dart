import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dev/dev_screen.dart';
import 'providers/settings.dart';
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

    return MaterialApp(
      title: 'Wirdi',
      debugShowCheckedModeBanner: false,
      theme: WirdiTheme.light(typography: typography),
      darkTheme: WirdiTheme.dark(typography: typography),
      themeMode: resolved.themeMode,
      home: switch (settings) {
        AsyncError(:final Object error, :final StackTrace stackTrace) =>
          FailureScreen(
            title: 'Could not read settings',
            error: error,
            stackTrace: stackTrace,
          ),
        // One frame, over the launch screen. A spinner here would be a flash
        // of chrome, not a sign of progress.
        AsyncLoading() => const Scaffold(body: SizedBox.shrink()),
        _ => const DevScreen(),
      },
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
