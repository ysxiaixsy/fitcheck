import 'dart:async';

import 'package:fitcheck/weather/weather_service.dart';
import 'package:fitcheck/weather/weather_store.dart';
import 'package:flutter_test/flutter_test.dart';

class LocationRepository implements WeatherLocationRepository {
  final values = StreamController<WeatherLocation?>.broadcast(sync: true);
  final saves = <WeatherLocation>[];
  final pendingSaves = <Completer<void>>[];
  bool blockSaves = false;
  int watches = 0;

  @override
  Stream<WeatherLocation?> watchLocation() {
    watches++;
    return values.stream;
  }

  @override
  Future<void> saveLocation(WeatherLocation location) {
    saves.add(location);
    if (!blockSaves) return Future.value();
    final pending = Completer<void>();
    pendingSaves.add(pending);
    return pending.future;
  }
}

class PendingWeatherService extends WeatherService {
  final requested = <WeatherLocation>[];
  final pending = <Completer<WeatherObservation>>[];
  final searches = <String>[];
  List<WeatherLocation> searchResults = [];
  Object? searchError;

  @override
  Future<WeatherObservation> currentWeather(WeatherLocation location) {
    requested.add(location);
    final response = Completer<WeatherObservation>();
    pending.add(response);
    return response.future;
  }

  @override
  Future<List<WeatherLocation>> searchLocations(String city) async {
    searches.add(city);
    if (searchError != null) throw searchError!;
    return searchResults;
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  final manila = WeatherLocation(
    id: 1,
    name: 'Manila',
    latitude: 14.6,
    longitude: 121,
  );
  final baguio = WeatherLocation(
    id: 2,
    name: 'Baguio',
    latitude: 16.4,
    longitude: 120.6,
  );
  late DateTime now;
  late LocationRepository repository;
  late PendingWeatherService service;
  late WeatherStore store;

  WeatherObservation observation(
    WeatherLocation city, {
    DateTime? observedAt,
  }) => WeatherObservation(
    location: city,
    temperatureC: city.id == 1 ? 31 : 18,
    relativeHumidity: 75,
    observedAtUTC: observedAt ?? now,
    fetchedAtUTC: now,
  );

  Future<void> load(WeatherLocation city) async {
    repository.values.add(city);
    await tick();
    service.pending.last.complete(observation(city));
    await tick();
  }

  setUp(() {
    now = DateTime.utc(2026, 11, 3, 8);
    repository = LocationRepository();
    service = PendingWeatherService();
    store = WeatherStore(
      service: service,
      repository: repository,
      clock: () => now,
    );
  });

  tearDown(() async {
    store.dispose();
    service.close();
    await repository.values.close();
  });

  test('a user with no saved city has no invented weather', () {
    expect(store.loading, isTrue);
    repository.values.add(null);
    expect(store.loading, isFalse);
    expect(store.location, isNull);
    expect(store.observation, isNull);
    expect(store.error, isNull);
    expect(service.requested, isEmpty);
  });

  test(
    'saved city fetches actual weather and stays fresh for fifteen minutes',
    () async {
      await load(manila);
      expect(store.location, manila);
      expect(store.observation!.temperatureC, 31);
      expect(store.loading, isFalse);
      now = now.add(const Duration(minutes: 14, seconds: 59));
      await store.refresh();
      await store.retry();
      expect(service.requested, hasLength(1));
      now = now.add(const Duration(seconds: 1));
      final refresh = store.refresh();
      await tick();
      expect(service.requested, hasLength(2));
      expect(store.loading, isTrue);
      service.pending.last.complete(observation(manila));
      await refresh;
      expect(store.error, isNull);
    },
  );

  test(
    'concurrent refreshes and duplicate city snapshots share one fetch',
    () async {
      repository.values.add(manila);
      final first = store.refresh();
      final second = store.refresh();
      repository.values.add(manila);
      expect(store.loading, isTrue);
      await tick();
      expect(service.requested, hasLength(1));
      service.pending.single.complete(observation(manila));
      await Future.wait([first, second]);
      expect(store.loading, isFalse);
    },
  );

  test(
    'switch clears old weather immediately and persists before fetching',
    () async {
      await load(manila);
      repository.blockSaves = true;
      final selection = store.setLocation(baguio);
      expect(store.location, baguio);
      expect(store.observation, isNull);
      expect(store.loading, isTrue);
      await tick();
      expect(repository.saves, [baguio]);
      expect(service.requested, [manila]);
      repository.pendingSaves.single.complete();
      await tick();
      expect(service.requested, [manila, baguio]);
      service.pending.last.complete(observation(baguio));
      await selection;
      expect(store.observation!.location, baguio);
    },
  );

  test('an old city response cannot overwrite a newer city', () async {
    repository.values.add(manila);
    await tick();
    repository.values.add(baguio);
    await tick();
    service.pending[1].complete(observation(baguio));
    await tick();
    service.pending[0].complete(observation(manila));
    await tick();
    expect(store.location, baguio);
    expect(store.observation!.temperatureC, 18);
    expect(store.loading, isFalse);
    expect(store.error, isNull);
  });

  test(
    'overlapping saves keep the latest city in both UI and persistence',
    () async {
      repository.blockSaves = true;
      final first = store.setLocation(manila);
      await tick();
      final second = store.setLocation(baguio);
      repository.values.add(manila);
      expect(store.location, baguio);
      repository.pendingSaves[0].complete();
      await tick();
      expect(repository.saves, [manila, baguio]);
      expect(service.requested, isEmpty);
      repository.pendingSaves[1].complete();
      await tick();
      expect(service.requested, [baguio]);
      service.pending.single.complete(observation(baguio));
      await Future.wait([first, second]);
      expect(store.location, baguio);
      expect(store.observation!.location, baguio);
    },
  );

  test(
    'a slow previous-city fetch does not delay saving the next city',
    () async {
      final first = store.setLocation(manila);
      await tick();
      expect(service.requested, [manila]);
      final second = store.setLocation(baguio);
      await tick();
      expect(repository.saves, [manila, baguio]);
      expect(service.requested, [manila, baguio]);
      service.pending[1].complete(observation(baguio));
      await second;
      service.pending[0].complete(observation(manila));
      await first;
      expect(store.observation!.location, baguio);
    },
  );

  test(
    'save failure is controlled, never fetches, and retries persistence',
    () async {
      repository.blockSaves = true;
      final selected = store.setLocation(baguio);
      final assertion = expectLater(selected, throwsA(isA<WeatherFailure>()));
      await tick();
      repository.pendingSaves.single.completeError(
        StateError('private database failure'),
      );
      await assertion;
      expect(store.error, 'Could not save your city. Please try again.');
      expect(store.loading, isFalse);
      expect(service.requested, isEmpty);
      repository.values.add(manila);
      expect(store.location, baguio);
      repository.blockSaves = false;
      final retry = store.retry();
      await tick();
      expect(repository.saves, [baguio, baguio]);
      service.pending.single.complete(observation(baguio));
      await retry;
      expect(store.error, isNull);
      expect(store.observation!.location, baguio);
    },
  );

  test(
    'weather failure is retryable while valid previous weather remains usable',
    () async {
      await load(manila);
      final oldObservation = store.observation;
      now = now.add(const Duration(minutes: 15));
      final refresh = store.refresh();
      await tick();
      service.pending.last.completeError(StateError('internal socket details'));
      await refresh;
      expect(store.observation, oldObservation);
      expect(store.error, 'Could not load the weather. Please try again.');
      final retry = store.retry();
      await tick();
      service.pending.last.complete(observation(manila));
      await retry;
      expect(service.requested, hasLength(3));
      expect(store.error, isNull);
    },
  );

  test(
    'one-hour limit is checked on reads even without a refresh event',
    () async {
      await load(manila);
      now = now.add(const Duration(hours: 1));
      expect(store.observation, isNotNull);
      now = now.add(const Duration(milliseconds: 1));
      expect(store.observation, isNull);
      final refresh = store.refresh();
      await tick();
      service.pending.last.complete(observation(manila));
      await refresh;
      expect(store.observation, isNotNull);
    },
  );

  test(
    'stale or implausibly future observations are rejected for ranking',
    () async {
      repository.values.add(manila);
      await tick();
      service.pending.last.complete(
        observation(
          manila,
          observedAt: now.subtract(const Duration(hours: 1, seconds: 1)),
        ),
      );
      await tick();
      expect(store.observation, isNull);
      expect(store.error, contains('out of date'));
      final retry = store.retry();
      await tick();
      service.pending.last.complete(
        observation(manila, observedAt: now.add(const Duration(minutes: 16))),
      );
      await retry;
      expect(store.observation, isNull);
      expect(store.error, contains('out of date'));
    },
  );

  test('location stream failure can reconnect through retry', () async {
    repository.values.addError(StateError('storage details'));
    expect(store.error, 'Could not load your saved city. Please try again.');
    expect(store.loading, isFalse);
    await store.retry();
    expect(repository.watches, 2);
    await load(manila);
    expect(store.observation, isNotNull);
    expect(store.error, isNull);
  });

  test(
    'search forwards the query and returns real results without selecting',
    () async {
      service.searchResults = [baguio];
      expect(await store.searchLocations('Bag'), [baguio]);
      expect(service.searches, ['Bag']);
      expect(store.location, isNull);
      service.searchError = StateError('transport details');
      await expectLater(
        store.searchLocations('Man'),
        throwsA(isA<WeatherFailure>()),
      );
      service.searchError = const WeatherFailure('Search unavailable.');
      await expectLater(
        store.searchLocations('Man'),
        throwsA(
          isA<WeatherFailure>().having(
            (error) => error.message,
            'message',
            'Search unavailable.',
          ),
        ),
      );
    },
  );

  test('disposal prevents pending request results and notifications', () async {
    var notifications = 0;
    store.addListener(() => notifications++);
    repository.values.add(manila);
    await tick();
    final before = notifications;
    store.dispose();
    service.pending.single.complete(observation(manila));
    await tick();
    expect(store.observation, isNull);
    expect(notifications, before);
    await store.refresh();
    await store.setLocation(baguio);
    expect(service.requested, [manila]);
    // Tear-down can safely exercise disposal only once.
    store = WeatherStore(
      service: service,
      repository: repository,
      clock: () => now,
    );
  });
}
