import 'package:fitcheck/fragrance/fragrance.dart';
import 'package:flutter_test/flutter_test.dart';

Fragrance fragrance(
  String id,
  TemperatureBand temperature,
  HumidityBand humidity,
) => Fragrance(
  id: id,
  name: 'User fragrance $id',
  temperatureBand: temperature,
  humidityBand: humidity,
);

List<RankedFragrance> rank(
  Iterable<Fragrance> fragrances,
  double temperature,
  double humidity,
) => rankFragrances(
  fragrances: fragrances,
  temperatureC: temperature,
  relativeHumidity: humidity,
);

void main() {
  test(
    'stored fields round trip without treating notes as weather evidence',
    () {
      final original = Fragrance(
        id: 'personal-scent',
        name: '  My fragrance  ',
        scentNotes: '  Citrus and wood  ',
        temperatureBand: TemperatureBand.cool,
        humidityBand: HumidityBand.humid,
        photoUrl: 'https://example.com/photo.jpg',
      );
      final restored = Fragrance.fromMap(original.id, original.toMap());
      expect(restored.id, original.id);
      expect(restored.name, 'My fragrance');
      expect(restored.scentNotes, 'Citrus and wood');
      expect(restored.temperatureBand, TemperatureBand.cool);
      expect(restored.humidityBand, HumidityBand.humid);
      expect(restored.photoUrl, original.photoUrl);
      expect(restored.toMap(), original.toMap());
      expect(original.toMap().containsKey('id'), isFalse);
    },
  );

  test('optional fields may be absent or blank but bands require a choice', () {
    final restored = Fragrance.fromMap('one', {
      'name': 'One',
      'temperatureBand': 'warm',
      'humidityBand': 'dry',
    });
    expect(restored.scentNotes, isNull);
    expect(restored.photoUrl, isNull);
    final blank = Fragrance(
      id: 'two',
      name: 'Two',
      scentNotes: ' ',
      photoUrl: '',
      temperatureBand: TemperatureBand.mild,
      humidityBand: HumidityBand.balanced,
    );
    expect(blank.scentNotes, isNull);
    expect(blank.photoUrl, isNull);
    for (final field in ['name', 'temperatureBand', 'humidityBand']) {
      final data = restored.toMap()..remove(field);
      expect(() => Fragrance.fromMap('one', data), throwsFormatException);
    }
  });

  test(
    'invalid saved types, bands, and invalid references fail predictably',
    () {
      final data = fragrance(
        'one',
        TemperatureBand.cool,
        HumidityBand.dry,
      ).toMap();
      for (final field in data.keys) {
        expect(
          () => Fragrance.fromMap('one', {...data, field: 5}),
          throwsFormatException,
          reason: 'Incorrect $field type',
        );
      }
      for (final change in [
        {'name': ' '},
        {'name': 'x' * 121},
        {'scentNotes': 'x' * 501},
        {'temperatureBand': 'tropical'},
        {'humidityBand': 'rainy'},
        {'photoUrl': 'file:///private/photo.jpg'},
        {'photoUrl': 'https://'},
      ]) {
        expect(
          () => Fragrance.fromMap('one', {...data, ...change}),
          throwsFormatException,
        );
      }
      for (final id in ['', '.', '..', 'other/path', '中' * 501]) {
        expect(() => Fragrance.fromMap(id, data), throwsFormatException);
      }
    },
  );

  test('changing observed temperature changes the first fragrance', () {
    final choices = [
      fragrance('cool', TemperatureBand.cool, HumidityBand.balanced),
      fragrance('warm', TemperatureBand.warm, HumidityBand.balanced),
    ];
    expect(rank(choices, 18, 55).first.fragrance.id, 'cool');
    expect(rank(choices, 30, 55).first.fragrance.id, 'warm');
  });

  test('changing observed humidity changes the first fragrance', () {
    final choices = [
      fragrance('dry', TemperatureBand.mild, HumidityBand.dry),
      fragrance('humid', TemperatureBand.mild, HumidityBand.humid),
    ];
    expect(rank(choices, 23, 25).first.fragrance.id, 'dry');
    expect(rank(choices, 23, 85).first.fragrance.id, 'humid');
  });

  test(
    'temperature thresholds have one matching band including exact endpoints',
    () {
      final choices = [
        for (final band in TemperatureBand.values)
          fragrance(band.name, band, HumidityBand.balanced),
      ];
      for (final (temperature, band) in [
        (19.999, TemperatureBand.cool),
        (20.0, TemperatureBand.mild),
        (27.0, TemperatureBand.mild),
        (27.001, TemperatureBand.warm),
      ]) {
        final ranked = rank(choices, temperature, 50);
        expect(
          ranked.first.fragrance.temperatureBand,
          band,
          reason: '$temperature',
        );
        expect(ranked.first.score, 1);
        expect(ranked.skip(1).every((value) => value.score < 1), isTrue);
      }
    },
  );

  test(
    'humidity thresholds have one matching band including exact endpoints',
    () {
      final choices = [
        for (final band in HumidityBand.values)
          fragrance(band.name, TemperatureBand.mild, band),
      ];
      for (final (humidity, band) in [
        (0.0, HumidityBand.dry),
        (39.999, HumidityBand.dry),
        (40.0, HumidityBand.balanced),
        (70.0, HumidityBand.balanced),
        (70.001, HumidityBand.humid),
        (100.0, HumidityBand.humid),
      ]) {
        final ranked = rank(choices, 23, humidity);
        expect(ranked.first.fragrance.humidityBand, band, reason: '$humidity');
        expect(ranked.first.score, 1);
        expect(ranked.skip(1).every((value) => value.score < 1), isTrue);
      }
    },
  );

  test('a nearer mismatched preference outranks a farther one', () {
    final ranked = rank(
      [
        fragrance('cool', TemperatureBand.cool, HumidityBand.balanced),
        fragrance('mild', TemperatureBand.mild, HumidityBand.balanced),
      ],
      32,
      60,
    );
    expect(ranked.map((value) => value.fragrance.id), ['mild', 'cool']);
    expect(ranked.first.score, greaterThan(ranked.last.score));
    final warm = fragrance('warm', TemperatureBand.warm, HumidityBand.balanced);
    expect(
      rank([warm], 26, 60).single.score,
      greaterThan(rank([warm], 10, 60).single.score),
    );
  });

  test(
    'all combinations rank the exact match first and preserve every choice',
    () {
      final choices = [
        for (final temperature in TemperatureBand.values)
          for (final humidity in HumidityBand.values)
            fragrance(
              '${temperature.name}-${humidity.name}',
              temperature,
              humidity,
            ),
      ];
      final ranked = rank(choices, 31, 88);
      expect(ranked.first.fragrance.id, 'warm-humid');
      expect(
        ranked.map((value) => value.fragrance.id).toSet(),
        choices.map((value) => value.id).toSet(),
      );
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i - 1].score, greaterThanOrEqualTo(ranked[i].score));
      }
      expect(() => ranked.clear(), throwsUnsupportedError);
    },
  );

  test('equal compatibility uses IDs regardless of input order or names', () {
    final choices = [
      fragrance('z', TemperatureBand.mild, HumidityBand.balanced),
      fragrance('a', TemperatureBand.mild, HumidityBand.balanced),
      fragrance('m', TemperatureBand.mild, HumidityBand.balanced),
    ];
    expect(rank(choices, 22, 55).map((value) => value.fragrance.id), [
      'a',
      'm',
      'z',
    ]);
    expect(rank(choices.reversed, 22, 55).map((value) => value.fragrance.id), [
      'a',
      'm',
      'z',
    ]);
  });

  test(
    'reasons describe actual weather and disclose mismatched preferences',
    () {
      final ranked = rank(
        [
          fragrance('matched', TemperatureBand.cool, HumidityBand.humid),
          fragrance('unmatched', TemperatureBand.warm, HumidityBand.dry),
        ],
        19.99,
        85,
      );
      for (final value in ranked) {
        expect(value.reason, contains('19.99°C and 85% humidity'));
        expect(value.reason, isNot(contains('\n')));
        expect(value.reason, isNot(contains('Citrus')));
      }
      expect(
        ranked.first.reason,
        contains('Cool (below 20°C) fits the temperature'),
      );
      expect(
        ranked.first.reason,
        contains('Humid (above 70%) fits the humidity'),
      );
      expect(
        ranked.last.reason,
        contains('Warm (above 27°C) is outside the temperature'),
      );
      expect(
        ranked.last.reason,
        contains('Dry (below 40%) is outside the humidity'),
      );
    },
  );

  test('nonfinite temperature and invalid humidity are rejected even with no choices', () {
    for (final temperature in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(() => rank([], temperature, 50), throwsArgumentError);
    }
    for (final humidity in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
      -0.01,
      100.01,
    ]) {
      expect(() => rank([], 25, humidity), throwsArgumentError);
    }
  });

  test('no collection produces no fragrance or invented reason', () {
    expect(rank([], 25, 50), isEmpty);
  });

  test('band labels use the user-facing vocabulary', () {
    expect(TemperatureBand.values.map((value) => value.label), [
      'Cool',
      'Mild',
      'Warm',
    ]);
    expect(HumidityBand.values.map((value) => value.label), [
      'Dry',
      'Balanced',
      'Humid',
    ]);
  });
}
