import 'package:flutter/material.dart';

import '../../widgets/voussoir_stripe.dart';

/// The shell every picker wears: a title, a back arrow and the rule.
///
/// A picker is pushed to answer one question and popped with the answer, so it
/// has no actions of its own — the answer is the row you tap.
class PickerScaffold extends StatelessWidget {
  const PickerScaffold({
    super.key,
    required this.title,
    required this.body,
    this.header,
  });

  final String title;

  /// Sits between the rule and [body], and does not scroll with it.
  ///
  /// The dhikr picker's search field lives here: a field that scrolls away
  /// above four hundred rows is a field you have to scroll back to before you
  /// can change your mind about the search.
  final Widget? header;

  final Widget body;

  @override
  Widget build(BuildContext context) {
    final Widget? header = this.header;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          child: VoussoirStripe.rule(),
        ),
      ),
      body: header == null
          ? body
          : Column(
              children: <Widget>[
                header,
                Expanded(child: body),
              ],
            ),
    );
  }
}
