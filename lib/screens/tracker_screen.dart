import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings.dart';
import '../providers/streak.dart';
import '../theme/theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/streak_panel.dart';

/// Days in a row, and a calendar of this month.
///
/// That is the whole tab, and it is the whole feature. No tiers, no personal
/// best, no "at risk", nothing that gets louder as the number grows: the
/// standard streak pattern is engineered to produce guilt, and pointing that
/// at somebody's devotional life is a different thing from pointing it at a
/// language app.
///
/// The panel moved here from the top of the collections list, which is where
/// it lived before there was anywhere better for it.
class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden entirely when the setting is off — not greyed, not collapsed to a
    // number. Absent while the settings load rather than appearing and then
    // vanishing, which would show it to exactly the person who asked not to
    // see it.
    final bool show = ref.watch(settingsProvider).value?.showStreak ?? false;
    if (!show) {
      return const EmptyState(
        title: 'The streak is off',
        body: 'Turn "Show streak" back on in Settings to see it here.',
      );
    }

    final StreakView? view = ref.watch(streakViewProvider).value;
    if (view == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
      children: <Widget>[StreakPanel(view: view)],
    );
  }
}
