import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// A field for searching a long list, in the app's own shapes: squared at
/// [WirdiMetrics.buttonRadius], a hairline outline, one tonal step of fill, and
/// a clear button once there is something to clear.
///
/// Styled here rather than through an `inputDecorationTheme`. The app has
/// exactly one field that searches anything; theming every [TextField] to suit
/// it would restyle four dialogs that are not searching for anything, which is
/// a theme-wide decision taken on one screen's behalf.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;

  /// What this field searches, said plainly. It is the only instruction the
  /// screen gives, so it should name what is being matched rather than say
  /// "Search".
  final String hintText;

  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color quiet = scheme.onSurfaceVariant;

    // The same border in every state. Focus is the caret and the keyboard; a
    // field that also changes colour is saying it twice, and the colour it
    // would reach for is `primary`, which this app keeps for the wird itself.
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: WirdiMetrics.button,
      borderSide: BorderSide(
        color: scheme.outlineVariant,
        width: WirdiMetrics.hairline,
      ),
    );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: scheme.surfaceContainer,
            isDense: true,
            prefixIcon: Icon(Icons.search, color: quiet),
            // Only once there is text: an always-present clear button on an
            // empty field is a button that does nothing, sitting where the
            // text will go.
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, color: quiet),
                    tooltip: 'Clear the search',
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                  ),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
          ),
        );
      },
    );
  }
}
