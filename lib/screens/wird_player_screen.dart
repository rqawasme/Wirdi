import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/item_labels.dart';
import '../domain/collection.dart';
import '../domain/collection_id.dart';
import '../domain/content.dart';
import '../domain/playback_step.dart';
import '../player/player_haptics.dart';
import '../player/wird_player.dart';
import '../providers/data_providers.dart';
import '../providers/reading.dart';
import '../providers/settings.dart';
import '../theme/theme.dart';
import '../widgets/ayah_block.dart';
import '../widgets/dhikr_block.dart';
import '../widgets/failure_screen.dart';
import '../widgets/plate.dart';
import '../widgets/translation_text.dart';
import '../widgets/voussoir_stripe.dart';

/// The counter. The screen the app is for.
///
/// It owns a [WirdPlayer] for as long as it is on screen and rebuilds off it
/// through a [ListenableBuilder], so a tap goes straight from the gesture to
/// the object that holds the count and back out as a repaint. Nothing on the
/// counting path goes through a provider, a stream or an animation.
///
/// **Nothing here animates.** Not the count, not the stripe, not the band. That
/// is the one rule the whole screen is built around: at thirty-three
/// repetitions a counter that eases into position is a counter running behind
/// the thumb, and the lag is the entire experience. Feedback is haptic instead
/// — see [PlayerHaptics].
///
/// **One mechanic.** Every step counts the same way: the content area is the
/// tap target, whatever kind of step it is, and the band above the controls
/// says so in words. A surah is not an exception to that — it is a step whose
/// unit is one ayah, shown one at a time.
class WirdPlayerScreen extends ConsumerStatefulWidget {
  const WirdPlayerScreen({super.key, required this.collectionId});

  final CollectionId collectionId;

  @override
  ConsumerState<WirdPlayerScreen> createState() => _WirdPlayerScreenState();
}

class _WirdPlayerScreenState extends ConsumerState<WirdPlayerScreen> {
  late final PlayerHaptics _haptics;
  late final Future<WirdPlayer> _opening;
  late final AppLifecycleListener _lifecycle;

  WirdPlayer? _player;

  @override
  void initState() {
    super.initState();
    _haptics = PlayerHaptics(
      enabled: ref.read(settingsProvider).value?.haptics ?? true,
    );
    _opening = WirdPlayer.open(
      id: widget.collectionId,
      collections: ref.read(collectionRepositoryProvider),
      user: ref.read(userRepositoryProvider),
      haptics: _haptics,
    ).then(_attach);
    // Backgrounding is the last moment before the process might not come back,
    // and it is the one save that cannot wait for a debounce. onInactive fires
    // first on both platforms; the others are belt and braces, and flushing
    // twice writes once.
    _lifecycle = AppLifecycleListener(
      onInactive: _flush,
      onPause: _flush,
      onDetach: _flush,
    );
  }

  /// Takes ownership of the player once it has opened.
  WirdPlayer _attach(WirdPlayer player) {
    if (!mounted) {
      // Left before the databases answered. Nothing has been counted, so this
      // only releases the timer.
      player.dispose();
      return player;
    }
    _player = player;
    return player;
  }

  void _flush() {
    final WirdPlayer? player = _player;
    if (player != null) unawaited(player.flush());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // Writes whatever is pending on the way out: leaving the player is exactly
    // when the position needs to be durable.
    _player?.dispose();
    super.dispose();
  }

  /// Leaves the player, from the tap on the finished step.
  ///
  /// [maybePop] and nothing more: the player was pushed from Home or from the
  /// collections list, and it goes back to whichever of them opened it. Both
  /// of those refresh themselves when it does.
  void _leave() {
    unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    // The switch can move while the player is open, and the haptics object
    // outlives any one build, so this is a live setting rather than one read
    // at open.
    ref.listen<AsyncValue<WirdiSettings>>(settingsProvider, (
      AsyncValue<WirdiSettings>? previous,
      AsyncValue<WirdiSettings> next,
    ) {
      final bool? enabled = next.value?.haptics;
      if (enabled != null) _haptics.enabled = enabled;
    });

    return FutureBuilder<WirdPlayer>(
      future: _opening,
      builder: (BuildContext context, AsyncSnapshot<WirdPlayer> snapshot) {
        if (snapshot.hasError) {
          return FailureScreen(
            title: 'Could not open this wird',
            error: snapshot.error!,
            stackTrace: snapshot.stackTrace ?? StackTrace.empty,
          );
        }
        final WirdPlayer? player = snapshot.data;
        if (player == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return ListenableBuilder(
          listenable: player,
          builder: (BuildContext context, Widget? child) =>
              _Player(player: player, onLeave: _leave),
        );
      },
    );
  }
}

/// Everything below the app bar, rebuilt on every count.
///
/// The rebuild reaches the step's text, which sounds wasteful on a counting
/// path and is not: the [TextSpan] compares equal across it, so the paragraph
/// is neither re-shaped nor re-laid-out. What actually changes is the count,
/// the stripe, and whether two buttons are enabled.
class _Player extends StatelessWidget {
  const _Player({required this.player, required this.onLeave});

  final WirdPlayer player;

  /// What the tap on the finished step does.
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final CollectionItemEntry? item = player.currentItem;

    return Scaffold(
      appBar: AppBar(
        title: Text(player.collection.collection.name),
        actions: <Widget>[
          // In the overflow rather than on the bar: starting over throws away
          // a session, and it should take two deliberate taps to do that.
          PopupMenuButton<void>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            itemBuilder: (BuildContext context) => <PopupMenuEntry<void>>[
              PopupMenuItem<void>(
                onTap: player.isEmpty ? null : player.startOver,
                child: const Text('Start over'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(VoussoirStripe.progressHeight),
          // The identity moment: the wird itself, as an arch filling in. One
          // segment per step up to thirty-three, proportionally past that, and
          // the current step's own share counted inside its segment. The
          // step's indicator is the number below it — the stripe measures the
          // whole thing, or it measures neither.
          child: VoussoirStripe.progress(
            value: player.collectionProgress,
            segments: player.stripeSegments,
          ),
        ),
      ),
      body: player.isEmpty
          ? const _EmptyCollection()
          // The finished step is a step: the same header, the same tap target,
          // the same band naming the gesture and the same controls below it.
          // What changes is what each of them says — nothing about the shape
          // of the screen, because the last thing a reciter does here should
          // not be the one thing that looks unlike everything else.
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (player.finished)
                  _CompleteHeader(player: player)
                else
                  _StepHeader(player: player, item: item),
                Expanded(
                  // Keyed on the whole position, so each step, each round and
                  // each unit gets a fresh subtree: without it the scroll
                  // position and an opened benefits panel carry over, and the
                  // next ayah arrives already scrolled half way down. A round
                  // is a reading of the item from the start, so it starts at
                  // the top the same way a new step does.
                  key: ValueKey<String>(
                    player.finished
                        ? 'complete'
                        : 'step-${player.stepIndex}-${player.currentCount}'
                              '-${player.unitIndex}',
                  ),
                  child: player.finished
                      ? _CompleteStep(player: player, onLeave: onLeave)
                      : _StepContent(player: player, item: item),
                ),
                _AdvanceBand(player: player),
                _Controls(player: player),
              ],
            ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WirdiMetrics.space6),
        child: Text(
          'There is nothing in this collection to recite.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// What this step is, and where in it the reciter is.
///
/// Fixed above the content rather than scrolling with it: it is what the eye
/// comes back to between repetitions, and a line you have to scroll to find is
/// a line you stop looking at. The count itself is not here — it lives in the
/// band, under the thumb — so this is purely "what am I on".
class _StepHeader extends ConsumerWidget {
  const _StepHeader({required this.player, required this.item});

  final WirdPlayer player;
  final CollectionItemEntry? item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    final PlaybackStep step = player.step;
    final (String name, String? kind) = _title(ref, item);
    final String? position = _positionLine(player);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.readingColumnPadding,
        WirdiMetrics.space4,
        WirdiMetrics.readingColumnPadding,
        WirdiMetrics.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (kind != null)
                      Padding(
                        // Two lines of one label rather than two labels: the
                        // gap is optical, and the 4dp step would read as a
                        // separate line of chrome.
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          kind,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: quiet,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: WirdiMetrics.space3),
              // Always, including at one: a step that repeats once still says
              // so, and a plate that comes and goes is worse than a quiet x1.
              Plate(label: '×${step.count}'),
            ],
          ),
          if (position != null)
            Padding(
              padding: const EdgeInsets.only(top: WirdiMetrics.space3),
              child: Text(
                position,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: quiet,
                  fontFeatures: const <FontFeature>[
                    // The line changes on every tap, and a proportional 1 is
                    // narrower than a 7: without this it shifts sideways as it
                    // counts.
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// What this step is called, and what kind of thing it is under that.
  ///
  /// Delegated to [itemHeading] so that the item sheet on the contents screen
  /// calls the same ayah the same thing this does.
  (String, String?) _title(WidgetRef ref, CollectionItemEntry? item) =>
      itemHeading(item, surahName: (int number) => _surahName(ref, number));

  /// The transliterated surah name, for an ayah that names its surah.
  ///
  /// Already loaded for the surah list, and only wanted for the name.
  String _surahName(WidgetRef ref, int number) {
    final Surah? surah = ref
        .watch(surahsProvider)
        .value
        ?.where((Surah s) => s.number == number)
        .firstOrNull;
    return surah?.nameTransliterated ?? 'Surah $number';
  }
}

/// Every position this step is in, on one line, smaller unit first.
///
/// One line and one place: the plate carries the step's count and nothing
/// else, so there is never a second number to reconcile it with.
String? _positionLine(WirdPlayer player) {
  final PlaybackStep step = player.step;
  // The repetition being recited now rather than the ones behind it, and never
  // past the target: the completing tap holds the last step at its full count
  // for the beat the screen stays.
  final int round = math.min(player.currentCount + 1, step.count);

  if (step.isMultiUnit) {
    final String ayah = 'Ayah ${player.unitIndex + 1} of ${step.unitCount}';
    return step.isInRepeatBlock
        ? '$ayah · round ${step.repetition} of ${step.repetitionsTotal}'
        : '$ayah · round $round of ${step.count}';
  }
  if (step.count > 1) return 'Repeat $round of ${step.count}';
  if (step.isInRepeatBlock) {
    final (int item, int items) = _itemInRound(player);
    return 'Round ${step.repetition} of ${step.repetitionsTotal} '
        '· item $item of $items';
  }
  // One unit, said once, on its own: there is no position to state.
  return null;
}

/// Where this step sits among the items of one pass through its repeat block,
/// as (which item, how many).
///
/// Read off the flattened list rather than stored on the step: a block emits
/// its items consecutively, one whole pass at a time, so the run of steps
/// around this one that share its round number is that pass.
(int, int) _itemInRound(WirdPlayer player) {
  final List<PlaybackStep> steps = player.steps;
  final PlaybackStep step = player.step;
  bool sameRound(PlaybackStep other) =>
      other.repetition == step.repetition &&
      other.repetitionsTotal == step.repetitionsTotal;

  int first = step.index;
  while (first > 0 && sameRound(steps[first - 1])) {
    first--;
  }
  int last = step.index;
  while (last < steps.length - 1 && sameRound(steps[last + 1])) {
    last++;
  }
  return (step.index - first + 1, last - first + 1);
}

/// The header of the finished step: what was just finished, and how much of it
/// there was.
///
/// The step header's own shape — a title with a quieter line under it — so the
/// top of the screen does not rearrange itself at the end of a wird. What it
/// drops is the plate: a step that repeats is `x3`, and the wird as a whole is
/// not a step that repeats.
class _CompleteHeader extends StatelessWidget {
  const _CompleteHeader({required this.player});

  final WirdPlayer player;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WirdiMetrics.readingColumnPadding,
        WirdiMetrics.space4,
        WirdiMetrics.readingColumnPadding,
        WirdiMetrics.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Wird complete', style: theme.textTheme.titleMedium),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _recited(player),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `12 steps · 87 repetitions`.
///
/// Counted rather than praised. It is the wird the reciter just said, stated
/// in the two units the screen has been using all the way through — the step
/// counter in the controls and the count in the band — so the line is a total
/// of numbers they already watched go by.
String _recited(WirdPlayer player) {
  final int steps = player.steps.length;
  final int repetitions = player.totalRepetitions;
  final String stepWord = steps == 1 ? 'step' : 'steps';
  final String repetitionWord = repetitions == 1 ? 'repetition' : 'repetitions';
  return '$steps $stepWord · $repetitions $repetitionWord';
}

/// The finished step.
///
/// A step like the others: the content area is the tap target, the band above
/// the controls says so, and the tap does the next thing — which here is to
/// leave. There is no button, because no other step has one and the end of a
/// wird is a poor place to teach a new gesture.
///
/// Three lines, centred in the area a step's text would fill, and the largest
/// type the app sets outside the mushaf: `الْحَمْدُ لِلَّهِ`, one sentence,
/// and the run of days under it. There is nothing to read here, so there is
/// no column to read down — the words are the screen.
///
/// The first two read the same at three days as at three hundred, and the
/// third counts the run without remarking on it: the home tile's vocabulary,
/// which is the one place in the app already allowed to encourage. Nothing
/// escalates, nothing is negative, and the mark itself is the app's own
/// material — the stripe above, solid brick because the wird filled it.
class _CompleteStep extends StatefulWidget {
  const _CompleteStep({required this.player, required this.onLeave});

  final WirdPlayer player;

  final VoidCallback onLeave;

  @override
  State<_CompleteStep> createState() => _CompleteStepState();
}

class _CompleteStepState extends State<_CompleteStep> {
  /// The tap that finished the wird is one of a run of taps, and at a tasbih's
  /// pace the next one is already on its way down. Without this the reciter
  /// would tap straight through the end of their wird and never see it.
  ///
  /// [WirdiMotion.completion] because it is the same beat it always was — the
  /// screen holding still at the end of a wird — spent guarding the step
  /// instead of counting down to a dismissal the reciter did not ask for.
  Timer? _grace;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready || _grace != null) return;
    final Duration beat = Theme.of(
      context,
    ).extension<WirdiMotion>()!.completion;
    if (beat == Duration.zero) {
      _ready = true;
      return;
    }
    _grace = Timer(beat, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _grace?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String? run = _run(widget.player.completedStreak);

    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    return _TapToCount(
      onTap: _ready ? widget.onLeave : null,
      label: 'Close',
      centred: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            'الْحَمْدُ لِلَّهِ',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: type.completionArabic.copyWith(color: colors.primary),
          ),
          const SizedBox(height: WirdiMetrics.space4),
          Text(
            'Consistency is the key. May it be accepted, Ameen.',
            textAlign: TextAlign.center,
            style: type.completionLine.copyWith(color: colors.onSurface),
          ),
          if (run != null)
            Padding(
              padding: const EdgeInsets.only(top: WirdiMetrics.space3),
              child: Text(
                run,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// This collection's run of days, in the home tile's own words.
  ///
  /// Past tense and closing, because the wird is done. Null until the read
  /// behind the completion lands, and null at zero — which the completion
  /// just written makes unreachable, but a number that says a run of none
  /// would be worse than no line at all.
  String? _run(int? streak) => switch (streak) {
    null || 0 => null,
    1 => 'A day begun.',
    final int days => '$days days and counting.',
  };
}

/// The count, and the gesture that changes it, named in words.
///
/// The screen's one affordance. The content area above has counted since the
/// app had a counter and nothing on it ever said so; this is where a reader
/// finds that out — a fixed band, never scrolled past, never hidden, and not
/// itself a target, because the target is the whole area above it.
///
/// No icon: the glyph set has nothing that means "tap the page", and inventing
/// one would say less than the sentence does. Nothing here animates, the
/// numeral least of all, and the number is stated rather than commented on —
/// there is no "last one" and no colour change as it runs down.
class _AdvanceBand extends StatelessWidget {
  const _AdvanceBand({required this.player});

  /// Fixed, and deep enough to read as a part of the screen rather than a
  /// strip of chrome. It does not move as the count runs down.
  static const double height = 88;

  final WirdPlayer player;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final ColorScheme colors = theme.colorScheme;

    return Semantics(
      container: true,
      liveRegion: true,
      label: _semanticLabel(),
      child: ExcludeSemantics(
        child: Container(
          // A floor rather than a fixed height: 88 at every ordinary text
          // size, and room to grow instead of overflow for a reader who has
          // turned the OS scale all the way up.
          constraints: const BoxConstraints(minHeight: height),
          padding: const EdgeInsets.symmetric(
            horizontal: WirdiMetrics.readingColumnPadding,
            vertical: WirdiMetrics.space3,
          ),
          decoration: BoxDecoration(
            // A tonal step and a hairline, squared and flush to both edges.
            // No shadow, and no radius: it is a part of the screen, not a
            // card lying on it.
            color: colors.surfaceContainerHigh,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant,
                width: WirdiMetrics.hairline,
              ),
            ),
          ),
          // The same three slots on every step, the finished one included: the
          // brick figure, the word under it, and the line that names the
          // gesture. At the end the figure is a check rather than a numeral —
          // the band would say "0 left" otherwise, which reads as nothing
          // having been done at all — and the gesture it names is the way out.
          child: Row(
            children: <Widget>[
              if (player.finished)
                Icon(
                  Icons.check,
                  // Sized off the numeral it stands in for, so the band's
                  // first column is the same width at the end as all the way
                  // through it.
                  size: type.counter.fontSize,
                  color: colors.primary,
                )
              else
                Text(
                  '${player.remaining}',
                  style: type.counter.copyWith(color: colors.primary),
                ),
              const SizedBox(width: WirdiMetrics.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      player.finished ? 'done' : 'left',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      switch (player) {
                        WirdPlayer(finished: true) =>
                          'Tap anywhere above to close',
                        WirdPlayer(isMultiUnit: true) =>
                          'Tap anywhere above to go to the next ayah',
                        _ => 'Tap anywhere above to count',
                      },
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
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

  /// The live region: the count, where in the item the reciter is, and where
  /// in the wird. Announced on every tap, so it is the whole position.
  String _semanticLabel() {
    if (player.finished) return 'Wird complete. Tap anywhere above to close';
    final PlaybackStep step = player.step;
    final String left = step.count > 1
        ? '${player.remaining} left of ${step.count}'
        : '${player.remaining} left';
    final String unit = player.isMultiUnit
        ? ', ayah ${player.unitIndex + 1} of ${player.unitCount}'
        : '';
    return '$left$unit, step ${player.stepIndex + 1} of '
        '${player.steps.length}';
  }
}

/// The step itself, in the tap target every kind of step shares.
///
/// One branch, not three. The kind decides what is drawn and what a unit is —
/// a dhikr whole, an ayah whole, a surah one verse at a time — and never how
/// the reciter advances, so every kind is wrapped in the same [_TapToCount].
class _StepContent extends StatelessWidget {
  const _StepContent({required this.player, required this.item});

  final WirdPlayer player;
  final CollectionItemEntry? item;

  @override
  Widget build(BuildContext context) {
    // Bound to a local so the patterns promote: a field cannot be.
    final CollectionItemEntry? entry = item;
    // Named for what the tap does here, so a screen reader announces the
    // gesture rather than only offering it.
    final String label = player.isMultiUnit ? 'Next ayah' : 'Count';
    return switch (entry) {
      DhikrItem() => _TapToCount(
        onTap: player.increment,
        label: label,
        child: _DhikrStep(item: entry),
      ),
      AyahItem() => _TapToCount(
        onTap: player.increment,
        label: label,
        child: _AyahStep(item: entry),
      ),
      SurahItem() => _TapToCount(
        onTap: player.increment,
        label: label,
        child: _SurahStep(player: player, item: entry),
      ),
      // The step's entry is not in the collection any more. Resolution drops
      // items whose content has gone, so this is only reachable if the two
      // views of the collection disagree — worth saying rather than blanking.
      null => const _MissingStep(),
    };
  }
}

class _MissingStep extends StatelessWidget {
  const _MissingStep();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WirdiMetrics.space6),
        child: Text(
          'This item is no longer in the collection. Skip past it.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The content area, as one tap target.
///
/// Opaque hit testing over the whole area, including the margins and the empty
/// space below short text: at speed the thumb lands wherever it lands, and a
/// counter that ignores a tap because it missed the words is a counter you
/// stop trusting. Scrolling still works — a scrollable claims drags, not taps
/// — so a long ayah can be read and counted with the same thumb.
///
/// No ripple, deliberately. An ink splash on every tap is animation, on the
/// one surface that must not have any.
class _TapToCount extends StatelessWidget {
  const _TapToCount({
    required this.onTap,
    required this.label,
    required this.child,
    this.centred = false,
  });

  /// What the tap does. Counting on every step but the last; on the finished
  /// step, leaving — one mechanic, to the end of the wird and out of it.
  final VoidCallback? onTap;

  /// What the tap does, in the same words the band uses.
  final String label;

  /// Centre the child in the area rather than sitting it at the top.
  ///
  /// For the finished step, which is two short lines and no page to read: at
  /// the top they hang under the header with the screen empty below them.
  /// Every other step is a column of text that starts where text starts.
  final bool centred;

  final Widget child;

  static const EdgeInsets _padding = EdgeInsets.fromLTRB(
    WirdiMetrics.readingColumnPadding,
    0,
    WirdiMetrics.readingColumnPadding,
    WirdiMetrics.space6,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Two shapes, and the counting path keeps the plain one: a
        // [LayoutBuilder] on it would run its builder inside layout on every
        // tap, for a centring nothing on a step of text asks for.
        child: centred
            ? LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    padding: _padding,
                    // Still a scroll view: centred until the text outgrows the
                    // area, which at the largest accessibility sizes it does,
                    // and then it scrolls like everything else.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(
                          0,
                          constraints.maxHeight - _padding.vertical,
                        ),
                      ),
                      child: Center(child: child),
                    ),
                  );
                },
              )
            : SingleChildScrollView(padding: _padding, child: child),
      ),
    );
  }
}

/// A dhikr step: the Arabic, the translation, and what the collection says
/// about it.
class _DhikrStep extends ConsumerWidget {
  const _DhikrStep({required this.item});

  final DhikrItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool showTranslation =
        ref.watch(settingsProvider).value?.showTranslation ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DhikrBlock(dhikr: item.dhikr, showTranslation: showTranslation),
        _Note(note: item.note),
        _SourceLine(source: item.source),
        _Benefits(benefits: item.dhikr.benefits),
      ],
    );
  }
}

/// An ayah step: the same verse rendering the reading view uses. Which verse
/// it is is the step header's line, not a second one here.
class _AyahStep extends ConsumerWidget {
  const _AyahStep({required this.item});

  final AyahItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool showTranslation =
        ref.watch(settingsProvider).value?.showTranslation ?? true;
    final Ayah ayah = item.ayah;
    // Already loaded for the surah list, and only wanted for the name.
    final Surah? surah = ref
        .watch(surahsProvider)
        .value
        ?.where((Surah s) => s.number == ayah.surahNumber)
        .firstOrNull;
    final String name =
        surah?.nameTransliterated ?? 'Surah ${ayah.surahNumber}';

    // No reference line: the header above names the verse, and saying it twice
    // is saying it once too often.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AyahBlock(
          ayah: ayah,
          surahName: name,
          showTranslation: showTranslation,
        ),
        _Note(note: item.note),
      ],
    );
  }
}

/// A surah step: one ayah of it, the one the unit cursor is on.
///
/// Not a scroll of the whole surah any more. A surah is a sequence of units
/// recited a number of times, so the screen shows the unit — Al-Baqarah is 286
/// of them and a wall of them was never what was being recited from.
class _SurahStep extends ConsumerWidget {
  const _SurahStep({required this.player, required this.item});

  final WirdPlayer player;
  final SurahItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SurahReading> reading = ref.watch(
      surahReadingProvider(item.surah.number),
    );
    final bool showTranslation =
        ref.watch(settingsProvider).value?.showTranslation ?? true;

    return switch (reading) {
      // Said in the content area rather than as a [FailureScreen], which is a
      // Scaffold and cannot be laid out inside the scrolling tap target.
      AsyncError(:final Object error) => _ContentMessage(
        'Could not read surah ${item.surah.number}. $error',
      ),
      AsyncData(:final SurahReading value) => _SurahVerse(
        reading: value,
        unitIndex: player.unitIndex,
        note: item.note,
        showTranslation: showTranslation,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// The ayah the cursor is on, with the basmala above it at the start of a
/// reading.
class _SurahVerse extends StatelessWidget {
  const _SurahVerse({
    required this.reading,
    required this.unitIndex,
    required this.note,
    required this.showTranslation,
  });

  final SurahReading reading;
  final int unitIndex;
  final String? note;
  final bool showTranslation;

  @override
  Widget build(BuildContext context) {
    final List<Ayah> ayahs = reading.ayahs;
    // The content build verifies that every surah has the verses its ayah
    // count claims, so this is a guard on an index rather than a state with
    // anything to say.
    if (ayahs.isEmpty) return const SizedBox.shrink();
    final int index = unitIndex.clamp(0, ayahs.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // It belongs to the start of a reading, not to the surah, so it comes
        // back on every round. At-Tawbah has none, which the flag carries.
        if (reading.hasBismillahHeading && index == 0)
          BismillahHeading(text: reading.bismillah!),
        AyahBlock(
          ayah: ayahs[index],
          surahName: reading.surah.nameTransliterated,
          showTranslation: showTranslation,
        ),
        _Note(note: note),
      ],
    );
  }
}

/// Something to say where the content should be, inside the scrolling tap
/// target.
class _ContentMessage extends StatelessWidget {
  const _ContentMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WirdiMetrics.space6),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The per-collection rubric on an item: what this wird says about reciting
/// this one, as its author wrote it.
class _Note extends StatelessWidget {
  const _Note({required this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    final String? note = this.note;
    if (note == null || note.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: WirdiMetrics.space4),
      child: Container(
        padding: const EdgeInsets.all(WirdiMetrics.space3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: WirdiMetrics.card,
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: WirdiMetrics.hairline,
          ),
        ),
        child: Text(note, style: theme.textTheme.bodySmall),
      ),
    );
  }
}

/// Where a dhikr comes from.
///
/// Always shown when there is one, never behind a tap: sourcing is a trust
/// feature, and a reference you have to go looking for is a reference nobody
/// reads. It is hydrated onto the item during resolution, so showing it costs
/// no query.
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.source});

  final Source? source;

  @override
  Widget build(BuildContext context) {
    final Source? source = this.source;
    if (source == null) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final String grading = source.grading == null ? '' : ' · ${source.grading}';

    return Padding(
      padding: const EdgeInsets.only(top: WirdiMetrics.space4),
      child: Text(
        '${source.collection} ${source.reference}$grading',
        style: type.dhikrCaption.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// What is narrated about saying this dhikr, behind an expand.
///
/// Behind one because it is a paragraph, and a paragraph between the Arabic and
/// the next repetition is a paragraph in the way. Open, it stays open for the
/// step; the tap that opens it does not count, since the tile takes the gesture
/// before the counting area sees it.
class _Benefits extends StatefulWidget {
  const _Benefits({required this.benefits});

  final String? benefits;

  @override
  State<_Benefits> createState() => _BenefitsState();
}

class _BenefitsState extends State<_Benefits> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final String? benefits = widget.benefits;
    if (benefits == null || benefits.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color quiet = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: WirdiMetrics.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                size: WirdiMetrics.space5,
              ),
              label: const Text('Benefits'),
              style: TextButton.styleFrom(
                foregroundColor: quiet,
                padding: const EdgeInsets.symmetric(
                  horizontal: WirdiMetrics.space2,
                  vertical: WirdiMetrics.space1,
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(top: WirdiMetrics.space2),
              child: TranslationText(
                benefits,
                style: type.dhikrCaption.copyWith(color: quiet),
              ),
            ),
        ],
      ),
    );
  }
}

/// Undo, and manual movement between steps.
///
/// No advance button. Advancing is the content area, and the band above says
/// so; a second control for the same thing would be a second thing to hit by
/// accident and a second place for the count to disagree with itself.
///
/// Undo stays here, outside the counting area, because it has to be somewhere
/// a thumb counting at speed cannot reach by accident, and a labelled button in
/// its own bar is that place.
class _Controls extends StatelessWidget {
  const _Controls({required this.player});

  final WirdPlayer player;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color quiet = theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: WirdiMetrics.hairline,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            WirdiMetrics.space4,
            WirdiMetrics.space2,
            WirdiMetrics.space4,
            WirdiMetrics.space2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: player.canUndo ? player.decrement : null,
                    icon: const Icon(Icons.undo, size: WirdiMetrics.space5),
                    label: const Text('Undo'),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_outlined),
                    tooltip: 'Previous step',
                    onPressed: player.canSkipBackward
                        ? player.skipBackward
                        : null,
                  ),
                  Text(
                    '${player.stepIndex + 1} of ${player.steps.length}',
                    style: theme.textTheme.bodySmall?.copyWith(color: quiet),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_outlined),
                    tooltip: 'Next step',
                    onPressed: player.canSkipForward
                        ? player.skipForward
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
