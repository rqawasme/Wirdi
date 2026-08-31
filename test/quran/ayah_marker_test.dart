import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/quran/uthmani_text.dart';
import 'package:wirdi/theme/theme.dart';

/// U+06DD is supposed to draw the digits that follow it *inside* the ornament.
/// Plenty of fonts declare the codepoint and then lay the digits out beside it,
/// or on top of each other, and the reading view's verse numbering depends on
/// the enclosure actually happening.
///
/// The test is the advance width: enclosed digits add nothing to it, because
/// they are drawn within the ornament's own box. Both bundled faces pass, three
/// digits included. If a font update breaks it, this fails here rather than in
/// a mushaf that has grown numbers outside their ornaments.
void main() {
  Future<void> loadFont(String family, String path) async {
    final FontLoader loader = FontLoader(family);
    loader.addFont(
      File(path).readAsBytes().then(
        (List<int> bytes) => ByteData.view(Uint8List.fromList(bytes).buffer),
      ),
    );
    await loader.load();
  }

  setUpAll(() async {
    await loadFont(
      WirdiFonts.naskh,
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    );
    await loadFont(WirdiFonts.quran, 'assets/fonts/AmiriQuran-Regular.ttf');
  });

  double widthOf(String text, String family) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: family, fontSize: 40),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }

  for (final ArabicFace face in ArabicFace.values) {
    group(face.family, () {
      for (final int ayahNumber in <int>[1, 7, 25, 255, 286]) {
        test('encloses $ayahNumber', () {
          final double ornament = widthOf(UthmaniText.endOfAyah, face.family);
          final double digits = widthOf(
            UthmaniText.arabicIndicDigits(ayahNumber),
            face.family,
          );
          final double marker = widthOf(
            UthmaniText.ayahMarker(ayahNumber),
            face.family,
          );

          expect(
            digits,
            greaterThan(0),
            reason: 'the digits must have a width of their own to compare to',
          );
          expect(
            marker,
            closeTo(ornament, 0.5),
            reason:
                'the digits added ${(marker - ornament).toStringAsFixed(1)} to '
                'the advance, so they are being set beside the ornament rather '
                'than inside it',
          );
        });
      }
    });
  }
}
