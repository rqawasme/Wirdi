import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/theme/theme.dart';

/// The two codepoints each family has to borrow from the other.
///
/// A font missing a character does not fail loudly: it draws an empty box, or —
/// where the platform has a fallback chain — quietly borrows the glyph from
/// some other face, which looks almost right and is different on every device.
/// `tool/check_font_coverage.py` catches that for the text in `content.db`.
/// These two are not in `content.db`: one arrives inside the translation, and
/// the other is drawn by the text engine rather than authored at all.
void main() {
  const WirdiTypography type = WirdiTypography();

  /// U+FDFA, the sallallahu-alayhi-wasallam ligature. Inline in the Saheeh
  /// International translation, in the middle of English sentences.
  const int salawat = 0xFDFA;

  /// U+2026, the ellipsis. Never authored: the text engine draws it wherever a
  /// line is truncated with [TextOverflow.ellipsis], which on this screen is
  /// the Arabic name on a home-screen tile.
  const int ellipsis = 0x2026;

  test('Latin falls back to the Arabic face for the salawat ligature', () {
    expect(type.translation.fontFamily, WirdiFonts.latin);
    expect(type.translation.fontFamilyFallback, contains(WirdiFonts.naskh));

    expect(_covers(WirdiFonts.latin, salawat), isFalse);
    expect(_covers(WirdiFonts.naskh, salawat), isTrue);
  });

  test('Arabic falls back to the Latin face for the ellipsis', () {
    expect(type.arabicChrome.fontFamily, WirdiFonts.naskh);
    expect(type.arabicChrome.fontFamilyFallback, contains(WirdiFonts.latin));

    // The reason the fallback is there. If Noto Naskh ever gains an ellipsis
    // this test says so, and the fallback can go.
    expect(_covers(WirdiFonts.naskh, ellipsis), isFalse);
    expect(_covers(WirdiFonts.latin, ellipsis), isTrue);
  });

  test('the Latin fallback cannot mask a gap in the Arabic faces', () {
    // Inter has no Arabic at all, so a missing Arabic mark still renders as the
    // box it should rather than being silently substituted.
    expect(_covers(WirdiFonts.latin, 0x0645), isFalse); // meem
    expect(_covers(WirdiFonts.latin, 0x064E), isFalse); // fatha
  });
}

/// Whether the font file for [family] has a glyph for [codepoint].
///
/// Reads the `cmap` directly, the same way `tool/check_font_coverage.py` does
/// and for the same reason: one loop over the format-4 and format-12 subtables
/// is cheaper to trust than a font-parsing dependency.
bool _covers(String family, int codepoint) {
  final File file = File('assets/fonts/${_files[family]!}');
  final ByteData data = ByteData.sublistView(file.readAsBytesSync());

  final int tableCount = data.getUint16(4);
  int? cmapOffset;
  for (int i = 0; i < tableCount; i++) {
    final int record = 12 + i * 16;
    final String tag = String.fromCharCodes(
      Uint8List.sublistView(data, record, record + 4),
    );
    if (tag == 'cmap') {
      cmapOffset = data.getUint32(record + 8);
      break;
    }
  }
  expect(cmapOffset, isNotNull, reason: 'no cmap in $family');

  final int subtables = data.getUint16(cmapOffset! + 2);
  for (int i = 0; i < subtables; i++) {
    final int offset = cmapOffset + data.getUint32(cmapOffset + 4 + i * 8 + 4);
    if (_subtableCovers(data, offset, codepoint)) return true;
  }
  return false;
}

bool _subtableCovers(ByteData data, int offset, int codepoint) {
  switch (data.getUint16(offset)) {
    case 4:
      if (codepoint > 0xFFFF) return false;
      final int segX2 = data.getUint16(offset + 6);
      final int ends = offset + 14;
      final int starts = ends + segX2 + 2;
      final int deltas = starts + segX2;
      final int ranges = deltas + segX2;
      for (int s = 0; s < segX2; s += 2) {
        if (codepoint > data.getUint16(ends + s)) continue;
        if (codepoint < data.getUint16(starts + s)) return false;
        final int rangeOffset = data.getUint16(ranges + s);
        if (rangeOffset == 0) {
          return (codepoint + data.getInt16(deltas + s)) & 0xFFFF != 0;
        }
        final int glyphAt =
            ranges +
            s +
            rangeOffset +
            (codepoint - data.getUint16(starts + s)) * 2;
        if (glyphAt + 1 >= data.lengthInBytes) return false;
        return data.getUint16(glyphAt) != 0;
      }
      return false;
    case 12:
      final int groups = data.getUint32(offset + 12);
      for (int g = 0; g < groups; g++) {
        final int at = offset + 16 + g * 12;
        if (codepoint >= data.getUint32(at) &&
            codepoint <= data.getUint32(at + 4)) {
          return true;
        }
      }
      return false;
    default:
      return false;
  }
}

const Map<String, String> _files = <String, String>{
  WirdiFonts.latin: 'Inter-Regular.ttf',
  WirdiFonts.naskh: 'NotoNaskhArabic-Regular.ttf',
  WirdiFonts.quran: 'AmiriQuran-Regular.ttf',
};
