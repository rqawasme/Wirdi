import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is the type of a ProviderScope override; flutter_riverpod
// exports it from misc.dart rather than its main library.
import 'package:flutter_riverpod/misc.dart' show Override;

import 'data/wirdi_data.dart';
import 'providers/data_providers.dart';
import 'wirdi_app.dart';

/// Opens both databases, then runs the app with them.
///
/// [WirdiData.open] is where the bundled `content.db` is copied out of the
/// asset bundle into the application support directory — on a first launch,
/// four and a half megabytes of it — and where the SQLite in use and the
/// content schema version are both checked. All three can fail, none of them
/// can be recovered from at runtime, and every one of them is a build problem
/// rather than a user problem. So they are caught here and put on the screen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final WirdiData data = await WirdiData.open();
    runApp(
      ProviderScope(
        overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
        child: const WirdiApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Wirdi failed to start: $error\n$stackTrace');
    runApp(StartupFailureApp(error: error, stackTrace: stackTrace));
  }
}
