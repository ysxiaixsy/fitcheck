import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherFailure implements Exception {
  const WeatherFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class WeatherLocation {
  WeatherLocation({
    required this.id,
    required String name,
    required this.latitude,
    required this.longitude,
    String? country,
  }) : name = name.trim(),
       country = country?.trim() {
    if (id <= 0 ||
        this.name.isEmpty ||
        this.name.length > 200 ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        (this.country != null &&
            (this.country!.isEmpty || this.country!.length > 200))) {
      throw const WeatherFailure(
        'This location could not be read. Search for it again.',
      );
    }
  }

  factory WeatherLocation.fromJson(Map<String, dynamic> json) =>
      WeatherLocation.fromMap(json);

  factory WeatherLocation.fromMap(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final country = json['country'];
    if (id is! int ||
        name is! String ||
        latitude is! num ||
        longitude is! num ||
        (country != null && country is! String)) {
      throw const WeatherFailure(
        'This location could not be read. Search for it again.',
      );
    }
    return WeatherLocation(
      id: id,
      name: name,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      country: country as String?,
    );
  }

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? country;

  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    if (country != null) 'country': country,
  };
}

class WeatherObservation {
  WeatherObservation({
    required this.location,
    required this.temperatureC,
    required this.relativeHumidity,
    required DateTime observedAtUTC,
    required DateTime fetchedAtUTC,
  }) : observedAtUTC = observedAtUTC.toUtc(),
       fetchedAtUTC = fetchedAtUTC.toUtc() {
    // Broad surface-weather bounds reject corrupt data without clipping a
    // location's unusually hot or cold conditions.
    if (!temperatureC.isFinite ||
        temperatureC < -100 ||
        temperatureC > 100 ||
        !relativeHumidity.isFinite ||
        relativeHumidity < 0 ||
        relativeHumidity > 100) {
      throw const WeatherFailure(
        'The weather data could not be read. Try again.',
      );
    }
  }

  final WeatherLocation location;
  final double temperatureC;
  final double relativeHumidity;
  final DateTime observedAtUTC;
  final DateTime fetchedAtUTC;
}

/// City search and current model conditions from Open-Meteo.
///
/// API contracts: https://open-meteo.com/en/docs and
/// https://open-meteo.com/en/docs/geocoding-api.
/// The free endpoints are for non-commercial use and require attribution:
/// https://open-meteo.com/en/terms. Review provider terms before release.
class WeatherService {
  WeatherService({
    http.Client? client,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _clock = clock ?? DateTime.now {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive.');
    }
  }

  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _clock;
  final Duration timeout;

  Future<List<WeatherLocation>> searchLocations(String city) async {
    final name = city.trim();
    if (name.length < 2) return const [];
    if (name.length > 200) {
      throw const WeatherFailure('Enter a shorter city name.');
    }
    final json = await _getJson(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': name,
        'count': '10',
        'language': 'en',
        'format': 'json',
      }),
    );
    final results = json['results'];
    // Open-Meteo omits empty fields, including results when no city matches.
    if (results == null && !json.containsKey('results')) return const [];
    if (results is! List) throw _unreadable;
    return List.unmodifiable([
      for (final result in results)
        if (result is Map<String, dynamic>)
          WeatherLocation.fromJson(result)
        else
          throw _unreadable,
    ]);
  }

  Future<WeatherObservation> currentWeather(WeatherLocation location) async {
    final json = await _getJson(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'current': 'temperature_2m,relative_humidity_2m',
        'temperature_unit': 'celsius',
        'timezone': 'UTC',
        'timeformat': 'unixtime',
      }),
    );
    final current = json['current'];
    final units = json['current_units'];
    if (json['utc_offset_seconds'] != 0 ||
        current is! Map<String, dynamic> ||
        units is! Map<String, dynamic> ||
        units['time'] != 'unixtime' ||
        units['temperature_2m'] != '°C' ||
        units['relative_humidity_2m'] != '%') {
      throw _unreadable;
    }
    final time = current['time'];
    final temperature = current['temperature_2m'];
    final humidity = current['relative_humidity_2m'];
    if (time is! int ||
        time < 0 ||
        time > 253402300799 ||
        temperature is! num ||
        humidity is! num) {
      throw _unreadable;
    }
    return WeatherObservation(
      location: location,
      temperatureC: temperature.toDouble(),
      relativeHumidity: humidity.toDouble(),
      observedAtUTC: DateTime.fromMillisecondsSinceEpoch(
        time * 1000,
        isUtc: true,
      ),
      fetchedAtUTC: _clock(),
    );
  }

  static const _unreadable = WeatherFailure(
    'The weather data could not be read. Try again.',
  );

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    try {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers['accept'] = 'application/json';
      final response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(timeout);
      if (response.statusCode == 429) {
        throw const WeatherFailure(
          'Weather is busy right now. Wait a moment and try again.',
        );
      }
      if (response.statusCode != 200) {
        throw const WeatherFailure(
          'Could not load the weather. Try again shortly.',
        );
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic> || json['error'] == true) {
        throw _unreadable;
      }
      return json;
    } on WeatherFailure {
      rethrow;
    } on TimeoutException {
      throw const WeatherFailure(
        'The weather request took too long. Check your connection and try again.',
      );
    } on FormatException {
      throw _unreadable;
    } catch (_) {
      throw const WeatherFailure(
        'Could not connect to the weather service. Check your connection and try again.',
      );
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
