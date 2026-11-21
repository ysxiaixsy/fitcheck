import 'dart:convert';

import '../wardrobe/wardrobe_models.dart';
import 'outfit_picker.dart';

class OutfitFailure implements Exception {
  const OutfitFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

final class SavedOutfit {
  SavedOutfit({
    required DateTime date,
    required this.topId,
    required this.bottomId,
    required this.shoesId,
    required this.occasionId,
    required this.reason,
    this.worn = false,
  }) : date = DateTime(date.year, date.month, date.day) {
    if (date.year < 1 || date.year > 9999) {
      throw const OutfitFailure('This outfit has an invalid date.');
    }
    for (final id in [topId, bottomId, shoesId, occasionId]) {
      if (id.isEmpty ||
          id == '.' ||
          id == '..' ||
          id.contains('/') ||
          utf8.encode(id).length > 1500) {
        throw const OutfitFailure(
          'This outfit contains an invalid item or occasion.',
        );
      }
    }
    if (itemIds.length != 3) {
      throw const OutfitFailure(
        'An outfit needs three different clothing items.',
      );
    }
    if (reason.trim().isEmpty ||
        reason.length > 500 ||
        reason.contains(RegExp(r'[\r\n]'))) {
      throw const OutfitFailure('This outfit needs a short, one-line reason.');
    }
  }

  final DateTime date;
  final String topId, bottomId, shoesId, occasionId, reason;
  final bool worn;

  String get dateKey => outfitDateKey(date);
  Set<String> get itemIds => Set.unmodifiable({topId, bottomId, shoesId});

  factory SavedOutfit.fromSuggestion(
    OutfitSuggestion outfit, {
    bool worn = false,
  }) {
    if (outfit.top.category != ClothingCategory.top ||
        outfit.bottom.category != ClothingCategory.bottom ||
        outfit.shoes.category != ClothingCategory.shoes) {
      throw const OutfitFailure(
        'Choose a top, a bottom, and shoes for this outfit.',
      );
    }
    return SavedOutfit(
      date: outfit.date,
      topId: outfit.top.id,
      bottomId: outfit.bottom.id,
      shoesId: outfit.shoes.id,
      occasionId: outfit.occasion.id,
      reason: outfit.reason,
      worn: worn,
    );
  }

  factory SavedOutfit.fromMap(
    Map<String, dynamic> data, {
    String? expectedDateKey,
  }) {
    String stringField(String name) {
      final value = data[name];
      if (value is! String) {
        throw const OutfitFailure(
          'This saved outfit could not be read. Please refresh it.',
        );
      }
      return value;
    }

    final key = stringField('date');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
      throw const OutfitFailure('This saved outfit has an invalid date.');
    }
    final date = DateTime(
      int.parse(key.substring(0, 4)),
      int.parse(key.substring(5, 7)),
      int.parse(key.substring(8, 10)),
    );
    if (outfitDateKey(date) != key ||
        (expectedDateKey != null && expectedDateKey != key)) {
      throw const OutfitFailure(
        'This saved outfit belongs to a different or invalid day.',
      );
    }
    final worn = data['worn'];
    if (worn is! bool) {
      throw const OutfitFailure(
        'This saved outfit has an invalid wear status.',
      );
    }
    return SavedOutfit(
      date: date,
      topId: stringField('topId'),
      bottomId: stringField('bottomId'),
      shoesId: stringField('shoesId'),
      occasionId: stringField('occasionId'),
      reason: stringField('reason'),
      worn: worn,
    );
  }

  Map<String, Object?> toMap() => {
    'date': dateKey,
    'topId': topId,
    'bottomId': bottomId,
    'shoesId': shoesId,
    'occasionId': occasionId,
    'reason': reason,
    'worn': worn,
  };

  /// Restores references for display, including a worn outfit's now-dirty items.
  /// Eligibility is checked when selecting or recording another wear.
  OutfitSuggestion? resolve({
    required List<ClothingItem> items,
    required List<Occasion> occasions,
  }) {
    final byId = {for (final item in items) item.id: item};
    final top = byId[topId], bottom = byId[bottomId], shoes = byId[shoesId];
    final occasion = occasions
        .where((value) => value.id == occasionId)
        .firstOrNull;
    if (top == null ||
        bottom == null ||
        shoes == null ||
        occasion == null ||
        top.category != ClothingCategory.top ||
        bottom.category != ClothingCategory.bottom ||
        shoes.category != ClothingCategory.shoes) {
      return null;
    }
    return OutfitSuggestion(
      date: date,
      occasion: occasion,
      top: top,
      bottom: bottom,
      shoes: shoes,
      reason: reason,
    );
  }
}

abstract interface class OutfitRepository {
  Stream<SavedOutfit?> watchDate(DateTime date);
  Future<void> saveSuggestion(OutfitSuggestion outfit);
  Future<void> wear(OutfitSuggestion outfit);
}
