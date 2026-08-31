import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/content.dart';
import '../providers/reading.dart';
import '../providers/settings.dart';
import '../theme/theme.dart';
import '../widgets/ayah_block.dart';
import '../widgets/failure_screen.dart';
import '../widgets/voussoir_stripe.dart';

/// One surah, verse by verse.
///
/// Nothing here animates on scroll: no collapsing header, no parallax, no
/// fading rule. The header is the surah's name and the voussoir stripe under
/// it, and it stays exactly where it is.
class ReadingScreen extends ConsumerWidget {
  const ReadingScreen({
    super.key,
    required this.surahNumber,
    this.initialAyahNumber,
  });

  final int surahNumber;

  /// The verse to open at. Null starts at the top.
  final int? initialAyahNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SurahReading> reading = ref.watch(
      surahReadingProvider(surahNumber),
    );
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    return Scaffold(
      appBar: AppBar(
        title: switch (reading) {
          AsyncData(:final SurahReading value) => Row(
            children: <Widget>[
              Expanded(child: Text(value.surah.nameTransliterated)),
              const SizedBox(width: WirdiMetrics.space3),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  value.surah.nameArabic,
                  style: type.arabicTitle,
                  locale: AyahBlock.arabic,
                ),
              ),
            ],
          ),
          _ => const Text(''),
        },
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: switch (reading) {
        AsyncError(:final Object error, :final StackTrace stackTrace) =>
          FailureScreen(
            title: 'Could not read surah $surahNumber',
            error: error,
            stackTrace: stackTrace,
          ),
        AsyncData(:final SurahReading value) => _SurahBody(
          reading: value,
          initialAyahNumber: initialAyahNumber,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SurahBody extends ConsumerStatefulWidget {
  const _SurahBody({required this.reading, required this.initialAyahNumber});

  final SurahReading reading;
  final int? initialAyahNumber;

  @override
  ConsumerState<_SurahBody> createState() => _SurahBodyState();
}

class _SurahBodyState extends ConsumerState<_SurahBody> {
  /// How many times [_jumpToIndex] will look for its target before giving up.
  ///
  /// Each pass either lands on the verse or gets materially closer, so this is
  /// a guard against a pathological list rather than a budget that gets used.
  static const int _maxRestorePasses = 5;

  final ScrollController _controller = ScrollController();
  final GlobalKey _listKey = GlobalKey();

  /// Captured in [initState] rather than read where it is used.
  ///
  /// `ref` is unsafe once the widget is being unmounted, and flushing the
  /// position is exactly a dispose-time job — so holding the recorder is the
  /// only way to do it. It also saves a provider read on every scroll frame.
  late final ReadingPositionRecorder _recorder;

  /// 1 when a basmala heading occupies index 0, else 0.
  late final int _leading = widget.reading.hasBismillahHeading ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(readingPositionRecorderProvider);
    final int? ayahNumber = widget.initialAyahNumber;
    if (ayahNumber != null && ayahNumber > 1) {
      // After the first layout, or there is no sliver to ask yet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToIndex(_indexOfAyah(ayahNumber));
      });
    }
  }

  @override
  void dispose() {
    // Leaving a surah is exactly when the position needs to be durable, and it
    // is also when nothing more will arrive to fire the debounce timer.
    _recorder.flush();
    _controller.dispose();
    super.dispose();
  }

  int _indexOfAyah(int ayahNumber) {
    final int i = widget.reading.ayahs.indexWhere(
      (Ayah a) => a.ayahNumber == ayahNumber,
    );
    return _leading + (i < 0 ? 0 : i);
  }

  int? _ayahNumberAt(int index) {
    final int i = index - _leading;
    if (i < 0) return widget.reading.ayahs.firstOrNull?.ayahNumber;
    if (i >= widget.reading.ayahs.length) return null;
    return widget.reading.ayahs[i].ayahNumber;
  }

  void _onScroll() {
    final int? index = _firstVisibleIndex();
    if (index == null) return;
    final int? ayahNumber = _ayahNumberAt(index);
    if (ayahNumber == null) return;
    _recorder.record(widget.reading.surah.number, ayahNumber);
  }

  // -- Asking the sliver where it is -----------------------------------------
  //
  // Verses are variable height — a two-word ayah and Ayat al-Kursi are not
  // remotely the same size, and the Arabic size slider changes all of them — so
  // the scroll offset cannot say which verse is on screen. Every package that
  // answers this is a package, so instead the sliver is asked directly: each of
  // its laid-out children carries its index and its layout offset.

  RenderSliverMultiBoxAdaptor? _sliver() {
    final RenderObject? root = _listKey.currentContext?.findRenderObject();
    return root == null ? null : _findSliver(root);
  }

  static RenderSliverMultiBoxAdaptor? _findSliver(RenderObject object) {
    if (object is RenderSliverMultiBoxAdaptor) return object;
    RenderSliverMultiBoxAdaptor? found;
    object.visitChildren((RenderObject child) {
      found ??= _findSliver(child);
    });
    return found;
  }

  /// The index of the topmost item the viewport is showing.
  int? _firstVisibleIndex() {
    final RenderSliverMultiBoxAdaptor? sliver = _sliver();
    if (sliver == null || !_controller.hasClients) return null;

    final double offset = _controller.position.pixels;
    RenderBox? child = sliver.firstChild;
    while (child != null) {
      final SliverMultiBoxAdaptorParentData data =
          child.parentData! as SliverMultiBoxAdaptorParentData;
      final double? layoutOffset = data.layoutOffset;
      // The first child whose bottom edge is past the top of the viewport.
      // `size.height` rather than the sliver's protected paintExtentOf: this
      // list is always vertical, so the height *is* the extent along the axis.
      if (layoutOffset != null && layoutOffset + child.size.height > offset) {
        return data.index;
      }
      child = sliver.childAfter(child);
    }
    return null;
  }

  RenderBox? _childWithIndex(RenderSliverMultiBoxAdaptor sliver, int index) {
    RenderBox? child = sliver.firstChild;
    while (child != null) {
      final SliverMultiBoxAdaptorParentData data =
          child.parentData! as SliverMultiBoxAdaptorParentData;
      if (data.index == index) return child;
      child = sliver.childAfter(child);
    }
    return null;
  }

  /// Where item [index] probably starts, for an item that is not built yet.
  ///
  /// Anchored on the built child nearest the target rather than counting from
  /// zero: its layout offset is known exactly, so only the gap between it and
  /// the target has to be guessed, and each jump brings the anchor closer. That
  /// is what makes repeating this converge — an estimate measured from zero is
  /// the same wrong number every pass.
  double? _estimateOffset(RenderSliverMultiBoxAdaptor sliver, int index) {
    final double? average = _averageExtent(sliver);
    if (average == null) return null;

    int? anchorIndex;
    double? anchorOffset;
    RenderBox? child = sliver.firstChild;
    while (child != null) {
      final SliverMultiBoxAdaptorParentData data =
          child.parentData! as SliverMultiBoxAdaptorParentData;
      final int? childIndex = data.index;
      final double? layoutOffset = data.layoutOffset;
      if (childIndex != null &&
          layoutOffset != null &&
          (anchorIndex == null ||
              (childIndex - index).abs() < (anchorIndex - index).abs())) {
        anchorIndex = childIndex;
        anchorOffset = layoutOffset;
      }
      child = sliver.childAfter(child);
    }

    if (anchorIndex == null) return index * average;
    return anchorOffset! + (index - anchorIndex) * average;
  }

  /// The mean height of the children currently laid out, for guessing where an
  /// unbuilt one is.
  double? _averageExtent(RenderSliverMultiBoxAdaptor sliver) {
    double total = 0;
    int count = 0;
    RenderBox? child = sliver.firstChild;
    while (child != null) {
      total += child.size.height;
      count++;
      child = sliver.childAfter(child);
    }
    return count == 0 ? null : total / count;
  }

  /// Scrolls so that item [index] is at the top.
  ///
  /// A lazy list has not built the target yet, and an unbuilt item's offset
  /// cannot be known — its height depends on how the Arabic wraps at the
  /// current size. So this alternates: guess from the mean height of what *is*
  /// built, let the frame settle, and once the target exists ask the viewport
  /// for its real offset. Jumping changes which items are built and can shift
  /// the answer slightly, so it repeats until the target is genuinely the
  /// topmost item rather than trusting one computed offset.
  ///
  /// Two passes is the normal case: guess, then refine.
  Future<void> _jumpToIndex(int index) async {
    for (int pass = 0; pass < _maxRestorePasses; pass++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_controller.hasClients) return;
      final RenderSliverMultiBoxAdaptor? sliver = _sliver();
      if (sliver == null) return;

      // The goal, checked directly. Landing near the verse is not the same as
      // landing on it, and the offset arithmetic cannot tell the difference.
      if (_firstVisibleIndex() == index) return;

      final ScrollPosition position = _controller.position;
      final RenderBox? child = _childWithIndex(sliver, index);
      final double target;
      if (child != null) {
        // Non-null by construction: the child is a sliver child, so it has a
        // viewport above it.
        target = RenderAbstractViewport.of(
          child,
        ).getOffsetToReveal(child, 0).offset;
      } else {
        final double? estimate = _estimateOffset(sliver, index);
        if (estimate == null) return;
        target = estimate;
      }

      final double clamped = target.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      // Nowhere left to go and still not there: the target is inside the last
      // screenful, so the bottom of the list is as close as it gets.
      if ((position.pixels - clamped).abs() < 0.5) return;
      _controller.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showTranslation =
        ref.watch(settingsProvider).value?.showTranslation ?? true;
    final SurahReading reading = widget.reading;
    final String surahName = reading.surah.nameTransliterated;

    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (ScrollUpdateNotification notification) {
        _onScroll();
        return false;
      },
      child: ListView.builder(
        key: _listKey,
        controller: _controller,
        padding: const EdgeInsets.only(
          top: WirdiMetrics.space6,
          bottom: WirdiMetrics.space6,
        ),
        itemCount: reading.ayahs.length + _leading,
        itemBuilder: (BuildContext context, int index) {
          final Widget child;
          if (_leading == 1 && index == 0) {
            child = BismillahHeading(text: reading.bismillah!);
          } else {
            child = AyahBlock(
              ayah: reading.ayahs[index - _leading],
              surahName: surahName,
              showTranslation: showTranslation,
            );
          }
          return Padding(padding: WirdiMetrics.readingColumn, child: child);
        },
      ),
    );
  }
}
