import 'package:flutter/widgets.dart';

/// Shape, spacing and line weight.
///
/// Plain constants rather than a [ThemeExtension]: none of these vary between
/// light and dark, and a value that never changes is easier to read at the call
/// site than a lookup that might.
abstract final class WirdiMetrics {
  /// The base spacing unit. Every gap in the app is a multiple of this.
  static const double unit = 4;

  static const double space1 = unit; // 4
  static const double space2 = unit * 2; // 8
  static const double space3 = unit * 3; // 12
  static const double space4 = unit * 4; // 16
  static const double space5 = unit * 5; // 20
  static const double space6 = unit * 6; // 24

  /// Cards and buttons. Buttons are squared at this radius deliberately,
  /// overriding Material's stadium default — see `WirdiTheme`.
  static const double cardRadius = 8;
  static const double buttonRadius = 8;

  /// Chips and counters — tighter, so a counter reads as a plate rather than a
  /// pill.
  static const double chipRadius = 4;

  /// Bottom sheets, top corners only.
  static const double sheetRadius = 12;

  /// Dialogs are not in the brief. They are surfaces that arrive over the
  /// content, like sheets, so they take the sheet radius.
  static const double dialogRadius = sheetRadius;

  /// Hairline rules. Sub-pixel on a 1x screen and exactly one pixel at 2x,
  /// which is the intent: a division, not a bar.
  static const double hairline = 0.5;

  /// Depth is tonal — surface, then surfaceContainer, then
  /// surfaceContainerHigh — plus hairline outlines. Nothing is lifted.
  static const double elevation = 0;

  /// Horizontal padding of a reading column. Wider than the 16dp Material
  /// default: Arabic set at 2.0 line height needs the extra breathing room at
  /// the margins or the block reads as a slab.
  static const double readingColumnPadding = 20;

  /// Vertical gap between one verse block and the next.
  static const double verseBlockSpacing = 24;

  static const BorderRadius card = BorderRadius.all(
    Radius.circular(cardRadius),
  );
  static const BorderRadius button = BorderRadius.all(
    Radius.circular(buttonRadius),
  );
  static const BorderRadius chip = BorderRadius.all(
    Radius.circular(chipRadius),
  );

  /// Top corners only: a sheet is a surface sliding up out of the bottom edge,
  /// and rounding the bottom would float it off the screen.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(sheetRadius),
  );

  static const BorderRadius dialog = BorderRadius.all(
    Radius.circular(dialogRadius),
  );

  static const EdgeInsets readingColumn = EdgeInsets.symmetric(
    horizontal: readingColumnPadding,
  );
}
