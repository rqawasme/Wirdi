import 'package:flutter/material.dart';

import '../providers/tracker.dart';
import '../theme/theme.dart';

/// The row at the top of the tracker that says what is being shown, and opens
/// the list of what else could be.
///
/// A sheet rather than a [DropdownButton], for the reason the commit sheet is
/// one: this app already asks "which of these?" by sliding a list up from the
/// bottom, and Material's dropdown menu is a rounded card in an app whose
/// corners are all 4 and 8.
class TrackerScopePicker extends StatelessWidget {
  const TrackerScopePicker({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final List<TrackerScopeOption> options;
  final TrackerScope selected;
  final ValueChanged<TrackerScope> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        final TrackerScope? chosen = await _showScopeSheet(
          context,
          options: options,
          selected: selected,
        );
        if (chosen != null) onSelect(chosen);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          WirdiMetrics.space4,
          WirdiMetrics.space4,
          WirdiMetrics.space4,
          WirdiMetrics.space3,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: WirdiMetrics.space2),
            // The same typographic chevron the calendar pages with, turned
            // down. An icon here would be the app's first.
            ExcludeSemantics(
              child: Text(
                '⌄',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the tracker is looking at: everything, or one collection.
///
/// The collections come in the order they were committed, which is the order
/// the home screen's tiles are in — so the two screens list the same things
/// the same way round. Anything done but no longer committed follows, without
/// a label saying so: "uncommitted" on a row would be a nudge to commit, and
/// this tab reports rather than asks.
Future<TrackerScope?> _showScopeSheet(
  BuildContext context, {
  required List<TrackerScopeOption> options,
  required TrackerScope selected,
}) {
  return showModalBottomSheet<TrackerScope>(
    context: context,
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return SafeArea(
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
                  WirdiMetrics.space2,
                ),
                child: Text('Show', style: theme.textTheme.titleMedium),
              ),
              for (final TrackerScopeOption option in options)
                ListTile(
                  title: Text(option.label),
                  // A check in quiet ink, the way every other chosen thing in
                  // this app is marked. Not a radio.
                  trailing: option.scope == selected
                      ? Icon(
                          Icons.check,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, option.scope),
                ),
              const SizedBox(height: WirdiMetrics.space4),
            ],
          ),
        ),
      );
    },
  );
}
