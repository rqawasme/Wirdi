import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;

import '../domain/commitment.dart';
import '../theme/theme.dart';

/// What the name-and-description form came back with.
@immutable
final class CollectionForm {
  const CollectionForm({required this.name, this.description});

  final String name;
  final String? description;
}

/// Naming a collection: for a new one, a copy of a built-in, or a rename.
///
/// A dialog rather than a screen. It asks for one required line and one
/// optional one, and pushing a route for that would put a back stack between
/// somebody and the collection they are trying to make.
Future<CollectionForm?> showCollectionForm(
  BuildContext context, {
  required String title,
  required String submitLabel,
  String initialName = '',
  String? initialDescription,
  bool askForDescription = true,
}) {
  return showDialog<CollectionForm>(
    context: context,
    builder: (BuildContext context) => _CollectionFormDialog(
      title: title,
      submitLabel: submitLabel,
      initialName: initialName,
      initialDescription: initialDescription,
      askForDescription: askForDescription,
    ),
  );
}

class _CollectionFormDialog extends StatefulWidget {
  const _CollectionFormDialog({
    required this.title,
    required this.submitLabel,
    required this.initialName,
    required this.initialDescription,
    required this.askForDescription,
  });

  final String title;
  final String submitLabel;
  final String initialName;
  final String? initialDescription;
  final bool askForDescription;

  @override
  State<_CollectionFormDialog> createState() => _CollectionFormDialogState();
}

class _CollectionFormDialogState extends State<_CollectionFormDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  )..addListener(_onNameChanged);
  late final TextEditingController _description = TextEditingController(
    text: widget.initialDescription ?? '',
  );

  bool _named = false;

  @override
  void initState() {
    super.initState();
    _named = _name.text.trim().isNotEmpty;
  }

  void _onNameChanged() {
    final bool named = _name.text.trim().isNotEmpty;
    if (named != _named) setState(() => _named = named);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_named) return;
    Navigator.pop(
      context,
      CollectionForm(
        name: _name.text.trim(),
        description: widget.askForDescription
            ? _emptyToNull(_description.text.trim())
            : widget.initialDescription,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: widget.askForDescription
                ? TextInputAction.next
                : TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: widget.askForDescription
                ? null
                : (String _) => _submit(),
          ),
          if (widget.askForDescription) ...<Widget>[
            const SizedBox(height: WirdiMetrics.space4),
            TextField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Description',
                helperText: 'Optional',
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // A collection with no name is a row nobody can tell apart from the
          // next one, so the action waits rather than inventing "Untitled".
          onPressed: _named ? _submit : null,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

/// The count override and note an item can carry.
@immutable
final class ItemOptions {
  const ItemOptions({this.count, this.note});

  /// Null leaves the item at its natural count.
  final int? count;

  final String? note;
}

/// Asked once per pick, on the way out of a picker.
///
/// Both fields are optional and both start empty — an item added without
/// touching either behaves exactly as the content intends it to, which is what
/// most items want. The count field shows the natural count as its hint rather
/// than as its value, so leaving it alone is not the same as pinning it.
Future<ItemOptions?> showItemOptions(
  BuildContext context, {
  required String title,
  required String subtitle,
  required int naturalCount,
}) {
  return showDialog<ItemOptions>(
    context: context,
    builder: (BuildContext context) => _ItemOptionsDialog(
      title: title,
      subtitle: subtitle,
      naturalCount: naturalCount,
    ),
  );
}

class _ItemOptionsDialog extends StatefulWidget {
  const _ItemOptionsDialog({
    required this.title,
    required this.subtitle,
    required this.naturalCount,
  });

  final String title;
  final String subtitle;
  final int naturalCount;

  @override
  State<_ItemOptionsDialog> createState() => _ItemOptionsDialogState();
}

class _ItemOptionsDialogState extends State<_ItemOptionsDialog> {
  final TextEditingController _count = TextEditingController();
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _count.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final int? count = int.tryParse(_count.text.trim());
    Navigator.pop(
      context,
      ItemOptions(
        // Zero and anything below it are not counts; treated as "leave it
        // alone" rather than refused, since the field is optional anyway.
        count: count != null && count > 0 && count != widget.naturalCount
            ? count
            : null,
        note: _emptyToNull(_note.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: WirdiMetrics.space4),
          TextField(
            controller: _count,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: 'Count',
              hintText: '${widget.naturalCount}',
              helperText: 'Optional. Leave empty to keep it as it is.',
            ),
          ),
          const SizedBox(height: WirdiMetrics.space4),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'Note',
              helperText: 'Optional',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

/// How many times a repeat block is recited.
///
/// The only number in the grouping flow, so it is asked for on its own rather
/// than as one field of a form.
Future<int?> showRepetitionsDialog(BuildContext context) {
  return showDialog<int>(
    context: context,
    builder: (BuildContext context) => const _RepetitionsDialog(),
  );
}

class _RepetitionsDialog extends StatefulWidget {
  const _RepetitionsDialog();

  @override
  State<_RepetitionsDialog> createState() => _RepetitionsDialogState();
}

class _RepetitionsDialogState extends State<_RepetitionsDialog> {
  final TextEditingController _times = TextEditingController(text: '3');

  @override
  void dispose() {
    _times.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Repeat these items'),
      content: TextField(
        controller: _times,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: const InputDecoration(labelText: 'Times'),
        onSubmitted: (String _) =>
            Navigator.pop(context, int.tryParse(_times.text.trim())),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(_times.text.trim())),
          child: const Text('Repeat'),
        ),
      ],
    );
  }
}

/// Confirms a soft delete, saying what it does and does not take with it.
Future<bool> confirmDeleteCollection(
  BuildContext context, {
  required String name,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text('Delete $name?'),
      // The second sentence is the one that matters: a streak is built out of
      // completions, and deleting a collection must not read as deleting the
      // days somebody spent on it.
      content: const Text(
        'This removes the collection and anything part-way through it. '
        'The days you completed are kept.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

String? _emptyToNull(String value) => value.isEmpty ? null : value;

/// Which part of the day a collection is being committed to.
///
/// A sheet rather than a menu, and for the same reason the item pickers are
/// one: three equal choices, one of which is the answer. [current] marks the
/// one it is committed to already, so moving it is a choice made with the
/// present state in view rather than from memory.
///
/// The subtitles say what the section is for and nothing about what committing
/// will do. Nobody needs telling that a thing they put in their morning will
/// appear in their morning.
Future<DailySection?> showSectionPicker(
  BuildContext context, {
  required String name,
  DailySection? current,
}) {
  return showModalBottomSheet<DailySection>(
    context: context,
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                WirdiMetrics.space4,
                WirdiMetrics.space5,
                WirdiMetrics.space4,
                WirdiMetrics.space2,
              ),
              child: Text(name, style: theme.textTheme.titleMedium),
            ),
            for (final DailySection section in DailySection.values)
              ListTile(
                title: Text(section.label),
                subtitle: Text(_sectionSubtitle(section)),
                // A check, in the same quiet ink as everything else that marks
                // state in this app. Not a radio: the sheet closes on the tap,
                // so there is no selection to hold.
                trailing: section == current
                    ? Icon(
                        Icons.check,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
                onTap: () => Navigator.pop(context, section),
              ),
          ],
        ),
      );
    },
  );
}

String _sectionSubtitle(DailySection section) => switch (section) {
  DailySection.daily => 'No particular time of day',
  DailySection.morning => 'After fajr, until the sun is up',
  DailySection.evening => 'From asr onwards',
};
