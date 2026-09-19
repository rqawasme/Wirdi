import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collection_editing.dart';
import '../collections/dhikr_editing.dart';
import '../domain/collection.dart';
import '../domain/content.dart';
import '../domain/item_ref.dart';
import '../providers/adhkar.dart';
import '../providers/collections.dart';
import '../providers/home.dart';
import '../routes.dart';
import '../theme/theme.dart';
import '../widgets/banded_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/failure_screen.dart';
import '../widgets/plate.dart';
import '../widgets/voussoir_stripe.dart';

/// The adhkar the user wrote: all of them, what holds each, and the way to
/// write another.
///
/// Reached from the collections list rather than from a tab of its own. The
/// Collections tab is the one about what the app contains, and a shelf of your
/// own adhkar belongs in that list — four tabs is the ceiling, and this is not
/// a place anybody spends a morning.
///
/// A dhikr is edited and deleted from here and nowhere else. A collection names
/// its adhkar; it does not own them, and offering "delete this dhikr" from
/// inside a collection would mean offering, from one collection, to change
/// another.
class AdhkarScreen extends ConsumerStatefulWidget {
  const AdhkarScreen({super.key});

  @override
  ConsumerState<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends ConsumerState<AdhkarScreen> {
  /// A write is in flight.
  bool _busy = false;

  Future<void> _write({Dhikr? dhikr}) async {
    final Object? saved = await Navigator.pushNamed(
      context,
      Routes.dhikrEdit,
      arguments: DhikrEditArguments(dhikr: dhikr),
    );
    // The editor invalidates the list itself; an edit that changed a count has
    // also changed what every collection saying it resolves to.
    if (saved is UserDhikrRef && mounted) {
      ref
        ..invalidate(collectionListingsProvider)
        ..invalidate(homeViewProvider);
    }
  }

  Future<void> _delete(Dhikr dhikr) async {
    if (_busy) return;
    if (dhikr.ref case final UserDhikrRef target) {
      setState(() => _busy = true);
      try {
        final List<CollectionSummary> holders = await ref
            .read(userDhikrEditorProvider)
            .usedBy(target);
        if (!mounted) return;

        final bool confirmed = await _confirm(
          deleteDhikrPrompt(<String>[
            for (final CollectionSummary c in holders) c.name,
          ]),
        );
        if (!confirmed || !mounted) return;

        await ref.read(userDhikrEditorProvider).delete(target);
        ref
          ..invalidate(userAdhkarProvider)
          ..invalidate(userDhikrUsageProvider)
          // Every collection it was taken out of is a row shorter, and one of
          // them may be on the home screen.
          ..invalidate(collectionListingsProvider)
          ..invalidate(homeViewProvider);
      } on CollectionEditingError catch (error) {
        _say(error.message);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirm(String prompt) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete this dhikr?'),
        content: Text(prompt),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
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

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Dhikr>> adhkar = ref.watch(userAdhkarProvider);
    final Map<UserDhikrRef, int> usage =
        ref.watch(userDhikrUsageProvider).value ?? const <UserDhikrRef, int>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your adhkar'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Write a dhikr',
            onPressed: _busy ? null : () => _write(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: switch (adhkar) {
        AsyncError(:final Object error, :final StackTrace stackTrace) =>
          FailureScreen(
            title: 'Could not read your adhkar',
            error: error,
            stackTrace: stackTrace,
          ),
        AsyncData(:final List<Dhikr> value) =>
          value.isEmpty ? _empty() : _list(value, usage),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _empty() {
    return EmptyState(
      title: 'Nothing of your own yet',
      body:
          'Write down a dua you say, and it can go into any of your '
          'collections — at whatever count you keep it.',
      action: FilledButton(
        onPressed: _busy ? null : () => _write(),
        child: const Text('Write a dhikr'),
      ),
    );
  }

  Widget _list(List<Dhikr> adhkar, Map<UserDhikrRef, int> usage) {
    return ListView.builder(
      padding: WirdiMetrics.withSystemBottom(
        context,
        const EdgeInsets.only(bottom: WirdiMetrics.space6),
      ),
      itemCount: adhkar.length,
      itemBuilder: (BuildContext context, int index) => BandedRow(
        index: index,
        child: _DhikrRow(
          dhikr: adhkar[index],
          uses: usage[adhkar[index].ref] ?? 0,
          enabled: !_busy,
          onEdit: () => _write(dhikr: adhkar[index]),
          onDelete: () => _delete(adhkar[index]),
        ),
      ),
    );
  }
}

/// One of the user's adhkar: what it says, how often, and what holds it.
///
/// Its own row rather than [DhikrRow], which the pickers share: a picker's row
/// is a choice, and the whole of it is one tap. This one carries two actions
/// and a line of state, which is the shape `CollectionRow` settled on for the
/// same reason — the actions share the bottom line with the meta rather than
/// standing to the right of the text and taking the width off it.
class _DhikrRow extends StatelessWidget {
  const _DhikrRow({
    required this.dhikr,
    required this.uses,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final Dhikr dhikr;

  /// How many collection items name it.
  final int uses;

  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WirdiTypography type = theme.extension<WirdiTypography>()!;
    final Color quiet = theme.colorScheme.onSurfaceVariant;
    final String? translation = dhikr.translation;

    return Semantics(
      container: true,
      label: 'Dhikr, ${translation ?? dhikr.textArabic}, $_usesLabel',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          WirdiMetrics.space4,
          WirdiMetrics.space3,
          WirdiMetrics.space2,
          WirdiMetrics.space2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            dhikr.textArabic,
                            style: type.arabicTitle,
                            locale: const Locale('ar'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (dhikr.defaultCount > 1) ...<Widget>[
                        const SizedBox(width: WirdiMetrics.space3),
                        Plate(label: '×${dhikr.defaultCount}'),
                      ],
                    ],
                  ),
                  if (translation != null) ...<Widget>[
                    const SizedBox(height: WirdiMetrics.space2),
                    Text(
                      translation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: quiet),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      _usesLabel,
                      style: theme.textTheme.bodySmall?.copyWith(color: quiet),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: enabled ? onEdit : null,
                  child: const Text('Edit'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: enabled ? onDelete : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// What holds this dhikr, counted in items rather than collections: a
  /// collection that says it twice will lose two rows if it goes.
  String get _usesLabel => switch (uses) {
    0 => 'In none of your collections',
    1 => 'In one collection',
    _ => 'In $uses places',
  };
}
