import 'package:fitcheck/outfits/outfit_picker.dart';
import 'package:fitcheck/wardrobe/wardrobe_models.dart';
import 'package:flutter_test/flutter_test.dart';

const school = Occasion('school', 'School');
final day = DateTime(2026, 11, 2);
const picker = OutfitPicker();

ClothingItem garment(
  String id,
  ClothingCategory category, {
  Formality formality = Formality.casual,
  int wears = 0,
  int washAfter = 2,
  bool tracksLaundry = true,
  DateTime? lastWorn,
  List<String> occasions = const ['school'],
}) => ClothingItem(
  id: id,
  name: id,
  colorName: 'Navy',
  category: category,
  formality: formality,
  occasionIds: occasions,
  wearsSinceWash: wears,
  washAfterWears: washAfter,
  tracksLaundry: tracksLaundry,
  lastWorn: lastWorn,
);

List<ClothingItem> baseOutfit() => [
  garment('top', ClothingCategory.top),
  garment('bottom', ClothingCategory.bottom),
  garment('shoes', ClothingCategory.shoes),
];

OutfitSuggestion ready(OutfitSelection result) {
  expect(result, isA<OutfitSuggestion>());
  return result as OutfitSuggestion;
}

void main() {
  test('clean and worn clothes qualify; dirty tracked clothes do not', () {
    final items = [
      garment('dirty', ClothingCategory.top, wears: 2),
      garment('worn', ClothingCategory.top, wears: 1),
      garment('bottom', ClothingCategory.bottom),
      garment('shoes', ClothingCategory.shoes),
    ];
    final result = ready(
      picker.pick(items: items, date: day, occasion: school),
    );
    expect(result.top.id, 'worn');
    expect(result.bottom.laundryStatus, LaundryStatus.clean);
    expect(result.top.laundryStatus, LaundryStatus.worn);
  });

  test(
    'disabled laundry tracking does not make a frequently worn item dirty',
    () {
      final result = ready(
        picker.pick(
          items: [
            garment(
              'untracked',
              ClothingCategory.top,
              wears: 99,
              tracksLaundry: false,
            ),
            ...baseOutfit().skip(1),
          ],
          date: day,
          occasion: school,
        ),
      );
      expect(result.top.id, 'untracked');
    },
  );

  test(
    'future reservations block other dates but permit the held local day',
    () {
      final items = baseOutfit();
      final reservations = {
        'top': {outfitDateKey(DateTime(2026, 11, 3))},
      };
      final before = picker.pick(
        items: items,
        date: day,
        occasion: school,
        reservations: reservations,
      );
      expect(before, isA<MissingOutfitItems>());
      expect((before as MissingOutfitItems).categories, {ClothingCategory.top});

      final held = ready(
        picker.pick(
          items: items,
          date: DateTime(2026, 11, 3, 23, 59),
          occasion: school,
          reservations: reservations,
        ),
      );
      expect(held.top.id, 'top');
      expect(held.top.laundryStatus, LaundryStatus.clean);

      final expired = ready(
        picker.pick(
          items: items,
          date: DateTime(2026, 11, 4),
          occasion: school,
          reservations: reservations,
        ),
      );
      expect(expired.top.id, 'top');
    },
  );

  test('a reservation never makes dirty clothing eligible', () {
    final result = picker.pick(
      items: [
        garment('dirty', ClothingCategory.top, wears: 2),
        ...baseOutfit().skip(1),
      ],
      date: day,
      occasion: school,
      reservations: {
        'dirty': {outfitDateKey(day)},
      },
    );
    expect(result, isA<MissingOutfitItems>());
    expect((result as MissingOutfitItems).categories, {ClothingCategory.top});
  });

  test('matching formality wins over a mixed outfit with older pieces', () {
    final result = ready(
      picker.pick(
        items: [
          garment('old-casual-top', ClothingCategory.top),
          garment(
            'formal-top',
            ClothingCategory.top,
            formality: Formality.formal,
            lastWorn: DateTime(2026, 11, 1),
          ),
          garment(
            'formal-bottom',
            ClothingCategory.bottom,
            formality: Formality.formal,
          ),
          garment(
            'formal-shoes',
            ClothingCategory.shoes,
            formality: Formality.formal,
          ),
        ],
        date: day,
        occasion: school,
      ),
    );
    expect(result.top.id, 'formal-top');
    expect(result.pieces.map((item) => item.formality).toSet(), {
      Formality.formal,
    });
  });

  test(
    'within matching formality, least-recently-worn wins with stable ID ties',
    () {
      final items = [
        garment(
          'recent',
          ClothingCategory.top,
          lastWorn: DateTime(2026, 11, 1),
        ),
        garment('old-b', ClothingCategory.top, lastWorn: DateTime(2026, 10, 1)),
        garment('old-a', ClothingCategory.top, lastWorn: DateTime(2026, 10, 1)),
        ...baseOutfit().skip(1),
      ];
      final first = ready(
        picker.pick(items: items, date: day, occasion: school),
      );
      final reversed = ready(
        picker.pick(items: items.reversed, date: day, occasion: school),
      );
      expect(first.top.id, 'old-a');
      expect(reversed.itemIds, first.itemIds);
      final neverWorn = ready(
        picker.pick(
          items: [...items, garment('never', ClothingCategory.top)],
          date: day,
          occasion: school,
        ),
      );
      expect(neverWorn.top.id, 'never');
    },
  );

  test('recency determines which of multiple matching outfits wins', () {
    final result = ready(
      picker.pick(
        items: [
          for (final category in ClothingCategory.values) ...[
            garment(
              'casual-${category.name}',
              category,
              lastWorn: DateTime(2026, 11, 1),
            ),
            garment(
              'formal-${category.name}',
              category,
              formality: Formality.formal,
              lastWorn: DateTime(2026, 10, 1),
            ),
          ],
        ],
        date: day,
        occasion: school,
      ),
    );
    expect(result.pieces.map((item) => item.formality).toSet(), {
      Formality.formal,
    });
  });

  test('wrong occasion and missing categories produce an explicit incomplete result', () {
    final result = picker.pick(
      items: [
        garment('work-top', ClothingCategory.top, occasions: ['work']),
        garment('bottom', ClothingCategory.bottom),
      ],
      date: day,
      occasion: school,
    );
    expect(result, isA<MissingOutfitItems>());
    expect((result as MissingOutfitItems).categories, {
      ClothingCategory.top,
      ClothingCategory.shoes,
    });
  });

  test('Swap all excludes every current piece without mutating the original suggestion', () {
    final items = [
      ...baseOutfit(),
      garment('alternate-top', ClothingCategory.top),
      garment('alternate-bottom', ClothingCategory.bottom),
    ];
    final original = ready(
      picker.pick(items: baseOutfit(), date: day, occasion: school),
    );
    final alternative = picker.pick(
      items: items,
      date: day,
      occasion: school,
      excludeItemIds: original.itemIds,
    );
    expect(alternative, isA<MissingOutfitItems>());
    expect((alternative as MissingOutfitItems).categories, {
      ClothingCategory.shoes,
    });
    expect(original.itemIds, {'top', 'bottom', 'shoes'});
    expect(items.length, 5);
  });

  test(
    'Swap all returns a completely different outfit when alternatives exist',
    () {
      final original = ready(
        picker.pick(items: baseOutfit(), date: day, occasion: school),
      );
      final swapped = ready(
        picker.pick(
          items: [
            ...baseOutfit(),
            for (final category in ClothingCategory.values)
              garment('new-${category.name}', category),
          ],
          date: day,
          occasion: school,
          excludeItemIds: original.itemIds,
        ),
      );
      expect(swapped.itemIds.intersection(original.itemIds), isEmpty);
    },
  );

  test('swap candidates retain eligible current first, then prefer matching formality', () {
    final items = [
      garment('current', ClothingCategory.top, lastWorn: DateTime(2026, 11, 1)),
      garment('casual', ClothingCategory.top),
      garment('formal', ClothingCategory.top, formality: Formality.formal),
      garment('dirty', ClothingCategory.top, wears: 2),
      garment('reserved', ClothingCategory.top),
      garment('bottom', ClothingCategory.bottom),
    ];
    final candidates = picker.swapCandidates(
      items: items,
      date: day,
      occasion: school,
      category: ClothingCategory.top,
      currentItemId: 'current',
      preferredFormality: Formality.formal,
      reservations: {
        'reserved': {'2026-11-03'},
      },
    );
    expect(candidates.map((item) => item.id), ['current', 'formal', 'casual']);
    final expiredCurrent = picker.swapCandidates(
      items: items,
      date: day,
      occasion: school,
      category: ClothingCategory.top,
      currentItemId: 'dirty',
    );
    expect(expiredCurrent.any((item) => item.id == 'dirty'), isFalse);
  });

  test('reason uses actual occasion and formality, adding weather only when supplied', () {
    final noWeather = ready(
      picker.pick(items: baseOutfit(), date: day, occasion: school),
    );
    expect(noWeather.reason, 'For School with matching casual pieces.');
    final weather = ready(
      picker.pick(
        items: baseOutfit(),
        date: day,
        occasion: school,
        temperatureC: 27,
      ),
    );
    expect(
      weather.reason,
      'For School with matching casual pieces. 27°C today.',
    );
    expect(
      () => picker.pick(
        items: baseOutfit(),
        date: day,
        occasion: school,
        temperatureC: double.nan,
      ),
      throwsArgumentError,
    );
  });

  test('planned occasion wins; otherwise actual usage counts and stable ties resolve it', () {
    final occasions = [
      school,
      const Occasion('work', 'Work'),
      const Occasion('church', 'Church'),
    ];
    expect(
      resolveOutfitOccasion(
        occasions: occasions,
        plannedOccasionId: 'work',
        useCounts: {'school': 20},
      )?.id,
      'work',
    );
    expect(
      resolveOutfitOccasion(
        occasions: occasions,
        useCounts: {'school': 2, 'work': 3},
      )?.id,
      'work',
    );
    expect(
      resolveOutfitOccasion(
        occasions: occasions.reversed,
        useCounts: {'school': 2, 'work': 2},
      )?.id,
      'school',
    );
    expect(
      resolveOutfitOccasion(occasions: occasions, plannedOccasionId: 'removed'),
      isNull,
    );
    expect(resolveOutfitOccasion(occasions: const []), isNull);
  });
}
