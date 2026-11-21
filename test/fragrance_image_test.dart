import 'package:fitcheck/fragrance/fragrance.dart';
import 'package:fitcheck/fragrance/today_fragrance.dart';
import 'package:fitcheck/theme/fitcheck_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'a fragrance photo is decorative and does not make its card an image',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.light,
          home: Scaffold(
            body: Semantics(
              container: true,
              label: 'Fragrance card',
              child: FragranceImage(
                fragrance: Fragrance(
                  id: 'photo',
                  name: 'Photo scent',
                  temperatureBand: TemperatureBand.warm,
                  humidityBand: HumidityBand.humid,
                  photoUrl: 'https://example.test/photo.png',
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(FragranceImage)),
        isSemantics(label: 'Fragrance card', isImage: false),
      );
      semantics.dispose();
    },
  );
}
