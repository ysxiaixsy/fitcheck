import 'package:fitcheck/outfits/outfit_picker.dart';
import 'package:fitcheck/outfits/outfit_repository.dart';
import 'package:fitcheck/wardrobe/wardrobe_models.dart';
import 'package:flutter_test/flutter_test.dart';

const occasion = Occasion('school', 'School');

ClothingItem piece(String id, ClothingCategory category, {int wears = 0}) =>
    ClothingItem(
      id: id,
      name: id,
      colorName: 'Navy blue',
      category: category,
      formality: Formality.casual,
      occasionIds: const ['school'],
      washAfterWears: 2,
      wearsSinceWash: wears,
    );

OutfitSuggestion suggestion() => OutfitSuggestion(
  date: DateTime(2026, 11, 2, 18, 30),
  occasion: occasion,
  top: piece('top', ClothingCategory.top),
  bottom: piece('bottom', ClothingCategory.bottom),
  shoes: piece('shoes', ClothingCategory.shoes),
  reason: 'For School with matching casual pieces.',
);

Map<String, dynamic> savedData() => {
  'date': '2026-11-02',
  'topId': 'top',
  'bottomId': 'bottom',
  'shoesId': 'shoes',
  'occasionId': 'school',
  'reason': 'For School with matching casual pieces.',
  'worn': false,
};

void main() {
  test(
    'saved outfit round trip keeps its local calendar day and wear status',
    () {
      final saved = SavedOutfit.fromSuggestion(suggestion(), worn: true);
      final restored = SavedOutfit.fromMap(
        saved.toMap(),
        expectedDateKey: '2026-11-02',
      );

      expect(restored.date, DateTime(2026, 11, 2));
      expect(restored.dateKey, '2026-11-02');
      expect(restored.itemIds, {'top', 'bottom', 'shoes'});
      expect(restored.occasionId, 'school');
      expect(restored.reason, suggestion().reason);
      expect(restored.worn, isTrue);
    },
  );

  test('stored date rejects rollover, timestamp, and noncanonical forms', () {
    for (final date in [
      '2026-02-30',
      '2026-02-29',
      '2026-13-01',
      '2026-11-00',
      '2026-1-02',
      '2026-11-02T00:00:00Z',
      '0000-11-02',
    ]) {
      expect(
        () => SavedOutfit.fromMap({...savedData(), 'date': date}),
        throwsA(isA<OutfitFailure>()),
        reason: date,
      );
    }
    expect(
      SavedOutfit.fromMap({...savedData(), 'date': '2028-02-29'}).dateKey,
      '2028-02-29',
    );
  });

  test('stored date must agree with its document key', () {
    expect(
      () => SavedOutfit.fromMap(savedData(), expectedDateKey: '2026-11-03'),
      throwsA(isA<OutfitFailure>()),
    );
  });

  test(
    'missing or incorrectly typed storage fields have a controlled failure',
    () {
      for (final field in savedData().keys) {
        final missing = savedData()..remove(field);
        final incorrectlyTyped = savedData()..[field] = [1, 2, 3];
        expect(
          () => SavedOutfit.fromMap(missing),
          throwsA(isA<OutfitFailure>()),
          reason: 'Missing $field',
        );
        expect(
          () => SavedOutfit.fromMap(incorrectlyTyped),
          throwsA(isA<OutfitFailure>()),
          reason: 'Incorrect type for $field',
        );
      }
    },
  );

  test('invalid references and duplicate clothing slots are rejected', () {
    for (final change in [
      {'topId': ''},
      {'bottomId': 'top'},
      {'shoesId': 'nested/path'},
      {'occasionId': '..'},
      {'topId': List.filled(501, '中').join()},
    ]) {
      expect(
        () => SavedOutfit.fromMap({...savedData(), ...change}),
        throwsA(isA<OutfitFailure>()),
      );
    }
  });

  test('stored reasoning must be present and fit on one short line', () {
    for (final reason in ['', '   ', 'For School.\nNew line.', 'x' * 501]) {
      expect(
        () => SavedOutfit.fromMap({...savedData(), 'reason': reason}),
        throwsA(isA<OutfitFailure>()),
      );
    }
  });

  test(
    'worn outfits still resolve after their pieces become due for washing',
    () {
      final saved = SavedOutfit.fromSuggestion(suggestion(), worn: true);
      final resolved = saved.resolve(
        items: [
          piece('top', ClothingCategory.top, wears: 2),
          piece('bottom', ClothingCategory.bottom, wears: 2),
          piece('shoes', ClothingCategory.shoes, wears: 2),
        ],
        occasions: const [occasion],
      );

      expect(resolved, isNotNull);
      expect(
        resolved!.pieces.every(
          (item) => item.laundryStatus == LaundryStatus.toWash,
        ),
        isTrue,
      );
      expect(resolved.reason, saved.reason);
      expect(resolved.date, saved.date);
    },
  );

  test('missing, recategorized, or unknown-occasion references do not substitute an outfit', () {
    final saved = SavedOutfit.fromSuggestion(suggestion());
    expect(
      saved.resolve(
        items: [suggestion().bottom, suggestion().shoes],
        occasions: const [occasion],
      ),
      isNull,
    );
    expect(
      saved.resolve(
        items: [
          piece('top', ClothingCategory.bottom),
          suggestion().bottom,
          suggestion().shoes,
        ],
        occasions: const [occasion],
      ),
      isNull,
    );
    expect(
      saved.resolve(
        items: suggestion().pieces,
        occasions: const [Occasion('work', 'Work')],
      ),
      isNull,
    );
  });

  test('capturing a suggestion validates each clothing category', () {
    final original = suggestion();
    expect(
      () => SavedOutfit.fromSuggestion(
        OutfitSuggestion(
          date: original.date,
          occasion: original.occasion,
          top: original.shoes,
          bottom: original.bottom,
          shoes: original.top,
          reason: original.reason,
        ),
      ),
      throwsA(isA<OutfitFailure>()),
    );
  });
}
