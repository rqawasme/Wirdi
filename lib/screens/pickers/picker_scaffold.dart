import 'package:flutter/material.dart';

import '../../widgets/voussoir_stripe.dart';

/// The shell every picker wears: a title, a back arrow and the rule.
///
/// A picker is pushed to answer one question and popped with the answer, so it
/// has no actions of its own — the answer is the row you tap.
class PickerScaffold extends StatelessWidget {
  const PickerScaffold({super.key, required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: body,
    );
  }
}
