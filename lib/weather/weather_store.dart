import 'dart:async';

import 'package:flutter/foundation.dart';

import 'weather_service.dart';

/// Implementations are scoped to one signed-in user's saved city.
abstract interface class WeatherLocationRepository {
  Stream<WeatherLocation?> watchLocation();
  Future<void> saveLocation(WeatherLocation location);
}

class WeatherStore extends ChangeNotifier {
  WeatherStore({
    required this.service,
    required this.repository,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _listen();
  }

  final WeatherService service;
  final WeatherLocationRepository repository;
  final DateTime Function() _clock;
  static const freshness = Duration(minutes: 15);
  static const maximumObservationAge = Duration(hours: 1);
  static const _maximumFutureSkew = Duration(minutes: 15);

  WeatherLocation? _location;
  WeatherObservation? _observation;
  DateTime? _lastSuccess;
  bool _loading = true;
  String? _error;
  bool _disposed = false;
  bool _watchFailed = false;
  bool _unsavedLocation = false;
  int _selection = 0;
  int _watchGeneration = 0;
  WeatherLocation? _pendingLocation;
  StreamSubscription<WeatherLocation?>? _subscription;
  Future<void> _saveQueue = Future.value();
  Future<void>? _fetch;

  WeatherLocation? get location => _location;
  bool get loading => _loading;
  String? get error => _error;

  /// Consumers can rank fragrances only with a recent observation. Age is
  /// checked on every read, including when no notifier event has fired.
  WeatherObservation? get observation {
    final value = _observation;
    return value != null && _usable(value) ? value : null;
  }

  bool _usable(WeatherObservation value) {
    final now = _clock().toUtc();
    final age = now.difference(value.observedAtUTC);
    return age <= maximumObservationAge &&
        age >= -_maximumFutureSkew &&
        _sameLocation(value.location, _location);
  }

  static bool _sameLocation(WeatherLocation? a, WeatherLocation? b) =>
      a == null || b == null
      ? a == null && b == null
      : a.id == b.id && a.latitude == b.latitude && a.longitude == b.longitude;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _listen() {
    if (_disposed) return;
    final generation = ++_watchGeneration;
    _watchFailed = false;
    try {
      _subscription = repository.watchLocation().listen((location) {
        if (_disposed || generation != _watchGeneration) return;
        // A queued save can echo the previous city before the latest save.
        // Keep the user's current choice visible until that save finishes.
        if (_pendingLocation != null &&
            !_sameLocation(location, _pendingLocation)) {
          return;
        }
        if (_unsavedLocation && _pendingLocation == null) return;
        _watchFailed = false;
        if (!_sameLocation(_location, location)) {
          _select(location);
        } else {
          _location = location;
          if (_pendingLocation == null && !_unsavedLocation) {
            _loading = _fetch != null;
          }
          _notify();
        }
        if (location != null && !_unsavedLocation) {
          unawaited(refresh());
        }
      }, onError: (_) => _locationError(generation));
    } catch (_) {
      _locationError(generation);
    }
  }

  void _locationError(int generation) {
    if (_disposed || generation != _watchGeneration) return;
    _watchFailed = true;
    _loading = false;
    _error = 'Could not load your saved city. Please try again.';
    _notify();
  }

  void _select(WeatherLocation? selected) {
    _selection++;
    _location = selected;
    _observation = null;
    _lastSuccess = null;
    _fetch = null;
    _error = null;
    _loading = selected != null;
    _notify();
  }

  Future<List<WeatherLocation>> searchLocations(String city) async {
    if (_disposed) return const [];
    try {
      return await service.searchLocations(city);
    } on WeatherFailure {
      rethrow;
    } catch (_) {
      throw const WeatherFailure(
        'Could not search for cities. Please try again.',
      );
    }
  }

  /// Clears the previous city's weather immediately, saves the new city, then
  /// fetches conditions. Writes are serialized so the last choice also wins in
  /// storage when an earlier save completes slowly.
  Future<void> setLocation(WeatherLocation selected) {
    if (_disposed) return Future.value();
    _pendingLocation = selected;
    _unsavedLocation = true;
    _select(selected);
    final selection = _selection;
    final save = _saveQueue.then((_) async {
      if (_disposed || selection != _selection) return;
      try {
        await repository.saveLocation(selected);
      } catch (_) {
        if (!_disposed && selection == _selection) {
          _loading = false;
          _error = 'Could not save your city. Please try again.';
          _pendingLocation = null;
          _notify();
        }
        throw const WeatherFailure(
          'Could not save your city. Please try again.',
        );
      }
      if (_disposed || selection != _selection) return;
      _pendingLocation = null;
      _unsavedLocation = false;
    });
    // A failed earlier save must not prevent a later choice from persisting.
    // Queue writes only: an old city's slow network request must not delay the
    // next city's persistence or fetch.
    _saveQueue = save.catchError((_) {});
    return save.then((_) async {
      if (!_disposed && selection == _selection) await refresh();
    });
  }

  /// Successful fetches remain fresh for 15 minutes. Concurrent refreshes share
  /// one request; an error or an expired observation can be retried immediately.
  Future<void> refresh() {
    if (_disposed || _location == null) return Future.value();
    if (_unsavedLocation) {
      // Saving is already followed by a fetch; do not race it with an extra one.
      if (_pendingLocation != null) return _saveQueue;
      return setLocation(_location!).catchError((_) {});
    }
    if (_fetch != null) return _fetch!;
    final now = _clock().toUtc();
    final age = _lastSuccess == null ? null : now.difference(_lastSuccess!);
    if (_error == null &&
        observation != null &&
        age != null &&
        age >= Duration.zero &&
        age < freshness) {
      return Future.value();
    }
    final selection = _selection;
    final selected = _location!;
    _loading = true;
    _error = null;
    // Defer service work until _fetch is assigned, also covering synchronous
    // service failures and refreshes invoked from notification listeners.
    final fetch = Future<void>.microtask(() async {
      try {
        final value = await service.currentWeather(selected);
        if (_disposed || selection != _selection) return;
        if (!_usable(value)) {
          throw const WeatherFailure(
            'The weather data is out of date. Please try again.',
          );
        }
        _observation = value;
        _lastSuccess = _clock().toUtc();
      } catch (error) {
        if (_disposed || selection != _selection) return;
        _error = error is WeatherFailure
            ? error.message
            : 'Could not load the weather. Please try again.';
      } finally {
        if (!_disposed && selection == _selection) {
          _fetch = null;
          _loading = false;
          _notify();
        }
      }
    });
    _fetch = fetch;
    _notify();
    return fetch;
  }

  Future<void> retry() async {
    if (_disposed) return;
    if (_watchFailed) {
      _watchGeneration++;
      final subscription = _subscription;
      _subscription = null;
      _loading = true;
      _error = null;
      _notify();
      try {
        await subscription?.cancel();
      } catch (_) {
        // The obsolete listener is excluded by its generation.
      }
      if (_disposed) return;
      _listen();
      return;
    }
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _selection++;
    _watchGeneration++;
    _subscription?.cancel().ignore();
    _subscription = null;
    super.dispose();
  }
}
