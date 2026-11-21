import '../wardrobe/wardrobe_models.dart';

/// Reservation keys use the user's local calendar date, without a time or zone.
String outfitDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

typedef ItemReservations = Map<String, Set<String>>;

sealed class OutfitSelection {
  const OutfitSelection({required this.date, required this.occasion});
  final DateTime date;
  final Occasion occasion;
}

final class OutfitSuggestion extends OutfitSelection {
  OutfitSuggestion({
    required super.date,
    required super.occasion,
    required this.top,
    required this.bottom,
    required this.shoes,
    required this.reason,
  });

  final ClothingItem top, bottom, shoes;
  final String reason;

  List<ClothingItem> get pieces => [top, bottom, shoes];
  Set<String> get itemIds => {top.id, bottom.id, shoes.id};
}

final class MissingOutfitItems extends OutfitSelection {
  MissingOutfitItems({
    required super.date,
    required super.occasion,
    required Set<ClothingCategory> categories,
  }) : categories = Set.unmodifiable(categories);

  /// Missing categories reflect the current filters, including swap exclusions.
  final Set<ClothingCategory> categories;
}

/// Resolves a known planned occasion, or the most frequently used known occasion.
///
/// The caller supplies actual use counts. Equal counts use ID order, so a
/// storage query's ordering cannot silently change an unplanned day's occasion.
/// An unknown planned ID returns null rather than choosing a different plan.
Occasion? resolveOutfitOccasion({
  required Iterable<Occasion> occasions,
  String? plannedOccasionId,
  Map<String, int> useCounts = const {},
}) {
  final available = occasions.toList();
  if (plannedOccasionId != null) {
    for (final occasion in available) {
      if (occasion.id == plannedOccasionId) return occasion;
    }
    return null;
  }
  if (useCounts.values.any((count) => count < 0)) {
    throw ArgumentError.value(
      useCounts,
      'useCounts',
      'Counts must be nonnegative.',
    );
  }
  available.sort((a, b) {
    final frequency = (useCounts[b.id] ?? 0).compareTo(useCounts[a.id] ?? 0);
    return frequency != 0 ? frequency : a.id.compareTo(b.id);
  });
  return available.firstOrNull;
}

/// Pure, deterministic outfit selection; it neither records wears nor mutates
/// garments. Reservations remain independent of the underlying laundry state.
class OutfitPicker {
  const OutfitPicker();

  OutfitSelection pick({
    required Iterable<ClothingItem> items,
    required DateTime date,
    required Occasion occasion,
    ItemReservations reservations = const {},
    Set<String> excludeItemIds = const {},
    double? temperatureC,
  }) {
    if (temperatureC != null && !temperatureC.isFinite) {
      throw ArgumentError.value(
        temperatureC,
        'temperatureC',
        'Use a finite temperature.',
      );
    }
    final day = DateTime(date.year, date.month, date.day);
    final eligible = _eligible(
      items,
      date: day,
      occasionId: occasion.id,
      reservations: reservations,
      excludeItemIds: excludeItemIds,
    );
    final byCategory = {
      for (final category in ClothingCategory.values)
        category: eligible.where((item) => item.category == category).toList()
          ..sort(_compareRecency),
    };
    final missing = {
      for (final entry in byCategory.entries)
        if (entry.value.isEmpty) entry.key,
    };
    if (missing.isNotEmpty) {
      return MissingOutfitItems(
        date: day,
        occasion: occasion,
        categories: missing,
      );
    }

    // Only the oldest candidate of each formality can win within its group.
    // This bounds the search to 3 × 3 × 3 combinations even for large wardrobes.
    List<ClothingItem> oldestPerFormality(ClothingCategory category) => [
      for (final formality in Formality.values)
        ?byCategory[category]!
            .where((item) => item.formality == formality)
            .firstOrNull,
    ];
    final ranks = {
      for (final candidates in byCategory.values)
        for (var i = 0; i < candidates.length; i++) candidates[i].id: i,
    };
    _Combination? best;
    for (final top in oldestPerFormality(ClothingCategory.top)) {
      for (final bottom in oldestPerFormality(ClothingCategory.bottom)) {
        for (final shoes in oldestPerFormality(ClothingCategory.shoes)) {
          final candidate = _Combination([top, bottom, shoes], ranks);
          if (best == null || candidate.compareTo(best) < 0) best = candidate;
        }
      }
    }
    final chosen = best!.items;
    final matching = chosen.map((item) => item.formality).toSet().length == 1;
    final reason = StringBuffer('For ${occasion.name}');
    if (matching) {
      reason.write(
        ' with matching ${chosen.first.formality.label.toLowerCase()} pieces',
      );
    }
    reason.write('.');
    if (temperatureC != null) {
      final temperature = temperatureC == temperatureC.roundToDouble()
          ? temperatureC.toInt().toString()
          : temperatureC.toStringAsFixed(1);
      // Weather is reported as a fact; this picker does not infer fabric warmth.
      reason.write(' $temperature°C today.');
    }
    return OutfitSuggestion(
      date: day,
      occasion: occasion,
      top: chosen[0],
      bottom: chosen[1],
      shoes: chosen[2],
      reason: reason.toString(),
    );
  }

  /// Uses the same eligibility rules as [pick]. The current item comes first
  /// only while it remains eligible; preferred formality ranks alternatives.
  List<ClothingItem> swapCandidates({
    required Iterable<ClothingItem> items,
    required DateTime date,
    required Occasion occasion,
    required ClothingCategory category,
    String? currentItemId,
    Formality? preferredFormality,
    ItemReservations reservations = const {},
    Set<String> excludeItemIds = const {},
  }) {
    final eligible = _eligible(
      items,
      date: date,
      occasionId: occasion.id,
      reservations: reservations,
      excludeItemIds: excludeItemIds,
    ).where((item) => item.category == category).toList();
    eligible.sort((a, b) {
      if (a.id == currentItemId && b.id != currentItemId) return -1;
      if (b.id == currentItemId && a.id != currentItemId) return 1;
      if (preferredFormality != null) {
        final aMatches = a.formality == preferredFormality;
        final bMatches = b.formality == preferredFormality;
        if (aMatches != bMatches) return aMatches ? -1 : 1;
      }
      return _compareRecency(a, b);
    });
    return List.unmodifiable(eligible);
  }

  Iterable<ClothingItem> _eligible(
    Iterable<ClothingItem> items, {
    required DateTime date,
    required String occasionId,
    required ItemReservations reservations,
    required Set<String> excludeItemIds,
  }) sync* {
    final day = outfitDateKey(date);
    for (final item in items) {
      if (excludeItemIds.contains(item.id) ||
          !item.occasionIds.contains(occasionId) ||
          item.laundryStatus == LaundryStatus.toWash) {
        continue;
      }
      final holds = reservations[item.id];
      if (holds != null &&
          !holds.contains(day) &&
          holds.any((heldDay) => heldDay.compareTo(day) >= 0)) {
        continue;
      }
      yield item;
    }
  }

  static int _compareRecency(ClothingItem a, ClothingItem b) {
    if (a.lastWorn == null && b.lastWorn != null) return -1;
    if (b.lastWorn == null && a.lastWorn != null) return 1;
    final worn = a.lastWorn?.compareTo(b.lastWorn!) ?? 0;
    return worn != 0 ? worn : a.id.compareTo(b.id);
  }
}

class _Combination implements Comparable<_Combination> {
  _Combination(this.items, Map<String, int> ranks)
    : formalityCount = items.map((item) => item.formality).toSet().length,
      recencyRank = items.fold(0, (total, item) => total + ranks[item.id]!);
  final List<ClothingItem> items;
  final int formalityCount, recencyRank;

  @override
  int compareTo(_Combination other) {
    final matching = formalityCount.compareTo(other.formalityCount);
    if (matching != 0) return matching;
    // Matching formality takes precedence, followed by the sum of the three
    // category-specific recency ranks and stable piece IDs.
    final recency = recencyRank.compareTo(other.recencyRank);
    if (recency != 0) return recency;
    for (var i = 0; i < items.length; i++) {
      final id = items[i].id.compareTo(other.items[i].id);
      if (id != 0) return id;
    }
    return 0;
  }
}
