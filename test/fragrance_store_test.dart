import 'dart:async';

import 'package:fitcheck/fragrance/fragrance.dart';
import 'package:fitcheck/fragrance/fragrance_repository.dart';
import 'package:fitcheck/fragrance/fragrance_store.dart';
import 'package:fitcheck/fragrance/today_fragrance.dart';
import 'package:fitcheck/theme/fitcheck_theme.dart';
import 'package:fitcheck/weather/weather_service.dart';
import 'package:fitcheck/weather/weather_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_fragrance_repository.dart';

final first = Fragrance(
  id: 'first',
  name: 'Chosen cool scent',
  temperatureBand: TemperatureBand.cool,
  humidityBand: HumidityBand.dry,
);
final second = Fragrance(
  id: 'second',
  name: 'Warm weather scent',
  temperatureBand: TemperatureBand.warm,
  humidityBand: HumidityBand.humid,
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

class ThrowingFragranceRepository extends MemoryFragranceRepository {
  @override
  Stream<List<Fragrance>> watchAll() =>
      throw StateError('private collection details');
  @override
  Stream<DailyFragrancePick?> watchPick(DateTime date) =>
      throw StateError('private pick details');
}

class FixedWeatherService extends WeatherService {
  FixedWeatherService(this.now);
  final DateTime now;
  @override
  Future<WeatherObservation> currentWeather(WeatherLocation location) async =>
      WeatherObservation(
        location: location,
        temperatureC: 31,
        relativeHumidity: 85,
        observedAtUTC: now,
        fetchedAtUTC: now,
      );
}

void main() {
  late DateTime now;
  late MemoryFragranceRepository repository;
  late FragranceStore store;
  bool disposed = false;

  setUp(() {
    now = DateTime(2026, 11, 3, 23, 59);
    repository = MemoryFragranceRepository(seed: [first, second]);
    store = FragranceStore(repository, clock: () => now);
    disposed = false;
  });
  tearDown(() async {
    if (!disposed) store.dispose();
    await repository.dispose();
  });

  test(
    'initial collection and saved choice finish loading independently',
    () async {
      store.dispose();
      repository.collectionReadGate = Completer<void>();
      repository.pickReadGate = Completer<void>();
      repository.picks['2026-11-03'] = DailyFragrancePick(
        dateKey: '2026-11-03',
        fragranceId: first.id,
      );
      store = FragranceStore(repository, clock: () => now);
      expect(store.loading, isTrue);
      expect(store.pickLoading, isTrue);
      repository.collectionReadGate!.complete();
      await flush();
      expect(store.items, [first, second]);
      expect(store.loading, isFalse);
      expect(store.pickLoading, isTrue);
      expect(store.selectedId, isNull);
      repository.pickReadGate!.complete();
      await flush();
      expect(store.selectedId, first.id);
      expect(store.pickLoading, isFalse);
      expect(() => store.items.clear(), throwsUnsupportedError);
    },
  );

  test(
    'choice waits for successful persistence and survives a new store',
    () async {
      await flush();
      repository.savePickGate = Completer<void>();
      final save = store.choose(first);
      expect(store.selectedId, isNull);
      repository.savePickGate!.complete();
      await save;
      expect(repository.savedChoices, [('2026-11-03', first.id)]);
      expect(store.selectedId, first.id);
      store.dispose();
      store = FragranceStore(repository, clock: () => now);
      await flush();
      expect(store.selectedId, first.id);
    },
  );

  test(
    'failed choice preserves the last saved choice and is retryable',
    () async {
      await flush();
      await store.choose(first);
      repository.savePickFailure = const FragranceFailure(
        'Could not save your fragrance. Try again.',
      );
      await expectLater(store.choose(second), throwsA(isA<FragranceFailure>()));
      expect(store.selectedId, first.id);
      expect(repository.picks['2026-11-03']!.fragranceId, first.id);
      repository.savePickFailure = null;
      await store.choose(second);
      expect(store.selectedId, second.id);
    },
  );

  test('deleted choices cannot be saved using an old item reference', () async {
    await flush();
    await repository.delete(first.id);
    await flush();
    await expectLater(store.choose(first), throwsA(isA<FragranceFailure>()));
    expect(repository.savedChoices, isEmpty);
    expect(store.items, [second]);
  });

  test(
    'midnight clears yesterday and loads the new day saved choice',
    () async {
      repository.emitPick(
        now,
        DailyFragrancePick(dateKey: '2026-11-03', fragranceId: first.id),
      );
      repository.picks['2026-11-04'] = DailyFragrancePick(
        dateKey: '2026-11-04',
        fragranceId: second.id,
      );
      await flush();
      expect(store.selectedId, first.id);
      now = now.add(const Duration(minutes: 2));
      store.checkDay();
      expect(store.dateKey, '2026-11-04');
      expect(store.selectedId, isNull);
      expect(store.pickLoading, isTrue);
      await flush();
      expect(store.selectedId, second.id);
      expect(repository.watchedDays, ['2026-11-03', '2026-11-04']);
    },
  );

  test(
    'a pending previous-day save cannot replace the next day choice',
    () async {
      await flush();
      repository.savePickGate = Completer<void>();
      final pending = store.choose(first);
      now = now.add(const Duration(minutes: 2));
      repository.picks['2026-11-04'] = DailyFragrancePick(
        dateKey: '2026-11-04',
        fragranceId: second.id,
      );
      store.checkDay();
      await flush();
      expect(store.selectedId, second.id);
      repository.savePickGate!.complete();
      await pending;
      await flush();
      expect(store.selectedId, second.id);
      expect(repository.picks['2026-11-03']!.fragranceId, first.id);
    },
  );

  test(
    'choosing after a date change uses the new local calendar day',
    () async {
      await flush();
      now = now.add(const Duration(minutes: 2));
      await store.choose(second);
      expect(repository.savedChoices, [('2026-11-04', second.id)]);
      expect(store.dateKey, '2026-11-04');
    },
  );

  test(
    'collection and choice failures remain separate through retry',
    () async {
      await flush();
      repository.collectionFailure = StateError('private collection error');
      repository.pickFailure = StateError('private pick error');
      store.retry();
      await flush();
      expect(store.loading, isFalse);
      expect(store.pickLoading, isFalse);
      expect(store.error, 'Could not load your fragrances. Try again.');
      repository.collectionFailure = null;
      store.retry();
      await flush();
      expect(store.error, contains('fragrance choice'));
      expect(store.error, isNot(contains('private')));
      repository.pickFailure = null;
      store.retry();
      await flush();
      expect(store.error, isNull);
    },
  );

  test('synchronous subscription failures remain controlled', () async {
    final failing = ThrowingFragranceRepository();
    final failedStore = FragranceStore(failing, clock: () => now);
    try {
      expect(failedStore.loading, isFalse);
      expect(failedStore.pickLoading, isFalse);
      expect(failedStore.error, 'Could not load your fragrances. Try again.');
      expect(failedStore.retry, returnsNormally);
    } finally {
      failedStore.dispose();
      await failing.dispose();
    }
  });

  test('cancelled saved-choice reads cannot publish after rollover', () async {
    store.dispose();
    repository.pickReadGate = Completer<void>();
    repository.picks['2026-11-03'] = DailyFragrancePick(
      dateKey: '2026-11-03',
      fragranceId: first.id,
    );
    store = FragranceStore(repository, clock: () => now);
    final previousRead = repository.pickReadGate!;
    repository.pickReadGate = null;
    now = now.add(const Duration(minutes: 2));
    repository.picks['2026-11-04'] = DailyFragrancePick(
      dateKey: '2026-11-04',
      fragranceId: second.id,
    );
    store.checkDay();
    await flush();
    previousRead.complete();
    await flush();
    expect(store.dateKey, '2026-11-04');
    expect(store.selectedId, second.id);
  });

  test(
    'disposed account cannot save or publish into another account',
    () async {
      await flush();
      var notifications = 0;
      store.addListener(() => notifications++);
      await store.choose(first);
      store.dispose();
      disposed = true;
      final before = notifications;
      final otherRepository = MemoryFragranceRepository(seed: [second]);
      final other = FragranceStore(otherRepository, clock: () => now);
      try {
        await expectLater(
          store.choose(first),
          throwsA(isA<FragranceFailure>()),
        );
        await repository.upsert(first);
        repository.emitPick(
          now,
          DailyFragrancePick(dateKey: '2026-11-03', fragranceId: first.id),
        );
        await flush();
        expect(notifications, before);
        expect(other.items, [second]);
        expect(other.selectedId, isNull);
        expect(otherRepository.picks, isEmpty);
      } finally {
        other.dispose();
        await otherRepository.dispose();
      }
    },
  );

  testWidgets(
    'Today waits for saved choice and falls back after its fragrance is deleted',
    (tester) async {
      final current = DateTime(2026, 11, 3, 8);
      final city = WeatherLocation(
        id: 1,
        name: 'Manila',
        latitude: 14.6,
        longitude: 121,
      );
      final data = MemoryFragranceRepository(
        seed: [first, second],
        location: city,
        savedPicks: [
          DailyFragrancePick(dateKey: '2026-11-03', fragranceId: first.id),
        ],
      )..pickReadGate = Completer<void>();
      final fragrances = FragranceStore(data, clock: () => current);
      final service = FixedWeatherService(current);
      final weather = WeatherStore(
        service: service,
        repository: data,
        clock: () => current,
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: FitCheckTheme.light,
            home: Scaffold(
              body: TodayFragrance(
                fragrances: fragrances,
                weather: weather,
                onAdd: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(first.name), findsNothing);
        expect(find.text(second.name), findsNothing);
        data.pickReadGate!.complete();
        await tester.pumpAndSettle();
        expect(find.text(first.name), findsOneWidget);
        expect(find.text(second.name), findsNothing);
        await data.delete(first.id);
        await tester.pumpAndSettle();
        expect(find.text(first.name), findsNothing);
        expect(find.text(second.name), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fragrances.dispose();
        weather.dispose();
        service.close();
        await data.dispose();
      }
    },
  );
}
