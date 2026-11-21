import 'dart:convert';
import 'dart:typed_data';

import '../weather/weather_store.dart';
import 'fragrance.dart';

class FragranceFailure implements Exception {
  const FragranceFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

String fragranceDateKey(DateTime date) {
  if (date.year < 1 || date.year > 9999) {
    throw const FragranceFailure('Choose a valid day for this fragrance.');
  }
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

void validateFragranceId(String id) {
  if (id.isEmpty ||
      id == '.' ||
      id == '..' ||
      id.contains('/') ||
      utf8.encode(id).length > 1500) {
    throw const FragranceFailure('This fragrance could not be found.');
  }
}

final class DailyFragrancePick {
  DailyFragrancePick({required this.dateKey, required this.fragranceId}) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateKey)) {
      throw const FragranceFailure('This saved fragrance has an invalid day.');
    }
    final date = DateTime(
      int.parse(dateKey.substring(0, 4)),
      int.parse(dateKey.substring(5, 7)),
      int.parse(dateKey.substring(8, 10)),
    );
    if (fragranceDateKey(date) != dateKey) {
      throw const FragranceFailure('This saved fragrance has an invalid day.');
    }
    validateFragranceId(fragranceId);
  }

  factory DailyFragrancePick.fromMap(
    Map<String, dynamic> data, {
    String? expectedDateKey,
  }) {
    final date = data['date'];
    final fragranceId = data['fragranceId'];
    if (date is! String ||
        fragranceId is! String ||
        (expectedDateKey != null && date != expectedDateKey)) {
      throw const FragranceFailure(
        'This saved fragrance could not be read. Try again.',
      );
    }
    return DailyFragrancePick(dateKey: date, fragranceId: fragranceId);
  }

  final String dateKey, fragranceId;

  Map<String, Object?> toMap() => {'date': dateKey, 'fragranceId': fragranceId};
}

abstract interface class FragranceRepository
    implements WeatherLocationRepository {
  String createId();
  Stream<List<Fragrance>> watchAll();
  Future<void> upsert(
    Fragrance fragrance, {
    Uint8List? photo,
    String? mimeType,
  });
  Future<void> delete(String id);
  Stream<DailyFragrancePick?> watchPick(DateTime date);
  Future<void> savePick(DateTime date, String fragranceId);
}
