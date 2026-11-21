import 'package:cloud_firestore/cloud_firestore.dart';

import '../wardrobe/wardrobe_models.dart';
import 'outfit_picker.dart';
import 'outfit_repository.dart';

class FirestoreOutfitRepository implements OutfitRepository {
  FirestoreOutfitRepository(
    String userId, {
    FirebaseFirestore? database,
    DateTime Function()? clock,
  }) : _userId = userId,
       _database = database ?? FirebaseFirestore.instance,
       _clock = clock ?? DateTime.now;

  final String _userId;
  final FirebaseFirestore _database;
  final DateTime Function() _clock;

  DocumentReference<Map<String, dynamic>> get _root =>
      _database.collection('users').doc(_userId);

  DocumentReference<Map<String, dynamic>> _daily(DateTime date) {
    if (date.year < 1 || date.year > 9999) {
      throw const OutfitFailure('This outfit has an invalid date.');
    }
    return _root.collection('outfits').doc(outfitDateKey(date));
  }

  @override
  Stream<SavedOutfit?> watchDate(DateTime date) async* {
    final reference = _daily(date);
    try {
      await for (final snapshot in reference.snapshots()) {
        final data = snapshot.data();
        yield data == null
            ? null
            : SavedOutfit.fromMap(data, expectedDateKey: reference.id);
      }
    } on OutfitFailure {
      rethrow;
    } catch (_) {
      throw const OutfitFailure(
        'Could not load this outfit. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> saveSuggestion(OutfitSuggestion outfit) async {
    final saved = SavedOutfit.fromSuggestion(outfit);
    final reference = _daily(saved.date);
    try {
      await _database.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(reference);
        final data = snapshot.data();
        if (data != null &&
            SavedOutfit.fromMap(data, expectedDateKey: reference.id).worn) {
          throw const OutfitFailure('This day’s outfit is already worn.');
        }
        transaction.set(reference, saved.toMap());
      });
    } on OutfitFailure {
      rethrow;
    } catch (_) {
      throw const OutfitFailure(
        'Could not save this outfit. Check your connection and try again.',
      );
    }
  }

  void _requireToday(DateTime date, DateTime now) {
    if (outfitDateKey(date) != outfitDateKey(now.toLocal())) {
      throw const OutfitFailure('You can record a wear only for today.');
    }
  }

  @override
  Future<void> wear(OutfitSuggestion outfit) async {
    final worn = SavedOutfit.fromSuggestion(outfit, worn: true);
    _requireToday(worn.date, _clock());
    final reference = _daily(worn.date);
    try {
      await _database.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(reference);
        final data = snapshot.data();
        final saved = data == null
            ? null
            : SavedOutfit.fromMap(data, expectedDateKey: reference.id);
        if (saved != null &&
            (saved.topId != worn.topId ||
                saved.bottomId != worn.bottomId ||
                saved.shoesId != worn.shoesId ||
                saved.occasionId != worn.occasionId)) {
          throw const OutfitFailure(
            'This outfit changed. Refresh it before recording a wear.',
          );
        }
        if (saved?.worn == true) return;

        final pieces = <ClothingItem>[];
        final references = [
          for (final id in [worn.topId, worn.bottomId, worn.shoesId])
            _root.collection('clothes').doc(id),
        ];
        final categories = ClothingCategory.values;
        for (var i = 0; i < references.length; i++) {
          final itemSnapshot = await transaction.get(references[i]);
          final itemData = itemSnapshot.data();
          if (itemData == null) {
            throw const OutfitFailure(
              'One of these items is no longer in your wardrobe. Refresh your outfit.',
            );
          }
          ClothingItem item;
          try {
            item = ClothingItem.fromMap(itemSnapshot.id, itemData);
          } catch (_) {
            throw const OutfitFailure(
              'One of these items could not be read. Refresh your wardrobe.',
            );
          }
          if (item.category != categories[i] ||
              item.wearsSinceWash < 0 ||
              item.washAfterWears < 1 ||
              item.washAfterWears > 3 ||
              !item.occasionIds.contains(worn.occasionId)) {
            throw const OutfitFailure(
              'One of these items changed. Refresh your outfit.',
            );
          }
          if (item.laundryStatus == LaundryStatus.toWash) {
            throw const OutfitFailure(
              'One of these items needs washing. Choose a clean or worn outfit.',
            );
          }
          pieces.add(item);
        }

        final now = _clock();
        _requireToday(worn.date, now);
        final lastWorn = now.toUtc().toIso8601String();
        for (var i = 0; i < pieces.length; i++) {
          transaction.update(references[i], {
            'wearsSinceWash': pieces[i].wearsSinceWash + 1,
            'lastWorn': lastWorn,
          });
        }
        transaction.set(reference, worn.toMap());
      });
    } on OutfitFailure {
      rethrow;
    } catch (_) {
      throw const OutfitFailure(
        'Could not record this outfit. Check your connection and try again.',
      );
    }
  }
}
