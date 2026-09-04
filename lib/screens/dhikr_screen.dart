import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

/// Single-dhikr counters: one dhikr, said a number of times, without a
/// collection around it.
///
/// Empty, and honestly so. The tab exists because the shell has four
/// destinations and this is one of them, but nothing in either database
/// describes a standalone counter yet: `content.db` has adhkar and it has
/// collections, and a dhikr on its own is neither. Filling the tab by listing
/// every dhikr in the database would be a product decision made by whoever was
/// nearest the keyboard, so it is left for one that is made deliberately.
///
/// The empty state names the state and stops. It does not apologise, and it
/// does not promise a date.
class DhikrScreen extends StatelessWidget {
  const DhikrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'No single adhkar yet',
      body:
          'A collection of one dhikr does the same thing for now. Make one on '
          'the Collections tab.',
    );
  }
}
