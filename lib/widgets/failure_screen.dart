import 'package:flutter/material.dart';

import '../theme/metrics.dart';

/// The whole app when it cannot start, or a screen when it cannot load.
///
/// Deliberately plain and deliberately verbose. The first time the bundled
/// `content.db` is copied out of the asset bundle is the first launch on a
/// device, and a failure there — a missing asset, a schema the pipeline no
/// longer builds, a SQLite older than the app supports — has to say so on
/// screen rather than leave a blank window and a line in the log.
class FailureScreen extends StatelessWidget {
  const FailureScreen({
    super.key,
    required this.title,
    required this.error,
    this.stackTrace,
  });

  final String title;
  final Object error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WirdiMetrics.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: WirdiMetrics.space3),
              SelectableText('$error', style: theme.textTheme.bodyMedium),
              if (stackTrace != null) ...<Widget>[
                const SizedBox(height: WirdiMetrics.space5),
                SelectableText(
                  '$stackTrace',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
