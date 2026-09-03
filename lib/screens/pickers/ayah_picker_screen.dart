import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collections/picked_item.dart';
import '../../domain/content.dart';
import '../../providers/editing.dart';
import '../../providers/reading.dart';
import '../../theme/theme.dart';
import '../../widgets/collection_dialogs.dart';
import '../../widgets/failure_screen.dart';
import '../../widgets/surah_row.dart';
import 'picker_scaffold.dart';

/// Pick a surah, then one ayah or a contiguous range of them.
///
/// A range is the case that matters. Wirds routinely use passages — the last
/// two ayahs of Al-Baqarah, Ayat al-Kursi through to the end of the ruku' —
/// and adding those one verse at a time is how somebody gives up on the
/// editor. A range adds one item per ayah, in order, so each one counts and is
/// read on its own the way the player already handles a verse.
///
/// Pops with a `List<PickedItem>`, one per ayah.
class AyahPickerScreen extends ConsumerWidget {
  const AyahPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Surah>> surahs = ref.watch(surahsProvider);

    return PickerScaffold(
      title: 'Add an ayah',
      body: switch (surahs) {
        AsyncError(:final Object error, :final StackTrace stackTrace) =>
          FailureScreen(
            title: 'Could not read the surah list',
            error: error,
            stackTrace: stackTrace,
          ),
        AsyncData(:final List<Surah> value) => ListView.builder(
          itemCount: value.length,
          itemBuilder: (BuildContext context, int index) => SurahRow(
            surah: value[index],
            onTap: () => _openRange(context, value[index]),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// The second step, pushed rather than named: it is a step inside this
  /// picker, not a screen of the app, and it cannot be reached without a
  /// surah to be about.
  Future<void> _openRange(BuildContext context, Surah surah) async {
    final List<PickedItem>? picked = await Navigator.push<List<PickedItem>>(
      context,
      MaterialPageRoute<List<PickedItem>>(
        builder: (BuildContext context) => _AyahRangeScreen(surah: surah),
      ),
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    Navigator.pop(context, picked);
  }
}

/// One ayah, or a run of them.
class _AyahRangeScreen extends ConsumerStatefulWidget {
  const _AyahRangeScreen({required this.surah});

  final Surah surah;

  @override
  ConsumerState<_AyahRangeScreen> createState() => _AyahRangeScreenState();
}

class _AyahRangeScreenState extends ConsumerState<_AyahRangeScreen> {
  final TextEditingController _from = TextEditingController(text: '1');
  final TextEditingController _to = TextEditingController(text: '1');

  /// A single ayah is the common case, so it is the mode the screen opens in
  /// and the second field only appears when it is asked for.
  bool _isRange = false;

  @override
  void initState() {
    super.initState();
    _from.addListener(_onChanged);
    _to.addListener(_onChanged);
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  int? get _fromValue => int.tryParse(_from.text.trim());

  int? get _toValue => _isRange ? int.tryParse(_to.text.trim()) : _fromValue;

  /// Why the range cannot be added, or null if it can.
  String? get _refusal {
    final int? from = _fromValue;
    final int? to = _toValue;
    final int last = widget.surah.ayahCount;
    if (from == null || to == null) return 'Give an ayah number.';
    if (from < 1 || to < 1) return 'Ayahs are numbered from 1.';
    if (from > last || to > last) {
      return '${widget.surah.nameTransliterated} has $last '
          '${last == 1 ? 'ayah' : 'ayahs'}.';
    }
    if (to < from) return 'The range ends before it starts.';
    return null;
  }

  int get _count => (_toValue ?? 0) - (_fromValue ?? 0) + 1;

  Future<void> _add() async {
    final int from = _fromValue!;
    final int to = _toValue!;
    final ItemOptions? options = await showItemOptions(
      context,
      title: _rangeLabel,
      subtitle: _isRange && to > from
          ? 'Adds $_count items, one per ayah. '
                'The count and note apply to each.'
          : 'One item.',
      naturalCount: 1,
    );
    if (options == null || !mounted) return;

    // Through the repository's own range query, so a range that runs past the
    // end of the surah comes back clamped instead of adding items that
    // resolve to nothing.
    final List<PickedItem> items = await ref
        .read(collectionEditorProvider)
        .ayahRange(
          widget.surah.number,
          from,
          to,
          count: options.count,
          note: options.note,
        );
    if (!mounted) return;
    Navigator.pop(context, items);
  }

  String get _rangeLabel {
    final int? from = _fromValue;
    final int? to = _toValue;
    final String surah = widget.surah.nameTransliterated;
    if (from == null) return surah;
    if (!_isRange || to == null || to == from) return '$surah $from';
    return '$surah $from–$to';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? refusal = _refusal;

    return PickerScaffold(
      title: widget.surah.nameTransliterated,
      body: ListView(
        padding: const EdgeInsets.all(WirdiMetrics.space5),
        children: <Widget>[
          Text(
            '${widget.surah.ayahCount} '
            '${widget.surah.ayahCount == 1 ? 'ayah' : 'ayahs'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: WirdiMetrics.space5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _from,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: _isRange ? 'From ayah' : 'Ayah',
                  ),
                ),
              ),
              if (_isRange) ...<Widget>[
                const SizedBox(width: WirdiMetrics.space4),
                Expanded(
                  child: TextField(
                    controller: _to,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(labelText: 'To ayah'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: WirdiMetrics.space2),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('A range of ayahs'),
            value: _isRange,
            onChanged: (bool value) => setState(() {
              _isRange = value;
              if (value && _to.text.trim().isEmpty) _to.text = _from.text;
            }),
          ),
          const SizedBox(height: WirdiMetrics.space4),
          Text(
            refusal ??
                (_count == 1
                    ? 'Adds $_rangeLabel.'
                    : 'Adds $_count ayahs, $_rangeLabel.'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: refusal == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: WirdiMetrics.space5),
          FilledButton(
            onPressed: refusal == null ? _add : null,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
