import 'dart:typed_data';

import 'wardrobe_models.dart';

class WardrobeFailure implements Exception {
  const WardrobeFailure(this.message);
  final String message;
}

abstract interface class WardrobeRepository {
  Stream<List<ClothingItem>> watchItems();
  Stream<List<Occasion>> watchOccasions();
  Future<void> addItem(
    ClothingDraft draft, {
    Uint8List? photo,
    String? mimeType,
  });
  Future<Occasion> addOccasion(String name);
  Future<void> markWashed(String itemId);
}
