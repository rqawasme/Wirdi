import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is the type of a ProviderScope override; flutter_riverpod
// exports it from misc.dart rather than its main library.
import 'package:flutter_riverpod/misc.dart' show Override;

import 'data/wirdi_data.dart';
import 'providers/data_providers.dart';
import 'providers/reminders.dart';
import 'reminders/local_notification_scheduler.dart';
import 'reminders/reminder_scheduler.dart';
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
    final ReminderScheduler reminders = await _openReminders();
    runApp(
      ProviderScope(
        overrides: <Override>[
          wirdiDataProvider.overrideWithValue(data),
          reminderSchedulerProvider.overrideWithValue(reminders),
        ],
        child: const WirdiApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Wirdi failed to start: $error\n$stackTrace');
    runApp(StartupFailureApp(error: error, stackTrace: stackTrace));
  }
}

/// The phone's notifications, or none if they could not be set up.
///
/// Unlike the databases, this is not a reason to refuse to start: everything
/// else in the app works without reminders, and the commit sheet already says
/// so when the phone will not show them.
Future<ReminderScheduler> _openReminders() async {
  try {
    return await LocalNotificationScheduler.initialize();
  } catch (error, stackTrace) {
    debugPrint('Wirdi could not set up reminders: $error\n$stackTrace');
    return const NoReminderScheduler();
  }
}
