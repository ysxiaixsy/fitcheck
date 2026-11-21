import 'dart:async';
import 'dart:convert';

import 'package:fitcheck/weather/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final locationData = <String, dynamic>{
    'id': 2950159,
    'name': 'Berlin',
    'latitude': 52.52437,
    'longitude': 13.41053,
    'country': 'Germany',
  };
  final location = WeatherLocation.fromMap(locationData);
  final observedAt = DateTime.utc(2026, 11, 3, 3);
  final fetchedAt = DateTime.utc(2026, 11, 3, 3, 4);

  Map<String, dynamic> currentResponse() => {
    'latitude': 52.52,
    'longitude': 13.42,
    'utc_offset_seconds': 0,
    'current_units': {
      'time': 'unixtime',
      'temperature_2m': '°C',
      'relative_humidity_2m': '%',
    },
    'current': {
      'time': observedAt.millisecondsSinceEpoch ~/ 1000,
      'temperature_2m': 12.4,
      'relative_humidity_2m': 73,
    },
  };

  WeatherService withResponse(Object json, {int status = 200}) {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode(json),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    addTearDown(client.close);
    return WeatherService(client: client, clock: () => fetchedAt);
  }

  Matcher failure([String? messagePart]) => isA<WeatherFailure>().having(
    (error) => error.message.toLowerCase(),
    'message',
    messagePart == null ? isNotEmpty : contains(messagePart.toLowerCase()),
  );

  group('WeatherLocation persistence', () {
    test('round trips validated selected city and optional country', () {
      expect(location.toMap(), locationData);
      expect(WeatherLocation.fromJson(location.toJson()).toMap(), locationData);
      final noCountry = {...locationData}..remove('country');
      expect(WeatherLocation.fromMap(noCountry).country, isNull);
      expect(WeatherLocation.fromMap(noCountry).toMap(), noCountry);
    });

    test('rejects missing, malformed, and out-of-range values', () {
      for (final invalid in [
        <String, dynamic>{},
        {...locationData, 'id': '2950159'},
        {...locationData, 'id': 0},
        {...locationData, 'name': '  '},
        {...locationData, 'latitude': '52.5'},
        {...locationData, 'latitude': -90.01},
        {...locationData, 'latitude': 90.01},
        {...locationData, 'latitude': double.nan},
        {...locationData, 'longitude': -180.01},
        {...locationData, 'longitude': 180.01},
        {...locationData, 'longitude': double.infinity},
        {...locationData, 'country': 3},
      ]) {
        expect(() => WeatherLocation.fromMap(invalid), throwsA(failure()));
      }
    });
  });

  group('city search', () {
    test(
      'uses the fixed HTTPS city endpoint and parses optional fields',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'geocoding-api.open-meteo.com');
          expect(request.url.path, '/v1/search');
          expect(request.url.queryParameters, {
            'name': 'Berlin, Germany',
            'count': '10',
            'language': 'en',
            'format': 'json',
          });
          expect(request.followRedirects, isFalse);
          return http.Response(
            jsonEncode({
              'results': [locationData],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        addTearDown(client.close);
        final results = await WeatherService(client: client)
            .searchLocations('  Berlin, Germany  ');
        expect(results.single.toMap(), locationData);
        expect(() => results.clear(), throwsUnsupportedError);
      },
    );

    test('empty and one-character queries make no request', () async {
      final client = MockClient(
        (_) async => throw StateError('Unexpected HTTP'),
      );
      addTearDown(client.close);
      final service = WeatherService(client: client);
      expect(await service.searchLocations('  '), isEmpty);
      expect(await service.searchLocations('B'), isEmpty);
      await expectLater(service.searchLocations('x' * 201), throwsA(failure()));
    });

    test('missing results and an empty list mean no matching city', () async {
      expect(await withResponse({}).searchLocations('Berlin'), isEmpty);
      expect(
        await withResponse({'results': []}).searchLocations('Berlin'),
        isEmpty,
      );
    });

    test(
      'malformed search results fail without an invented location',
      () async {
        for (final json in [
          [],
          {'error': true, 'reason': 'Invalid query'},
          {'results': null},
          {'results': {}},
          {
            'results': [null],
          },
          {
            'results': [
              {...locationData, 'latitude': 91},
            ],
          },
        ]) {
          await expectLater(
            withResponse(json).searchLocations('Berlin'),
            throwsA(failure()),
          );
        }
      },
    );
  });

  group('current weather', () {
    test(
      'requests Celsius model conditions and returns explicit UTC times',
      () async {
        final client = MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'api.open-meteo.com');
          expect(request.url.path, '/v1/forecast');
          expect(request.url.queryParameters, {
            'latitude': '52.52437',
            'longitude': '13.41053',
            'current': 'temperature_2m,relative_humidity_2m',
            'temperature_unit': 'celsius',
            'timezone': 'UTC',
            'timeformat': 'unixtime',
          });
          expect(request.followRedirects, isFalse);
          return http.Response(
            jsonEncode(currentResponse()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        addTearDown(client.close);
        final observation = await WeatherService(
          client: client,
          clock: () => fetchedAt,
        ).currentWeather(location);
        expect(observation.location, same(location));
        expect(observation.temperatureC, 12.4);
        expect(observation.relativeHumidity, 73);
        expect(observation.observedAtUTC, observedAt);
        expect(observation.fetchedAtUTC, fetchedAt);
        expect(observation.observedAtUTC.isUtc, isTrue);
        expect(observation.fetchedAtUTC.isUtc, isTrue);
      },
    );

    test('rejects missing, mistyped, or out-of-range model readings', () async {
      for (final change in [
        {'temperature_2m': null},
        {'temperature_2m': '12.4'},
        {'temperature_2m': -100.1},
        {'temperature_2m': 100.1},
        {'relative_humidity_2m': null},
        {'relative_humidity_2m': -1},
        {'relative_humidity_2m': 101},
        {'time': '2026-11-03T03:00'},
        {'time': -1},
        {'time': 253402300800},
      ]) {
        final json = currentResponse();
        json['current'] = {...json['current'] as Map, ...change};
        await expectLater(
          withResponse(json).currentWeather(location),
          throwsA(failure()),
        );
      }
    });

    test('rejects an unexpected timezone, units, or current schema', () async {
      for (final change in [
        {'utc_offset_seconds': 3600},
        {'current': null},
        {'current_units': null},
        {
          'current_units': {
            'time': 'iso8601',
            'temperature_2m': '°C',
            'relative_humidity_2m': '%',
          },
        },
        {
          'current_units': {
            'time': 'unixtime',
            'temperature_2m': '°F',
            'relative_humidity_2m': '%',
          },
        },
      ]) {
        await expectLater(
          withResponse({...currentResponse(), ...change})
              .currentWeather(location),
          throwsA(failure()),
        );
      }
    });

    test(
      'accepts humidity boundaries without substituting a default',
      () async {
        for (final humidity in [0, 100]) {
          final json = currentResponse();
          (json['current'] as Map)['relative_humidity_2m'] = humidity;
          expect(
            (await withResponse(json).currentWeather(location))
                .relativeHumidity,
            humidity,
          );
        }
      },
    );
  });

  group('request failures', () {
    test(
      'rate limit and server errors have controlled retry messages',
      () async {
        await expectLater(
          withResponse({
            'reason': 'private raw server error',
          }, status: 429).currentWeather(location),
          throwsA(failure('wait a moment')),
        );
        for (final status in [400, 302, 503]) {
          await expectLater(
            withResponse({
              'reason': 'private raw server error',
            }, status: status).currentWeather(location),
            throwsA(failure('try again')),
          );
        }
      },
    );

    test('network errors and invalid JSON never expose raw details', () async {
      for (final handler in <Future<http.Response> Function(http.Request)>[
        (_) async => throw http.ClientException('private transport details'),
        (_) async => http.Response('{broken json', 200),
      ]) {
        final client = MockClient(handler);
        addTearDown(client.close);
        await expectLater(
          WeatherService(client: client).currentWeather(location),
          throwsA(
            isA<WeatherFailure>().having(
              (error) => error.message,
              'message',
              isNot(contains('private')),
            ),
          ),
        );
      }
    });

    test(
      'a stalled HTTP request times out with a connection message',
      () async {
        final client = MockClient((_) => Completer<http.Response>().future);
        addTearDown(client.close);
        await expectLater(
          WeatherService(
            client: client,
            timeout: const Duration(milliseconds: 1),
          ).searchLocations('Berlin'),
          throwsA(failure('took too long')),
        );
      },
    );
  });
}
