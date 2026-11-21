import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'wardrobe_models.dart';
import 'wardrobe_repository.dart';

class FirestoreWardrobeRepository implements WardrobeRepository {
  FirestoreWardrobeRepository(
    String userId, {
    FirebaseFirestore? database,
    FirebaseStorage? storage,
  }) : _root = (database ?? FirebaseFirestore.instance)
           .collection('users')
           .doc(userId),
       _storage = storage ?? FirebaseStorage.instance;
  final DocumentReference<Map<String, dynamic>> _root;
  final FirebaseStorage _storage;
  @override
  Stream<List<ClothingItem>> watchItems() => _root
      .collection('clothes')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => ClothingItem.fromMap(doc.id, doc.data()))
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              ),
      );
  @override
  Stream<List<Occasion>> watchOccasions() =>
      _root.collection('occasions').snapshots().map((snapshot) {
        final values = {for (final value in Occasion.defaults) value.id: value};
        for (final doc in snapshot.docs) {
          values[doc.id] = Occasion(doc.id, doc.data()['name'] as String);
        }
        return values.values.toList();
      });
  @override
  Future<void> addItem(
    ClothingDraft draft, {
    Uint8List? photo,
    String? mimeType,
  }) async {
    draft.validate();
    final doc = _root.collection('clothes').doc();
    Reference? upload;
    try {
      String? url;
      if (photo != null) {
        if (photo.length > 5 * 1024 * 1024 ||
            !['image/jpeg', 'image/png', 'image/webp'].contains(mimeType)) {
          throw const WardrobeFailure(
            'Choose a JPG, PNG, or WebP photo smaller than 5 MB.',
          );
        }
        upload = _storage.ref('users/${_root.id}/clothes/${doc.id}/photo');
        await upload.putData(photo, SettableMetadata(contentType: mimeType));
        url = await upload.getDownloadURL();
      }
      final item = ClothingItem(
        id: doc.id,
        name: draft.name.trim(),
        colorName: draft.colorName.trim(),
        category: draft.category,
        formality: draft.formality,
        occasionIds: List.unmodifiable(draft.occasionIds),
        tracksLaundry: draft.tracksLaundry,
        washAfterWears: draft.washAfterWears,
        photoUrl: url,
      );
      await doc.set(item.toMap());
    } catch (error) {
      if (upload != null) {
        try {
          await upload.delete();
        } catch (_) {
          /* A failed upload may not exist. */
        }
      }
      if (error is WardrobeFailure) rethrow;
      throw const WardrobeFailure(
        'Could not save this item. Check your connection and try again.',
      );
    }
  }

  @override
  Future<Occasion> addOccasion(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40) {
      throw const WardrobeFailure('Use an occasion name up to 40 characters.');
    }
    final id = Uri.encodeComponent(trimmed.toLowerCase());
    final defaultMatch = Occasion.defaults.where(
      (occasion) => occasion.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (defaultMatch.isNotEmpty) return defaultMatch.first;
    final doc = _root.collection('occasions').doc(id);
    try {
      await doc.set({'name': trimmed, 'isDefault': false});
      return Occasion(id, trimmed);
    } catch (_) {
      throw const WardrobeFailure(
        'Could not save this occasion. Please try again.',
      );
    }
  }

  @override
  Future<void> markWashed(String itemId) async {
    try {
      await _root.collection('clothes').doc(itemId).update({
        'wearsSinceWash': 0,
      });
    } catch (_) {
      throw const WardrobeFailure(
        'Could not mark this item washed. Please try again.',
      );
    }
  }
}
