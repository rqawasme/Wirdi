import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/player_haptics.dart';
import '../player/tasbih_counter.dart';
import '../providers/data_providers.dart';
import '../providers/settings.dart';
import '../theme/theme.dart';
import '../widgets/failure_screen.dart';

/// The tasbih: one number, one tap target, and a way back to zero.
///
/// A counter with nothing attached to it. There is no dhikr on this screen, no
/// target to reach and no collection behind it — the number goes up on every
/// tap and keeps whatever it has reached until somebody resets it, including
/// across a tab switch and across a restart of the app. That is what a
/// hand-held tasbih does, and it is the whole of what this does.
///
/// It is the counting screen the wird player is not: the player counts
/// *something*, a step at a time, and stops when the wird is done. When the
/// thing being counted is not in the app — a tasbih after prayer, a salawat
/// count somebody is keeping for themselves — this is the tab for it.
///
/// **Nothing here animates**, which is the player's rule and holds for the
/// same reason: a number that eases into place is a number running behind the
/// thumb. Feedback is haptic, through the same [PlayerHaptics] and the same
/// settings switch.
class TasbihScreen extends ConsumerStatefulWidget {
  const TasbihScreen({super.key});

  @override
  ConsumerState<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends ConsumerState<TasbihScreen> {
  late final PlayerHaptics _haptics;
  late final Future<TasbihCounter> _opening;
  late final AppLifecycleListener _lifecycle;

  TasbihCounter? _counter;

  @override
  void initState() {
    super.initState();
    _haptics = PlayerHaptics(
      enabled: ref.read(settingsProvider).value?.haptics ?? true,
    );
    _opening = TasbihCounter.open(
      user: ref.read(userRepositoryProvider),
      haptics: _haptics,
    ).then(_attach);
    // This tab is alive for as long as the app is: it lives in the shell's
    // IndexedStack, so dispose only runs on the way out of the app entirely.
    // Backgrounding is therefore the save that matters, not disposal.
    _lifecycle = AppLifecycleListener(
      onInactive: _flush,
      onPause: _flush,
      onDetach: _flush,
    );
  }

  /// Takes ownership of the counter once it has read its stored count.
  TasbihCounter _attach(TasbihCounter counter) {
    if (!mounted) {
      counter.dispose();
      return counter;
    }
    _counter = counter;
    return counter;
  }

  void _flush() {
    final TasbihCounter? counter = _counter;
    if (counter != null) unawaited(counter.flush());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // Writes whatever is pending on the way out.
    _counter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The switch can move while this tab is alive, and the haptics object
    // outlives any one build, so this is a live setting rather than one read
    // when the tab was first shown.
    ref.listen<AsyncValue<WirdiSettings>>(settingsProvider, (
      AsyncValue<WirdiSettings>? previous,
      AsyncValue<WirdiSettings> next,
    ) {
      final bool? enabled = next.value?.haptics;
      if (enabled != null) _haptics.enabled = enabled;
    });

    return FutureBuilder<TasbihCounter>(
      future: _opening,
      builder: (BuildContext context, AsyncSnapshot<TasbihCounter> snapshot) {
        if (snapshot.hasError) {
          return FailureScreen(
            title: 'Could not open the tasbih',
            error: snapshot.error!,
            stackTrace: snapshot.stackTrace ?? StackTrace.empty,
          );
        }
        final TasbihCounter? counter = snapshot.data;
        // Blank rather than a spinner: this is one read of one settings row,
        // so a progress indicator would be a flash of chrome nobody has time
        // to read, on the tab that is meant to be instant.
        if (counter == null) return const SizedBox.shrink();

        return ListenableBuilder(
          listenable: counter,
          builder: (BuildContext context, Widget? child) =>
              _Tasbih(counter: counter),
        );
      },
    );
  }
}

/// The screen, rebuilt on every tap.
class _Tasbih extends StatelessWidget {
  const _Tasbih({required this.counter});

  final TasbihCounter counter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: _TapToCount(counter: counter)),
        _Controls(counter: counter),
      ],
    );
  }
}

/// Everything above the controls, as one tap target.
///
/// Opaque hit testing over the whole area, for the player's reason: at speed
/// the thumb lands wherever it lands, and a counter that ignores a tap because
/// it missed the numeral is a counter you stop trusting. No ripple — an ink
/// splash on every tap is animation, on a surface that must not have any.
class _TapToCount extends StatelessWidget {
  const _TapToCount({required this.counter});

  final TasbihCounter counter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final ColorScheme colors = theme.colorScheme;

    return Semantics(
      button: true,
      // Announced on every tap, which is what makes the count usable without
      // looking: the number is the value, and "Count" is what the gesture
      // does.
      liveRegion: true,
      label: 'Count',
      value: '${counter.count}',
      onTap: counter.increment,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: counter.increment,
          child: Padding(
            padding: const EdgeInsets.all(WirdiMetrics.space6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Shrunk to fit rather than wrapped or clipped: the numeral is
                // 72dp before the OS text scale touches it, and a count in the
                // thousands at the largest accessibility size is wider than a
                // phone. Scaling down keeps it one line and still the largest
                // thing on the screen.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${counter.count}',
                      style: type.tasbihCount.copyWith(color: colors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: WirdiMetrics.space4),
                Text(
                  'Tap anywhere to count',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Undo and reset, outside the counting area.
///
/// Outside it for the reason the player's undo is: they have to be somewhere a
/// thumb counting at speed cannot reach by accident. Both are disabled at zero
/// rather than hidden, so the bar does not change shape as the count starts.
class _Controls extends StatelessWidget {
  const _Controls({required this.counter});

  final TasbihCounter counter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: WirdiMetrics.hairline,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WirdiMetrics.space4,
          vertical: WirdiMetrics.space2,
        ),
        child: Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: counter.isEmpty ? null : counter.decrement,
              icon: const Icon(Icons.undo, size: WirdiMetrics.space5),
              label: const Text('Undo'),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: counter.isEmpty
                  ? null
                  : () => _reset(context, counter),
              icon: const Icon(Icons.refresh, size: WirdiMetrics.space5),
              label: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }

  /// Asks first. Resetting throws away however long somebody has been
  /// counting, and the button for it sits a thumb's width from a target that
  /// is being tapped at speed — the same argument that keeps "Start over" in
  /// the player's overflow menu, answered here with a question instead,
  /// because on this screen reset is the only other thing there is to do.
  Future<void> _reset(BuildContext context, TasbihCounter counter) async {
    final int count = counter.count;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reset the count?'),
        content: Text(
          'This takes $count back to zero. Nothing keeps it — the tasbih has '
          'no history.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) counter.reset();
  }
}
