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

class _Weather extends WeatherService {
  _Weather(this.clock);
  final DateTime Function() clock;
  @override
  Future<WeatherObservation> currentWeather(WeatherLocation location) async =>
      WeatherObservation(
        location: location,
        temperatureC: 31,
        relativeHumidity: 85,
        observedAtUTC: clock(),
        fetchedAtUTC: clock(),
      );
}

void main() {
  late DateTime now;
  late MemoryFragranceRepository repository;
  late FragranceStore fragrances;
  late WeatherStore weather;
  var initialized = false;
  final warm = Fragrance(
    id: 'warm',
    name: 'Fresh morning',
    temperatureBand: TemperatureBand.warm,
    humidityBand: HumidityBand.humid,
  );
  final cool = Fragrance(
    id: 'cool',
    name: 'Evening amber',
    temperatureBand: TemperatureBand.cool,
    humidityBand: HumidityBand.dry,
  );

  setUp(() {
    now = DateTime.utc(2026, 11, 3, 8);
    repository = MemoryFragranceRepository(
      seed: [cool, warm],
      location: WeatherLocation(
        id: 1,
        name: 'Iloilo',
        latitude: 10.7,
        longitude: 122.5,
      ),
    );
    initialized = false;
  });
  tearDown(() async {
    fragrances.dispose();
    weather.dispose();
    weather.service.close();
    await repository.close();
  });
  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
  }) async {
    if (!initialized) {
      fragrances = FragranceStore(repository, clock: () => now);
      weather = WeatherStore(
        service: _Weather(() => now),
        repository: repository,
        clock: () => now,
      );
      initialized = true;
    }
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? FitCheckTheme.dark : FitCheckTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TodayFragrance(
              fragrances: fragrances,
              weather: weather,
              onAdd: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fragrances.loading, isFalse, reason: 'collection readiness');
    expect(fragrances.pickLoading, isFalse, reason: 'pick readiness');
    expect(
      weather.observation,
      isNotNull,
      reason:
          'weather: ${weather.error}, loading ${weather.loading}, city ${weather.location?.name}',
    );
  }

  testWidgets(
    'sheet ranks by weather, cancel preserves pick, confirm persists choice',
    (tester) async {
      await pump(tester);
      expect(find.text('Fresh morning'), findsOneWidget);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      final warmRow = find.byKey(const ValueKey('fragrance-option-warm'));
      final coolRow = find.byKey(const ValueKey('fragrance-option-cool'));
      expect(
        tester.getTopLeft(warmRow).dy,
        lessThan(tester.getTopLeft(coolRow).dy),
      );
      await tester.tap(coolRow);
      await tester.pump();
      await tester.tap(find.byTooltip('Close change fragrance'));
      await tester.pumpAndSettle();
      expect(repository.picks, isEmpty);
      expect(find.text('Fresh morning'), findsOneWidget);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(coolRow);
      await tester.pump();
      await tester.tap(find.text('Use this fragrance'));
      await tester.pumpAndSettle();
      expect(repository.picks.values.single.fragranceId, 'cool');
      expect(find.text('Evening amber'), findsOneWidget);
      await repository.delete('cool');
      await tester.pumpAndSettle();
      expect(find.text('Fresh morning'), findsOneWidget);
    },
  );

  testWidgets(
    'save failure remains inline and cannot duplicate a pending save',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      repository.savePickGate = Completer<void>();
      repository.savePickFailure = const FragranceFailure(
        'Could not save. Try again.',
      );
      await tester.tap(find.text('Use this fragrance'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      expect(repository.savedChoices, hasLength(1));
      repository.savePickGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Could not save. Try again.'), findsOneWidget);
      expect(find.text('Change fragrance'), findsOneWidget);
      repository.savePickGate = null;
      repository.savePickFailure = null;
      await tester.tap(find.text('Use this fragrance'));
      await tester.pumpAndSettle();
      expect(find.text('Change fragrance'), findsNothing);
    },
  );

  testWidgets(
    'expired weather prevents confirmation without inventing a ranking',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      now = now.add(const Duration(hours: 2));
      await tester.tap(find.text('Use this fragrance'));
      await tester.pumpAndSettle();
      expect(repository.picks, isEmpty);
      expect(find.textContaining('day or weather changed'), findsOneWidget);
    },
  );

  testWidgets('both themes keep long rows usable at enlarged text', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await pump(tester, dark: dark, scale: 2);
      await tester.ensureVisible(find.text('Change'));
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Use this fragrance'));
      expect(
        tester
            .getSize(find.widgetWithText(FilledButton, 'Use this fragrance'))
            .height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byTooltip('Close change fragrance'));
      await tester.pumpAndSettle();
    }
  });
}
