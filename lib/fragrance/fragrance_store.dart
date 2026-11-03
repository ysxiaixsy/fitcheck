import 'dart:async';

import 'package:flutter/foundation.dart';

import 'fragrance.dart';
import 'fragrance_repository.dart';

/// Owns one account's collection and its explicitly chosen daily scent.
class FragranceStore extends ChangeNotifier {
  FragranceStore(this.repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _date = _clock();
    _watchCollection();
    _watchPick();
  }

  final FragranceRepository repository;
  final DateTime Function() _clock;
  StreamSubscription<List<Fragrance>>? _collection;
  StreamSubscription<DailyFragrancePick?>? _pick;
  late DateTime _date;
  int _pickGeneration = 0, _collectionGeneration = 0;
  bool _disposed = false, _loading = true, _pickLoading = true;
  List<Fragrance> _items = const [];
  String? _selectedId, _collectionError, _pickError;

  List<Fragrance> get items => _items;
  String? get selectedId => _selectedId;
  String? get error => _collectionError ?? _pickError;
  bool get loading => _loading;
  bool get pickLoading => _pickLoading;
  String get dateKey => fragranceDateKey(_date);

  void _watchCollection() {
    final generation = ++_collectionGeneration;
    _collection?.cancel().ignore();
    _loading = true;
    _collectionError = null;
    try {
      _collection = repository.watchAll().listen(
        (items) {
          if (_disposed || generation != _collectionGeneration) return;
          _items = List.unmodifiable(items);
          _loading = false;
          _collectionError = null;
          notifyListeners();
        },
        onError: (_) {
          if (_disposed || generation != _collectionGeneration) return;
          _loading = false;
          _collectionError = 'Could not load your fragrances. Try again.';
          notifyListeners();
        },
      );
    } catch (_) {
      _loading = false;
      _collectionError = 'Could not load your fragrances. Try again.';
    }
  }

  void _watchPick() {
    final generation = ++_pickGeneration;
    _pick?.cancel().ignore();
    _selectedId = null;
    _pickLoading = true;
    _pickError = null;
    try {
      _pick = repository
          .watchPick(_date)
          .listen(
            (pick) {
              if (_disposed || generation != _pickGeneration) return;
              _selectedId = pick?.fragranceId;
              _pickLoading = false;
              _pickError = null;
              notifyListeners();
            },
            onError: (_) {
              if (_disposed || generation != _pickGeneration) return;
              _pickError =
                  'Could not load today’s fragrance choice. Try again.';
              _pickLoading = false;
              notifyListeners();
            },
          );
    } catch (_) {
      _pickLoading = false;
      _pickError = 'Could not load the fragrance choice for today. Try again.';
    }
  }

  void checkDay() {
    if (_disposed || fragranceDateKey(_clock()) == dateKey) return;
    _date = _clock();
    _watchPick();
    notifyListeners();
  }

  void retry() {
    if (_disposed) return;
    checkDay();
    _watchCollection();
    _watchPick();
    notifyListeners();
  }

  Future<void> choose(Fragrance fragrance) async {
    if (_disposed) {
      throw const FragranceFailure(
        'Your account changed. Open the fragrance again.',
      );
    }
    checkDay();
    if (!_items.any((item) => item.id == fragrance.id)) {
      throw const FragranceFailure('This fragrance is no longer available.');
    }
    final date = _date;
    await repository.savePick(date, fragrance.id);
    if (!_disposed && fragranceDateKey(date) == dateKey) {
      _selectedId = fragrance.id;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _collection?.cancel().ignore();
    _pick?.cancel().ignore();
    super.dispose();
  }
}
