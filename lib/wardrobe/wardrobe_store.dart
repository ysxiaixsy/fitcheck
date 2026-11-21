import 'dart:async';

import 'package:flutter/foundation.dart';

import 'wardrobe_models.dart';
import 'wardrobe_repository.dart';

class WardrobeStore extends ChangeNotifier {
  WardrobeStore(this.repository) {
    _listen();
  }
  final WardrobeRepository repository;
  List<ClothingItem> items = [];
  List<Occasion> occasions = Occasion.defaults;
  bool loading = true;
  String? _itemsError;
  String? _occasionsError;
  String? get error => _itemsError ?? _occasionsError;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _pendingRetry;
  StreamSubscription<List<ClothingItem>>? _items;
  StreamSubscription<List<Occasion>>? _occasions;
  void _listen() {
    if (_disposed) return;
    final generation = ++_generation;
    _itemsError = null;
    _occasionsError = null;
    loading = true;
    _items = repository.watchItems().listen(
      (values) {
        if (_disposed || generation != _generation) return;
        items = values;
        loading = false;
        _itemsError = null;
        notifyListeners();
      },
      onError: (_) {
        if (_disposed || generation != _generation) return;
        loading = false;
        _itemsError = 'Could not load your wardrobe. Check your connection and try again.';
        notifyListeners();
      },
    );
    _occasions = repository.watchOccasions().listen(
      (values) {
        if (_disposed || generation != _generation) return;
        occasions = values;
        _occasionsError = null;
        notifyListeners();
      },
      onError: (_) {
        if (_disposed || generation != _generation) return;
        _occasionsError = 'Could not load your occasions. Please try again.';
        notifyListeners();
      },
    );
  }

  Future<void> retry() {
    if (_disposed) return Future<void>.value();
    return _pendingRetry ??= Future<void>.microtask(_restart).whenComplete(() {
      _pendingRetry = null;
    });
  }

  Future<void> _restart() async {
    if (_disposed) return;
    _generation++;
    final cancellations = <Future<void>>[
      if (_items != null) _items!.cancel(),
      if (_occasions != null) _occasions!.cancel(),
    ];
    _items = null;
    _occasions = null;
    _itemsError = null;
    _occasionsError = null;
    loading = true;
    notifyListeners();
    try {
      await Future.wait(cancellations);
    } catch (_) {
      // Obsolete subscriptions stay excluded by their generation.
    }
    if (_disposed) return;
    _listen();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _items?.cancel().ignore();
    _occasions?.cancel().ignore();
    _items = null;
    _occasions = null;
    super.dispose();
  }
}
