import 'package:flutter/material.dart';

/// A translation, with Saheeh International's bracket convention rendered.
///
/// The translation brackets words that are not in the Arabic — `[i.e., looks]`,
/// `[Muḥammad (ﷺ)]`, `[All] praise` — and does it in 3,409 of the 6,236 ayahs,
/// so it is not an edge case but the normal texture of the text. Dimming those
/// runs to [ColorScheme.onSurfaceVariant] lets the eye skip them and keeps the
/// translator's voice separate from the translation.
///
/// That was settled in phase 3 by looking at both on a device, so the reading
/// view has no toggle for it: [dimBracketedText] exists for the dev screen's
/// comparison and defaults to the decision.
class TranslationText extends StatelessWidget {
  const TranslationText(
    this.text, {
    super.key,
    this.style,
    this.dimBracketedText = true,
  });

  final String text;

  /// Defaults to `WirdiTypography.translation` at [ColorScheme.onSurface].
  final TextStyle? style;

  final bool dimBracketedText;

  /// A bracketed run, brackets included. Non-greedy and unnested, which is what
  /// the translation actually uses — no nested brackets anywhere in it.
  static final RegExp _bracketed = RegExp(r'\[[^\]]*\]');

  @override
  Widget build(BuildContext context) {
    if (!dimBracketedText) {
      return Text(text, style: style);
    }
    return Text.rich(
      TextSpan(
        children: _spans(Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      style: style,
      // The spans differ only in colour, so the plain text is what should be
      // read out rather than a sequence of styled fragments.
      semanticsLabel: text,
    );
  }

  List<InlineSpan> _spans(Color dim) {
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final RegExpMatch match in _bracketed.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match[0],
          style: TextStyle(color: dim),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}
