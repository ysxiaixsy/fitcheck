import 'dart:async';
import 'dart:typed_data';

import 'package:fitcheck/wardrobe/wardrobe_models.dart';
import 'package:fitcheck/wardrobe/wardrobe_repository.dart';

class MemoryWardrobeRepository implements WardrobeRepository {
  final List<ClothingItem> items = [];
  final List<Occasion> occasions = [...Occasion.defaults];
  final _items = StreamController<List<ClothingItem>>.broadcast();
  final _occasions = StreamController<List<Occasion>>.broadcast();
  @override
  Stream<List<ClothingItem>> watchItems() async* {
    yield [...items];
    yield* _items.stream;
  }

  @override
  Stream<List<Occasion>> watchOccasions() async* {
    yield [...occasions];
    yield* _occasions.stream;
  }

  @override
  Future<void> addItem(
    ClothingDraft draft, {
    Uint8List? photo,
    String? mimeType,
  }) async {
    draft.validate();
    items.add(
      ClothingItem(
        id: '${items.length}',
        name: draft.name.trim(),
        colorName: draft.colorName.trim(),
        category: draft.category,
        formality: draft.formality,
        occasionIds: draft.occasionIds,
        tracksLaundry: draft.tracksLaundry,
        washAfterWears: draft.washAfterWears,
      ),
    );
    _items.add([...items]);
  }

  @override
  Future<Occasion> addOccasion(String name) async {
    if (name.trim().isEmpty || name.trim().length > 40) {
      throw const WardrobeFailure('Use an occasion name up to 40 characters.');
    }
    final occasion = Occasion(name.toLowerCase(), name.trim());
    occasions.add(occasion);
    _occasions.add([...occasions]);
    return occasion;
  }

  @override
  Future<void> markWashed(String itemId) async {}
  Future<void> dispose() async {
    await _items.close();
    await _occasions.close();
  }
}
