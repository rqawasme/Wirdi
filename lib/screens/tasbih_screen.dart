import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/dhikr_editing.dart' show countInputFormatters;
import '../player/player_haptics.dart';
import '../player/tasbih_counter.dart';
import '../providers/data_providers.dart';
import '../providers/settings.dart';
import '../theme/theme.dart';
import '../widgets/failure_screen.dart';
import '../widgets/voussoir_stripe.dart';

/// The tasbih: one number, one tap target, and a way back to zero — with a
/// goal, if somebody wants one.
///
/// A counter with nothing attached to it. There is no dhikr on this screen and
/// no collection behind it — the number goes up on every tap and keeps
/// whatever it has reached until somebody resets it, including across a tab
/// switch and across a restart of the app. That is what a hand-held tasbih
/// does.
///
/// The goal is the marker bead on the string. Set one and a stripe under the
/// number fills toward it, the tap that reaches it knocks twice, and so does
/// every multiple of it after — and the count carries on through all of them.
/// Leave it unset and the screen is the bare counter it always was.
///
/// It is the counting screen the wird player is not: the player counts
/// *something*, a step at a time, and stops when the wird is done. When the
/// thing being counted is not in the app — a tasbih after prayer, a salawat
/// count somebody is keeping for themselves — this is the tab for it.
///
/// **The number never animates.** A number that eases into place is a number
/// running behind the thumb, which is the player's rule and holds for the same
/// reason. What moves is the moment of reaching the goal — see [_TapToCount] —
/// and it moves around the number rather than holding it back. Feedback on
/// every tap is haptic, through the same [PlayerHaptics] and the same settings
/// switch.
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
/// splash on every tap is a flash of motion on every count, which is the one
/// place this screen keeps still.
///
/// ## Reaching the goal
///
/// The tap that lands on the goal, or on a multiple of it, swells the number
/// and the stripe once and lets them settle back, over one
/// [WirdiMotion.completion] beat. Scale only, and painted rather than laid
/// out, so nothing around them moves, and the numeral has already changed on
/// the frame of the tap — the swell happens to the new number, it does not
/// wait to show it. The next tap lands while it is settling and simply counts.
///
/// A reader who has turned animations off in the OS, and a theme whose
/// completion beat is zero, get the same screen with nothing swelling: the
/// two knocks and the caption say it on their own.
class _TapToCount extends StatefulWidget {
  const _TapToCount({required this.counter});

  final TasbihCounter counter;

  /// How wide the goal's stripe is. A third or so of the screen's width either
  /// side of the number on a phone: wide enough to read as a bar at a glance,
  /// narrow enough to sit under the number rather than across the screen like
  /// the rule under the app bar.
  static const double stripeWidth = 240;

  /// At most one segment per logical pixel of [stripeWidth]. A goal of a
  /// thousand is not a thousand rectangles painted on every tap; it is a
  /// stripe that moves every fourth one, and the numeral above it moves on
  /// all of them.
  static const int maxStripeSegments = 240;

  /// How far the number and the stripe swell at the peak, as a fraction of
  /// their size. Enough to see out of the corner of an eye that is on the
  /// beads rather than the screen; not enough to read as a bounce.
  static const double numeralSwell = 0.08;
  static const double stripeSwell = 0.67;

  @override
  State<_TapToCount> createState() => _TapToCountState();
}

class _TapToCountState extends State<_TapToCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(vsync: this);

  /// Up quickly and back down slowly: the peak is the tap, and settling is
  /// most of the beat. Standard easing either way; nothing overshoots.
  late final Animation<double> _swell =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 0,
            end: 1,
          ).chain(CurveTween(curve: WirdiMotion.easingDecelerate)),
          weight: 30,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: 0,
          ).chain(CurveTween(curve: WirdiMotion.easing)),
          weight: 70,
        ),
      ]).animate(_arrival);

  /// The counter's [TasbihCounter.goalArrivals] as of the last swell, so a
  /// rebuild for any other reason — undo, a new goal, a theme change — is not
  /// mistaken for an arrival.
  late int _arrivals = widget.counter.goalArrivals;

  @override
  void initState() {
    super.initState();
    widget.counter.addListener(_onCounter);
  }

  @override
  void didUpdateWidget(_TapToCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.counter == widget.counter) return;
    oldWidget.counter.removeListener(_onCounter);
    widget.counter.addListener(_onCounter);
    _arrivals = widget.counter.goalArrivals;
  }

  @override
  void dispose() {
    widget.counter.removeListener(_onCounter);
    _arrival.dispose();
    super.dispose();
  }

  /// Listened to rather than read in build, because starting an animation is
  /// a side effect, and build runs for reasons that are not taps.
  void _onCounter() {
    final int arrivals = widget.counter.goalArrivals;
    if (arrivals == _arrivals || !mounted) return;
    _arrivals = arrivals;

    final Duration beat = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Theme.of(context).extension<WirdiMotion>()!.completion;
    if (beat == Duration.zero) return;
    // From the start each time: a goal small enough to come round again while
    // the last swell is settling swells again, rather than being swallowed.
    _arrival.duration = beat;
    unawaited(_arrival.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final ColorScheme colors = theme.colorScheme;
    final TasbihCounter counter = widget.counter;
    final int? goal = counter.goal;

    return Semantics(
      button: true,
      // Announced on every tap, which is what makes the count usable without
      // looking: the number is the value, and "Count" is what the gesture
      // does. The goal rides along in the value, so reaching it is announced
      // on the tap that reaches it.
      liveRegion: true,
      label: 'Count',
      value: _semanticValue(counter),
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
                  child: AnimatedBuilder(
                    animation: _swell,
                    builder: (BuildContext context, Widget? child) =>
                        Transform.scale(
                          scale: 1 + _TapToCount.numeralSwell * _swell.value,
                          child: child,
                        ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${counter.count}',
                        style: type.tasbihCount.copyWith(color: colors.primary),
                      ),
                    ),
                  ),
                ),
                if (goal != null) ...<Widget>[
                  const SizedBox(height: WirdiMetrics.space4),
                  AnimatedBuilder(
                    animation: _swell,
                    builder: (BuildContext context, Widget? child) =>
                        Transform.scale(
                          scaleY: 1 + _TapToCount.stripeSwell * _swell.value,
                          child: child,
                        ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _TapToCount.stripeWidth,
                      ),
                      child: _stripe(counter, goal),
                    ),
                  ),
                  const SizedBox(height: WirdiMetrics.space3),
                  _GoalCaption(counter: counter),
                ],
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

  /// The round so far, filling toward the goal.
  ///
  /// Counted rather than given a fraction, for the reason
  /// [VoussoirStripe.counted] gives. Past [_TapToCount.maxStripeSegments] the
  /// round is scaled down in whole numbers, quantised down, so the last
  /// segment lights on the goal and not a tap before it.
  static Widget _stripe(TasbihCounter counter, int goal) {
    final int segments = goal < _TapToCount.maxStripeSegments
        ? goal
        : _TapToCount.maxStripeSegments;
    return VoussoirStripe.counted(
      lit: counter.roundTaps * segments ~/ goal,
      of: segments,
    );
  }

  static String _semanticValue(TasbihCounter counter) {
    final int? goal = counter.goal;
    if (goal == null) return '${counter.count}';
    return switch (counter.goalsReached) {
      0 => '${counter.count} of $goal',
      1 => '${counter.count}, goal of $goal reached',
      final int times => '${counter.count}, goal of $goal reached $times times',
    };
  }
}

/// What the stripe means, in words: how far there is to go, and then how many
/// times the goal has come round.
///
/// "Goal reached" and not a congratulation, and the same line at the
/// hundredth multiple as at the first bar the count on it: nothing escalates,
/// which is the rule the home tiles and the finished wird keep too.
class _GoalCaption extends StatelessWidget {
  const _GoalCaption({required this.counter});

  final TasbihCounter counter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextStyle? style = theme.textTheme.bodyMedium;
    final int reached = counter.goalsReached;

    final Widget caption = reached == 0
        ? Text(
            'of ${counter.goal}',
            key: ValueKey<String>('of ${counter.goal}'),
            style: style?.copyWith(color: colors.onSurfaceVariant),
          )
        : Row(
            key: ValueKey<String>('reached $reached'),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Brick, as the player's finished band marks its check: the one
              // mark on the screen that says something has been reached.
              Icon(
                Icons.check,
                size: WirdiMetrics.space5,
                color: colors.primary,
              ),
              const SizedBox(width: WirdiMetrics.space1),
              Text(
                reached == 1 ? 'Goal reached' : 'Goal reached ×$reached',
                style: style?.copyWith(color: colors.onSurface),
              ),
            ],
          );

    // A short fade between one line and the next. The caption changes on the
    // goal's tap and not between, so it is never a fade on the counting path.
    final Duration fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : theme.extension<WirdiMotion>()!.standard;
    return AnimatedSwitcher(
      duration: fade,
      switchInCurve: WirdiMotion.easingDecelerate,
      switchOutCurve: WirdiMotion.easingAccelerate,
      child: caption,
    );
  }
}

/// Undo, the goal and reset, outside the counting area.
///
/// Outside it for the reason the player's undo is: they have to be somewhere a
/// thumb counting at speed cannot reach by accident. Undo and reset are
/// disabled at zero rather than hidden, so the bar does not change shape as
/// the count starts; the goal can be set at any count.
class _Controls extends StatelessWidget {
  const _Controls({required this.counter});

  final TasbihCounter counter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? goal = counter.goal;

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
            const SizedBox(width: WirdiMetrics.space2),
            // The middle takes what is left, so a six-digit goal at a large
            // text size shortens its own label rather than pushing reset off
            // the edge.
            Expanded(
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: () => _chooseGoal(context, counter),
                  icon: const Icon(
                    Icons.flag_outlined,
                    size: WirdiMetrics.space5,
                  ),
                  label: Text(
                    goal == null ? 'Goal' : 'Goal $goal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: WirdiMetrics.space2),
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

  Future<void> _chooseGoal(BuildContext context, TasbihCounter counter) async {
    final ({int? goal})? choice = await showModalBottomSheet<({int? goal})>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _GoalSheet(current: counter.goal),
    );
    if (choice != null) counter.setGoal(choice.goal);
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

/// Which goal: none, one of the four people count to most, or their own.
///
/// Closes on the choice, unlike the commitment sheet, because there is only
/// the one question. Pops with a record rather than the bare number, so that
/// choosing "No goal" and dismissing the sheet are not both null.
class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.current});

  final int? current;

  /// Thirty-three for the tasbih after prayer, a hundred for the adhkar the
  /// hadith count in hundreds, and a thousand for a long sitting. Anything
  /// else is the field's to hold — a goal saved before a preset was dropped
  /// opens there, so it is kept rather than lost.
  static const List<int> presets = <int>[33, 100, 1000];

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  /// Holds the current goal when it is one of somebody's own, so it can be
  /// adjusted from where it is rather than typed again.
  late final TextEditingController _custom = TextEditingController(
    text: switch (widget.current) {
      final int goal when !_GoalSheet.presets.contains(goal) => '$goal',
      _ => '',
    },
  );

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  int? get _customGoal {
    final int? goal = int.tryParse(_custom.text);
    return TasbihCounter.isValidGoal(goal) ? goal : null;
  }

  void _choose(int? goal) => Navigator.pop(context, (goal: goal));

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int? custom = _customGoal;

    // A check, in the same quiet ink as the commitment sheet's: the ink is the
    // app's way of saying which one is on.
    Widget? check(bool on) =>
        on ? Icon(Icons.check, color: colors.onSurfaceVariant) : null;

    return Padding(
      // The custom field is the last thing on the sheet, so the keyboard
      // pushes the sheet up rather than covering what is being typed.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  WirdiMetrics.space4,
                  WirdiMetrics.space5,
                  WirdiMetrics.space4,
                  WirdiMetrics.space1,
                ),
                child: Text('Goal', style: theme.textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  WirdiMetrics.space4,
                  0,
                  WirdiMetrics.space4,
                  WirdiMetrics.space2,
                ),
                child: Text(
                  'Two knocks when the count reaches it, and again at every '
                  'multiple. The count carries on past it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                title: const Text('No goal'),
                trailing: check(widget.current == null),
                onTap: () => _choose(null),
              ),
              for (final int preset in _GoalSheet.presets)
                ListTile(
                  title: Text('$preset'),
                  trailing: check(widget.current == preset),
                  onTap: () => _choose(preset),
                ),
              Padding(
                padding: const EdgeInsets.all(WirdiMetrics.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _custom,
                        keyboardType: TextInputType.number,
                        // The same digits and the same ceiling as every other
                        // count field, so none of them holds a number another
                        // would refuse.
                        inputFormatters: countInputFormatters,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Your own',
                        ),
                        onChanged: (String _) => setState(() {}),
                        onSubmitted: (String _) {
                          if (custom != null) _choose(custom);
                        },
                      ),
                    ),
                    const SizedBox(width: WirdiMetrics.space3),
                    Padding(
                      // Level with the field's text rather than its label.
                      padding: const EdgeInsets.only(top: WirdiMetrics.space2),
                      child: FilledButton(
                        onPressed: custom == null
                            ? null
                            : () => _choose(custom),
                        child: const Text('Set'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
