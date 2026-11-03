import 'dart:convert';
import 'dart:math' as math;

enum TemperatureBand {
  cool('Cool', 'below 20°C'),
  mild('Mild', '20–27°C'),
  warm('Warm', 'above 27°C');

  const TemperatureBand(this.label, this.rangeLabel);
  final String label, rangeLabel;

  bool contains(double temperatureC) => switch (this) {
    cool => temperatureC < 20,
    mild => temperatureC >= 20 && temperatureC <= 27,
    warm => temperatureC > 27,
  };

  double _distance(double temperatureC) => switch (this) {
    cool => math.max(0, temperatureC - 20),
    mild => math.max(0, math.max(20 - temperatureC, temperatureC - 27)),
    warm => math.max(0, 27 - temperatureC),
  };
}

enum HumidityBand {
  dry('Dry', 'below 40%'),
  balanced('Balanced', '40–70%'),
  humid('Humid', 'above 70%');

  const HumidityBand(this.label, this.rangeLabel);
  final String label, rangeLabel;

  bool contains(double relativeHumidity) => switch (this) {
    dry => relativeHumidity < 40,
    balanced => relativeHumidity >= 40 && relativeHumidity <= 70,
    humid => relativeHumidity > 70,
  };

  double _distance(double relativeHumidity) => switch (this) {
    dry => math.max(0, relativeHumidity - 40),
    balanced => math.max(
      0,
      math.max(40 - relativeHumidity, relativeHumidity - 70),
    ),
    humid => math.max(0, 70 - relativeHumidity),
  };
}

/// Weather bands are explicitly chosen by the user for this fragrance.
/// They are preferences, rather than claims about a perfume's ingredients.
final class Fragrance {
  Fragrance({
    required this.id,
    required String name,
    required this.temperatureBand,
    required this.humidityBand,
    String? scentNotes,
    String? photoUrl,
  }) : name = name.trim(),
       scentNotes = _optionalText(scentNotes),
       photoUrl = _optionalText(photoUrl) {
    if (id.isEmpty ||
        id == '.' ||
        id == '..' ||
        id.contains('/') ||
        utf8.encode(id).length > 1500) {
      throw ArgumentError.value(id, 'id', 'Use a valid fragrance ID.');
    }
    if (this.name.isEmpty || this.name.length > 120) {
      throw ArgumentError.value(
        name,
        'name',
        'Enter a name up to 120 characters.',
      );
    }
    if ((this.scentNotes?.length ?? 0) > 500) {
      throw ArgumentError.value(
        scentNotes,
        'scentNotes',
        'Use notes up to 500 characters.',
      );
    }
    if (this.photoUrl != null) {
      final uri = Uri.tryParse(this.photoUrl!);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw ArgumentError.value(
          photoUrl,
          'photoUrl',
          'Use an HTTP or HTTPS photo URL.',
        );
      }
    }
  }

  final String id, name;
  final String? scentNotes, photoUrl;
  final TemperatureBand temperatureBand;
  final HumidityBand humidityBand;

  static String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Document IDs live outside the stored fields, as they do for clothes.
  Map<String, Object?> toMap() => {
    'name': name,
    'scentNotes': scentNotes,
    'temperatureBand': temperatureBand.name,
    'humidityBand': humidityBand.name,
    'photoUrl': photoUrl,
  };

  factory Fragrance.fromMap(String id, Map<String, dynamic> data) {
    String requiredString(String key) {
      final value = data[key];
      if (value is! String) throw FormatException('Invalid fragrance $key.');
      return value;
    }

    String? optionalString(String key) {
      final value = data[key];
      if (value != null && value is! String) {
        throw FormatException('Invalid fragrance $key.');
      }
      return value as String?;
    }

    try {
      return Fragrance(
        id: id,
        name: requiredString('name'),
        temperatureBand: TemperatureBand.values.byName(
          requiredString('temperatureBand'),
        ),
        humidityBand: HumidityBand.values.byName(
          requiredString('humidityBand'),
        ),
        scentNotes: optionalString('scentNotes'),
        photoUrl: optionalString('photoUrl'),
      );
    } on ArgumentError catch (_) {
      throw const FormatException('Invalid fragrance fields.');
    }
  }
}

final class RankedFragrance {
  const RankedFragrance({
    required this.fragrance,
    required this.score,
    required this.reason,
  });
  final Fragrance fragrance;
  final double score;
  final String reason;
}

/// Ranks user-selected bands against observed weather; higher scores come first.
///
/// Temperatures below 20°C are Cool, 20–27°C inclusive are Mild, and above 27°C
/// are Warm. Humidity below 40% is Dry, 40–70% inclusive is Balanced, and above
/// 70% is Humid. Each mismatched band adds one penalty, plus its distance from
/// the band's boundary divided by 7°C or 30 humidity percentage points. Score
/// is 1 / (1 + total penalty), with 1 meaning both bands match. The mismatch
/// penalty keeps open boundaries distinct from inclusive boundaries at 20/27°C
/// and 40/70%. Equal scores use fragrance ID order, independent of input order.
///
/// Missing weather must be handled by the caller; this API never invents it.
List<RankedFragrance> rankFragrances({
  required Iterable<Fragrance> fragrances,
  required double temperatureC,
  required double relativeHumidity,
}) {
  if (!temperatureC.isFinite) {
    throw ArgumentError.value(
      temperatureC,
      'temperatureC',
      'Use a finite observed temperature.',
    );
  }
  if (!relativeHumidity.isFinite ||
      relativeHumidity < 0 ||
      relativeHumidity > 100) {
    throw ArgumentError.value(
      relativeHumidity,
      'relativeHumidity',
      'Use observed humidity from 0 to 100.',
    );
  }
  final ranked = <RankedFragrance>[];
  for (final fragrance in fragrances) {
    final temperatureFits = fragrance.temperatureBand.contains(temperatureC);
    final humidityFits = fragrance.humidityBand.contains(relativeHumidity);
    final penalty =
        (temperatureFits ? 0 : 1) +
        (humidityFits ? 0 : 1) +
        fragrance.temperatureBand._distance(temperatureC) / 7 +
        fragrance.humidityBand._distance(relativeHumidity) / 30;
    final temperatureReason =
        '${fragrance.temperatureBand.label} (${fragrance.temperatureBand.rangeLabel}) '
        '${temperatureFits ? 'fits the temperature' : 'is outside the temperature'}';
    final humidityReason =
        '${fragrance.humidityBand.label} (${fragrance.humidityBand.rangeLabel}) '
        '${humidityFits ? 'fits the humidity' : 'is outside the humidity'}';
    ranked.add(
      RankedFragrance(
        fragrance: fragrance,
        score: 1 / (1 + penalty),
        reason:
            '${_weatherNumber(temperatureC)}°C and ${_weatherNumber(relativeHumidity)}% humidity: '
            '$temperatureReason; $humidityReason.',
      ),
    );
  }
  ranked.sort((a, b) {
    final score = b.score.compareTo(a.score);
    return score == 0 ? a.fragrance.id.compareTo(b.fragrance.id) : score;
  });
  return List.unmodifiable(ranked);
}

String _weatherNumber(double value) => value == 0
    ? '0'
    : value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
