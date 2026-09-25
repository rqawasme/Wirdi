import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collection_editing.dart';
import '../collections/dhikr_editing.dart';
import '../domain/content.dart';
import '../domain/errors.dart';
import '../domain/item_ref.dart';
import '../providers/adhkar.dart';
import '../providers/refresh.dart';
import '../theme/theme.dart';
import '../widgets/voussoir_stripe.dart';

/// Writing a dhikr, or editing one already written.
///
/// Pops with the [UserDhikrRef] of what it saved, so that the picker that
/// pushed it can add the new dhikr to a collection without asking for it back;
/// with nothing if it was backed out of.
///
/// A screen and not a dialog. The collection form is a dialog because it asks
/// for one required line and one optional one; this asks for six fields, one of
/// them several lines of Arabic set right to left, and a dialog that tall is a
/// screen wearing the wrong clothes.
class DhikrEditScreen extends ConsumerStatefulWidget {
  const DhikrEditScreen({super.key, this.dhikr});

  /// The dhikr being edited, or null when one is being written.
  ///
  /// Its ref decides which: a [Dhikr] whose ref is a [ContentRef] is an
  /// authored one, which this screen cannot edit and is never handed.
  final Dhikr? dhikr;

  @override
  ConsumerState<DhikrEditScreen> createState() => _DhikrEditScreenState();
}

class _DhikrEditScreenState extends ConsumerState<DhikrEditScreen> {
  late final TextEditingController _arabic = TextEditingController(
    text: widget.dhikr?.textArabic ?? '',
  )..addListener(_onArabicChanged);
  late final TextEditingController _translation = TextEditingController(
    text: widget.dhikr?.translation ?? '',
  );
  late final TextEditingController _transliteration = TextEditingController(
    text: widget.dhikr?.transliteration ?? '',
  );
  late final TextEditingController _count = TextEditingController(
    text: '${widget.dhikr?.defaultCount ?? 1}',
  );
  late final TextEditingController _reference = TextEditingController(
    text: widget.dhikr?.reference ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.dhikr?.notes ?? '',
  );

  /// Whether there is anything in the Arabic field. Save waits on it rather
  /// than refusing afterwards: a disabled button says "not yet" where a snack
  /// bar says "you were wrong", and only one of those is true.
  bool _written = false;

  /// A write is in flight. Two saves racing would both be applied.
  bool _busy = false;

  /// The ref of the dhikr being edited, or null when writing a new one.
  UserDhikrRef? get _editing => switch (widget.dhikr?.ref) {
    final UserDhikrRef ref => ref,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _written = _arabic.text.trim().isNotEmpty;
  }

  void _onArabicChanged() {
    final bool written = _arabic.text.trim().isNotEmpty;
    if (written != _written) setState(() => _written = written);
  }

  @override
  void dispose() {
    _arabic
      ..removeListener(_onArabicChanged)
      ..dispose();
    _translation.dispose();
    _transliteration.dispose();
    _count.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  DhikrDraft get _draft => DhikrDraft(
    textArabic: _arabic.text,
    translation: _translation.text,
    transliteration: _transliteration.text,
    // An empty field is once, which is what the hint says. Anything else is
    // at most six digits — see [countInputFormatters] — so it always parses;
    // the fallback is for the empty field and nothing else.
    defaultCount: int.tryParse(_count.text.trim()) ?? 1,
    reference: _reference.text,
    notes: _notes.text,
  );

  Future<void> _save() async {
    if (_busy || !_written) return;
    // Before the await: see [refreshAfterUserWrite] on why not `ref` after it.
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    setState(() => _busy = true);
    try {
      final UserDhikrEditor editor = ref.read(userDhikrEditorProvider);
      final UserDhikrRef? editing = _editing;
      final UserDhikrRef saved;
      if (editing == null) {
        saved = await editor.create(_draft);
      } else {
        await editor.update(editing, _draft);
        saved = editing;
      }

      // Every list of these, and every collection that says one: the text and
      // the count a collection item resolves through have both just moved.
      refreshAfterUserWrite(container);

      if (mounted) Navigator.pop(context, saved);
    } on CollectionEditingError catch (error) {
      _say(error.message);
    } on DhikrNotFoundException {
      // Deleted while this form was open. There is nothing to save the edit
      // over, so say so and leave, rather than staying on a form whose every
      // Save will fail the same way.
      refreshAfterUserWrite(container);
      _say('That dhikr was deleted, so this edit was not saved.');
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final bool editing = _editing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit dhikr' : 'Write a dhikr'),
        actions: <Widget>[
          TextButton(
            onPressed: _written && !_busy ? _save : null,
            child: const Text('Save'),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: ListView(
        // The keyboard is up for most of the time this screen is open, so the
        // fields have to be able to scroll clear of it — and the last one has
        // to clear the system inset underneath it as well.
        padding: WirdiMetrics.withSystemBottom(
          context,
          const EdgeInsets.fromLTRB(
            WirdiMetrics.space4,
            WirdiMetrics.space4,
            WirdiMetrics.space4,
            WirdiMetrics.space6,
          ),
        ),
        children: <Widget>[
          // Genuinely right-to-left rather than right-aligned: the shaper needs
          // the paragraph direction to order runs and break lines correctly,
          // and so does the caret. Typed in the same face the player recites
          // it in, so what somebody writes is what they will read.
          TextField(
            controller: _arabic,
            autofocus: !editing,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: type.dhikr,
            maxLines: null,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              labelText: 'Arabic',
              alignLabelWithHint: true,
              helperText: 'The words as you say them',
            ),
          ),
          const SizedBox(height: WirdiMetrics.space5),
          TextField(
            controller: _translation,
            textCapitalization: TextCapitalization.sentences,
            maxLines: null,
            minLines: 2,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Translation',
              alignLabelWithHint: true,
              helperText: 'Optional',
            ),
          ),
          const SizedBox(height: WirdiMetrics.space5),
          TextField(
            controller: _transliteration,
            maxLines: null,
            minLines: 1,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Transliteration',
              helperText: 'Optional',
            ),
          ),
          const SizedBox(height: WirdiMetrics.space5),
          TextField(
            controller: _count,
            keyboardType: TextInputType.number,
            inputFormatters: countInputFormatters,
            decoration: const InputDecoration(
              labelText: 'Times said',
              hintText: '1',
              helperText: 'How many times, unless a collection says otherwise',
            ),
          ),
          const SizedBox(height: WirdiMetrics.space5),
          TextField(
            controller: _reference,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Where it is from',
              helperText: 'Optional. Yours to write, and shown as your note',
            ),
          ),
          const SizedBox(height: WirdiMetrics.space5),
          TextField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            maxLines: null,
            minLines: 2,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Note',
              alignLabelWithHint: true,
              helperText: 'Optional',
            ),
          ),
          if (editing) ...<Widget>[
            const SizedBox(height: WirdiMetrics.space5),
            Text(
              // Said here rather than discovered afterwards: an edit is shared,
              // and somebody about to fix a typo should know that it fixes the
              // typo everywhere they have said this dhikr.
              'Changes apply everywhere this dhikr is used.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
