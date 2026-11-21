import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../weather/weather_service.dart';
import 'fragrance.dart';
import 'fragrance_repository.dart';

class FirestoreFragranceRepository implements FragranceRepository {
  FirestoreFragranceRepository(
    String userId, {
    FirebaseFirestore? database,
    FirebaseStorage? storage,
  }) : _root = (database ?? FirebaseFirestore.instance)
           .collection('users')
           .doc(userId),
       _storage = storage ?? FirebaseStorage.instance {
    validateFragranceId(userId);
  }

  final DocumentReference<Map<String, dynamic>> _root;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _fragrances =>
      _root.collection('fragrances');

  DocumentReference<Map<String, dynamic>> get _weather =>
      _root.collection('settings').doc('weather');

  @override
  String createId() => _fragrances.doc().id;

  @override
  Stream<List<Fragrance>> watchAll() async* {
    try {
      await for (final snapshot in _fragrances.snapshots()) {
        final values =
            [
              for (final doc in snapshot.docs)
                Fragrance.fromMap(doc.id, doc.data()),
            ]..sort((a, b) {
              final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
              return name == 0 ? a.id.compareTo(b.id) : name;
            });
        yield List.unmodifiable(values);
      }
    } catch (_) {
      throw const FragranceFailure(
        'Could not load your fragrances. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> upsert(
    Fragrance fragrance, {
    Uint8List? photo,
    String? mimeType,
  }) async {
    validateFragranceId(fragrance.id);
    if (photo != null &&
        (photo.isEmpty ||
            photo.length > 5 * 1024 * 1024 ||
            !['image/jpeg', 'image/png', 'image/webp'].contains(mimeType))) {
      throw const FragranceFailure(
        'Choose a JPG, PNG, or WebP photo smaller than 5 MB.',
      );
    }
    final reference = _fragrances.doc(fragrance.id);
    Reference? upload;
    var writeStarted = false;
    try {
      var saved = fragrance;
      if (photo != null) {
        // A replacement never overwrites the photo used by the current record.
        upload = _storage.ref(
          'users/${_root.id}/fragrances/${fragrance.id}/photos/${createId()}',
        );
        await upload.putData(photo, SettableMetadata(contentType: mimeType));
        final url = await upload.getDownloadURL();
        saved = Fragrance(
          id: fragrance.id,
          name: fragrance.name,
          scentNotes: fragrance.scentNotes,
          temperatureBand: fragrance.temperatureBand,
          humidityBand: fragrance.humidityBand,
          photoUrl: url,
        );
      }
      writeStarted = true;
      await reference.set(saved.toMap());
      if (upload != null && fragrance.photoUrl != saved.photoUrl) {
        await _deleteOwnedPhoto(fragrance.id, fragrance.photoUrl);
      }
    } catch (error) {
      if (!writeStarted && upload != null) {
        try {
          await upload.delete();
        } catch (_) {
          // A failed upload might not exist.
        }
      }
      // A failed document acknowledgement can be ambiguous. Keep a successful
      // upload rather than deleting a photo a committed record might reference.
      if (error is FragranceFailure) rethrow;
      throw const FragranceFailure(
        'Could not save this fragrance. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    validateFragranceId(id);
    try {
      final reference = _fragrances.doc(id);
      final snapshot = await reference.get();
      final photoUrl = snapshot.data()?['photoUrl'];
      await reference.delete();
      if (photoUrl is String) await _deleteOwnedPhoto(id, photoUrl);
    } catch (_) {
      throw const FragranceFailure(
        'Could not delete this fragrance. Check your connection and try again.',
      );
    }
  }

  Future<void> _deleteOwnedPhoto(String id, String? url) async {
    if (url == null) return;
    try {
      final photo = _storage.refFromURL(url);
      final prefix = 'users/${_root.id}/fragrances/$id/photos/';
      if (photo.bucket == _storage.ref().bucket &&
          photo.fullPath.startsWith(prefix)) {
        await photo.delete();
      }
    } catch (_) {
      // The record is already saved/deleted. Failed photo cleanup must not make
      // the user repeat that operation or target an unrelated/external image.
    }
  }

  @override
  Stream<WeatherLocation?> watchLocation() async* {
    try {
      await for (final snapshot in _weather.snapshots()) {
        final data = snapshot.data();
        yield data == null ? null : WeatherLocation.fromMap(data);
      }
    } catch (_) {
      throw const FragranceFailure(
        'Could not load your weather location. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> saveLocation(WeatherLocation location) async {
    try {
      await _weather.set(location.toMap());
    } catch (_) {
      throw const FragranceFailure(
        'Could not save this location. Check your connection and try again.',
      );
    }
  }

  @override
  Stream<DailyFragrancePick?> watchPick(DateTime date) async* {
    final key = fragranceDateKey(date);
    try {
      await for (final snapshot
          in _root.collection('fragrancePicks').doc(key).snapshots()) {
        final data = snapshot.data();
        yield data == null
            ? null
            : DailyFragrancePick.fromMap(data, expectedDateKey: key);
      }
    } catch (_) {
      throw const FragranceFailure(
        'Could not load this day’s fragrance. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> savePick(DateTime date, String fragranceId) async {
    final pick = DailyFragrancePick(
      dateKey: fragranceDateKey(date),
      fragranceId: fragranceId,
    );
    try {
      await _root
          .collection('fragrancePicks')
          .doc(pick.dateKey)
          .set(pick.toMap());
    } catch (_) {
      throw const FragranceFailure(
        'Could not save this day’s fragrance. Check your connection and try again.',
      );
    }
  }
}
