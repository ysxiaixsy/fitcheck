import 'dart:async';
import 'dart:typed_data';

import 'package:fitcheck/fragrance/fragrance.dart';
import 'package:fitcheck/fragrance/fragrance_repository.dart';
import 'package:fitcheck/weather/weather_service.dart';

/// One isolated account's collection, city, and daily choices for tests.
class MemoryFragranceRepository implements FragranceRepository {
  MemoryFragranceRepository({
    Iterable<Fragrance> seed = const [],
    this.location,
    Iterable<DailyFragrancePick> savedPicks = const [],
  }) : items = [...seed],
       picks = {for (final pick in savedPicks) pick.dateKey: pick};

  final List<Fragrance> items;
  final Map<String, DailyFragrancePick> picks;
  WeatherLocation? location;
  Object? collectionFailure, pickFailure, locationFailure;
  Object? savePickFailure, saveLocationFailure, upsertFailure, deleteFailure;
  Completer<void>? collectionReadGate,
      pickReadGate,
      locationReadGate,
      savePickGate;
  final watchedDays = <String>[];
  final savedChoices = <(String, String)>[];
  int collectionWatches = 0;
  int _nextId = 0;
  bool _closed = false;
  final _collection = StreamController<List<Fragrance>>.broadcast(sync: true);
  final _locations = StreamController<WeatherLocation?>.broadcast(sync: true);
  final _picks = StreamController<(String, DailyFragrancePick?)>.broadcast(
    sync: true,
  );

  Stream<T> _watch<T>(
    Stream<T> events,
    T Function() initial,
    Object? Function() failure,
    Completer<void>? gate,
  ) => Stream<T>.multi((controller) {
    var ready = gate == null;
    var cancelled = false;
    final subscription = events.listen(
      (value) {
        if (ready && !cancelled) controller.add(value);
      },
      onError: (Object error, StackTrace stack) {
        if (ready && !cancelled) controller.addError(error, stack);
      },
      onDone: controller.close,
    );
    controller.onCancel = () {
      cancelled = true;
      return subscription.cancel();
    };
    void emitInitial() {
      if (cancelled || _closed) return;
      ready = true;
      final error = failure();
      if (error != null) {
        controller.addError(error);
      } else {
        controller.add(initial());
      }
    }

    if (gate == null) {
      emitInitial();
    } else {
      gate.future.then((_) => emitInitial());
    }
  });

  @override
  String createId() {
    String id;
    do {
      id = 'memory-fragrance-${++_nextId}';
    } while (items.any((item) => item.id == id));
    return id;
  }

  @override
  Stream<List<Fragrance>> watchAll() {
    collectionWatches++;
    return _watch(
      _collection.stream,
      () => List.unmodifiable(items),
      () => collectionFailure,
      collectionReadGate,
    );
  }

  void emitAll() => _collection.add(List.unmodifiable(items));
  void failCollection(Object error) => _collection.addError(error);

  @override
  Future<void> upsert(
    Fragrance fragrance, {
    Uint8List? photo,
    String? mimeType,
  }) async {
    if (upsertFailure != null) throw upsertFailure!;
    final index = items.indexWhere((item) => item.id == fragrance.id);
    if (index < 0) {
      items.add(fragrance);
    } else {
      items[index] = fragrance;
    }
    emitAll();
  }

  @override
  Future<void> delete(String id) async {
    if (deleteFailure != null) throw deleteFailure!;
    items.removeWhere((item) => item.id == id);
    emitAll();
  }

  @override
  Stream<DailyFragrancePick?> watchPick(DateTime date) {
    final key = fragranceDateKey(date);
    watchedDays.add(key);
    return _watch(
      _picks.stream.where((event) => event.$1 == key).map((event) => event.$2),
      () => picks[key],
      () => pickFailure,
      pickReadGate,
    );
  }

  void emitPick(DateTime date, DailyFragrancePick? pick) {
    final key = fragranceDateKey(date);
    if (pick == null) {
      picks.remove(key);
    } else {
      picks[key] = pick;
    }
    _picks.add((key, pick));
  }

  void failPick(Object error) => _picks.addError(error);

  @override
  Future<void> savePick(DateTime date, String fragranceId) async {
    final key = fragranceDateKey(date);
    savedChoices.add((key, fragranceId));
    await savePickGate?.future;
    if (savePickFailure != null) throw savePickFailure!;
    if (!items.any((item) => item.id == fragranceId)) {
      throw const FragranceFailure('This fragrance is no longer available.');
    }
    emitPick(date, DailyFragrancePick(dateKey: key, fragranceId: fragranceId));
  }

  @override
  Stream<WeatherLocation?> watchLocation() => _watch(
    _locations.stream,
    () => location,
    () => locationFailure,
    locationReadGate,
  );

  void emitLocation(WeatherLocation? value) {
    location = value;
    _locations.add(value);
  }

  @override
  Future<void> saveLocation(WeatherLocation selected) async {
    if (saveLocationFailure != null) throw saveLocationFailure!;
    emitLocation(selected);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait([
      _collection.close(),
      _locations.close(),
      _picks.close(),
    ]);
  }

  Future<void> dispose() => close();
}
