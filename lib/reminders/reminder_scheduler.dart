import 'reminder_plan.dart';

/// What the app asks of the phone's notifications. Nothing more.
///
/// An interface so that everything above it — the commit sheet, the settings
/// switch, the sync that lays reminders out — can be tested without a
/// platform channel, and so that the plugin behind it appears in exactly one
/// file: `local_notification_scheduler.dart`.
abstract interface class ReminderScheduler {
  /// Whether reminders can be shown, asking the user if they have not been
  /// asked yet.
  ///
  /// Called when somebody turns a reminder on, and never at launch: the
  /// system prompt makes sense next to the switch that caused it and nowhere
  /// else. Once refused, both platforms answer false without asking again.
  Future<bool> requestPermission();

  /// Opens the phone's own notification settings for this app — the only
  /// place a refusal can be undone.
  Future<void> openSystemSettings();

  /// Replaces every scheduled reminder with [reminders].
  ///
  /// Wholesale rather than incremental: the plan is cheap to work out and
  /// short, and a replacement cannot leave a reminder behind for a commitment
  /// that has since gone.
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Fires when a reminder is tapped while the app is running.
  ///
  /// A tap that launches the app does not come through here: a cold start
  /// already opens on Home, which is where a reminder leads.
  Stream<void> get taps;
}

/// Reminders that go nowhere.
///
/// The default, so that a widget test does not need a platform channel to
/// pump a screen with a commit sheet on it. `main` replaces it with the real
/// one.
final class NoReminderScheduler implements ReminderScheduler {
  const NoReminderScheduler();

  /// Nothing can be shown, so nothing is allowed.
  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {}

  @override
  Stream<void> get taps => const Stream<void>.empty();
}
