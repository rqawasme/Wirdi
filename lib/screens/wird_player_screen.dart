import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../widgets/translation_text.dart';
import '../widgets/voussoir_stripe.dart';

/// The counter. The screen the app is for.
///
/// It owns a [WirdPlayer] for as long as it is on screen and rebuilds off it
/// through a [ListenableBuilder], so a tap goes straight from the gesture to
/// the object that holds the count and back out as a repaint. Nothing on the
/// counting path goes through a provider, a stream or an animation.
///
/// **Nothing here animates.** Not the count, not the stripe. That is the one
/// rule the whole screen is built around: at thirty-three repetitions a
/// counter that eases into position is a counter running behind the thumb, and
/// the lag is the entire experience. Feedback is haptic instead — see
/// [PlayerHaptics].
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

  /// The completion beat is running. Guards against a second notification
  /// starting a second one.
  bool _leaving = false;

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
    player.addListener(_onPlayerChanged);
    return player;
  }

  void _flush() {
    final WirdPlayer? player = _player;
    if (player != null) unawaited(player.flush());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _player?.removeListener(_onPlayerChanged);
    // Writes whatever is pending on the way out: leaving the player is exactly
    // when the position needs to be durable.
    _player?.dispose();
    super.dispose();
  }

  void _onPlayerChanged() {
    if (_player!.finished && !_leaving) {
      _leaving = true;
      unawaited(_holdThenLeave());
    }
  }

  /// The quiet mark at the end of a wird.
  ///
  /// The stripe is already solid brick — the last tap filled it — so the mark
  /// is that the screen *stays* for a beat instead of snapping away, and the
  /// counter reads finished while it does. No confetti, no sound, and no
  /// animation to reduce, which is why reduce-motion simply takes the hold
  /// away rather than replacing it with something shorter.
  Future<void> _holdThenLeave() async {
    final Duration hold = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Theme.of(context).extension<WirdiMotion>()!.completion;
    await Future<void>.delayed(hold);
    if (mounted) await Navigator.of(context).maybePop();
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
              _Player(player: player),
        );
      },
    );
  }
}

/// Everything below the app bar, rebuilt on every count.
class _Player extends ConsumerWidget {
  const _Player({required this.player});

  final WirdPlayer player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // The identity moment: the count, as an arch filling in. One segment
          // per repetition up to thirty-three, proportionally past that.
          child: VoussoirStripe.progress(
            value: player.stepProgress,
            segments: player.stripeSegments,
          ),
        ),
      ),
      body: player.isEmpty
          ? const _EmptyCollection()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _CountHeader(player: player),
                Expanded(
                  child: _StepContent(player: player, item: item),
                ),
                _Controls(player: player, item: item),
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

/// The remaining count, and which round of a repeat block this is.
///
/// Fixed above the content rather than scrolling with it: it is what the eye
/// comes back to between repetitions, and a count you have to scroll to find is
/// a count you stop looking at.
class _CountHeader extends StatelessWidget {
  const _CountHeader({required this.player});

  final WirdPlayer player;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    final PlaybackStep step = player.step;

    final String label = player.finished
        ? 'done'
        : step.count > 1
        ? 'left of ${step.count}'
        : 'left';

    return Semantics(
      container: true,
      liveRegion: true,
      label: player.finished
          ? 'Wird complete'
          : '${player.remaining} $label, step ${player.stepIndex + 1} of '
                '${player.steps.length}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            WirdiMetrics.readingColumnPadding,
            WirdiMetrics.space4,
            WirdiMetrics.readingColumnPadding,
            WirdiMetrics.space3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                '${player.remaining}',
                style: type.counter.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(width: WirdiMetrics.space3),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: quiet),
                ),
              ),
              if (step.isInRepeatBlock)
                _Plate(
                  label: 'Round ${step.repetition} of ${step.repetitionsTotal}',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A squared plate — the same 4dp radius the surah number uses. Not a pill.
class _Plate extends StatelessWidget {
  const _Plate({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: WirdiMetrics.space2,
        vertical: WirdiMetrics.space1,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: WirdiMetrics.chip,
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: WirdiMetrics.hairline,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The step itself, in the kind of container its content deserves.
///
/// A dhikr or an ayah is tap-to-count and the whole area counts. A surah is
/// not: "read Al-Mulk" is a reading, not a thirty-tap interaction, so it gets
/// the phase 4 verse rendering and a single done action in the controls.
class _StepContent extends StatelessWidget {
  const _StepContent({required this.player, required this.item});

  final WirdPlayer player;
  final CollectionItemEntry? item;

  @override
  Widget build(BuildContext context) {
    // Bound to a local so the patterns promote: a field cannot be.
    final CollectionItemEntry? entry = item;
    return switch (entry) {
      DhikrItem() => _TapToCount(
        player: player,
        child: _DhikrStep(item: entry),
      ),
      AyahItem() => _TapToCount(
        player: player,
        child: _AyahStep(item: entry),
      ),
      SurahItem() => _SurahStep(item: entry),
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
  const _TapToCount({required this.player, required this.child});

  final WirdPlayer player;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onTap: player.increment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: player.increment,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            WirdiMetrics.readingColumnPadding,
            0,
            WirdiMetrics.readingColumnPadding,
            WirdiMetrics.space6,
          ),
          child: child,
        ),
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

/// An ayah step: the same verse rendering the reading view uses, under a line
/// saying which verse it is.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Reference('$name ${ayah.surahNumber}:${ayah.ayahNumber}'),
        const SizedBox(height: WirdiMetrics.space3),
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

/// A surah step: a reading block, not a counter.
///
/// The verses are the phase 4 [AyahBlock] in a [ListView.builder], for the same
/// reason the reading view uses one — Al-Baqarah is 286 rows, and building all
/// of them to show ten is the cost that matters. Counting happens on the done
/// action in the controls below, not by tapping the text.
class _SurahStep extends ConsumerWidget {
  const _SurahStep({required this.item});

  final SurahItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SurahReading> reading = ref.watch(
      surahReadingProvider(item.surah.number),
    );
    final bool showTranslation =
        ref.watch(settingsProvider).value?.showTranslation ?? true;

    return switch (reading) {
      AsyncError(:final Object error, :final StackTrace stackTrace) =>
        FailureScreen(
          title: 'Could not read surah ${item.surah.number}',
          error: error,
          stackTrace: stackTrace,
        ),
      AsyncData(:final SurahReading value) => _SurahVerses(
        reading: value,
        note: item.note,
        showTranslation: showTranslation,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _SurahVerses extends StatelessWidget {
  const _SurahVerses({
    required this.reading,
    required this.note,
    required this.showTranslation,
  });

  final SurahReading reading;
  final String? note;
  final bool showTranslation;

  @override
  Widget build(BuildContext context) {
    // The heading is item 0; the basmala, where the database says there is one,
    // is item 1. Everything after that is a verse.
    final int leading = reading.hasBismillahHeading ? 2 : 1;
    final String name = reading.surah.nameTransliterated;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: WirdiMetrics.space6),
      itemCount: reading.ayahs.length + leading,
      itemBuilder: (BuildContext context, int index) {
        final Widget child;
        if (index == 0) {
          child = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Reference('$name · ${reading.surah.ayahCount} ayahs'),
              _Note(note: note),
              const SizedBox(height: WirdiMetrics.space5),
            ],
          );
        } else if (leading == 2 && index == 1) {
          child = BismillahHeading(text: reading.bismillah!);
        } else {
          child = AyahBlock(
            ayah: reading.ayahs[index - leading],
            surahName: name,
            showTranslation: showTranslation,
          );
        }
        return Padding(padding: WirdiMetrics.readingColumn, child: child);
      },
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

/// A quiet line naming what is on screen.
class _Reference extends StatelessWidget {
  const _Reference(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Undo, the done action for a surah, and manual movement between steps.
///
/// All of it lives down here, outside the counting area, because the counting
/// area is one large increment button. Undo in particular has to be somewhere
/// a thumb counting at speed cannot reach by accident, and a labelled button in
/// its own bar is that place.
class _Controls extends StatelessWidget {
  const _Controls({required this.player, required this.item});

  final WirdPlayer player;
  final CollectionItemEntry? item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    final bool isSurah = item is SurahItem;

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
              if (isSurah) ...<Widget>[
                const SizedBox(height: WirdiMetrics.space1),
                FilledButton(
                  onPressed: player.finished ? null : player.increment,
                  child: Text(
                    player.step.count > 1
                        ? 'Done — ${player.remaining} to go'
                        : 'Done',
                  ),
                ),
                const SizedBox(height: WirdiMetrics.space2),
              ],
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
