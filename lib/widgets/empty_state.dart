import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'voussoir_stripe.dart';

/// What a screen says when there is nothing on it yet.
///
/// The mark above the text is a short length of the voussoir stripe — the same
/// motif that rules the app bar and fills in as progress. It is used here
/// because it is the only ornament this app has: an illustration would be a
/// whole visual language grown for the two screens that happen to be empty,
/// and it would be the loudest thing in an app whose case is quietness.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.body, this.action});

  /// How wide the stripe runs. Six segments at [VoussoirStripe.segmentWidth],
  /// so it reads as a fragment of the rule rather than as a divider that has
  /// lost its section.
  static const double stripeWidth = VoussoirStripe.segmentWidth * 6;

  final String title;

  /// A sentence under the title, saying what to do next. Optional: some empty
  /// states have nothing to suggest.
  final String? body;

  /// The action that fills the emptiness, if there is one.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? body = this.body;
    final Widget? action = this.action;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WirdiMetrics.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(width: stripeWidth, child: VoussoirStripe.rule()),
            const SizedBox(height: WirdiMetrics.space5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: WirdiMetrics.space2),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: WirdiMetrics.space5),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
