import 'dart:async';

import 'package:fitcheck/outfits/outfit_picker.dart';
import 'package:fitcheck/outfits/outfit_repository.dart';

class MemoryOutfitRepository implements OutfitRepository {
  final _records = <String, SavedOutfit>{};
  final _events = StreamController<SavedOutfit>.broadcast();
  @override
  Stream<SavedOutfit?> watchDate(DateTime date) async* {
    final key = outfitDateKey(date);
    yield _records[key];
    yield* _events.stream.where((value) => value.dateKey == key);
  }

  @override
  Future<void> saveSuggestion(OutfitSuggestion outfit) async {
    final record = SavedOutfit.fromSuggestion(outfit);
    if (_records[record.dateKey]?.worn == true) {
      throw const OutfitFailure('This day’s outfit is already worn.');
    }
    _records[record.dateKey] = record;
    _events.add(record);
  }

  @override
  Future<void> wear(OutfitSuggestion outfit) async {
    final record = SavedOutfit.fromSuggestion(outfit, worn: true);
    if (_records[record.dateKey]?.worn == true) return;
    _records[record.dateKey] = record;
    _events.add(record);
  }

  Future<void> dispose() => _events.close();
}
