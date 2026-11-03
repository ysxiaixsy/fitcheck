enum ClothingCategory {
  top('Top', 'Tops'),
  bottom('Bottom', 'Bottoms'),
  shoes('Shoes', 'Shoes');

  const ClothingCategory(this.label, this.plural);
  final String label, plural;
}

enum Formality {
  casual('Casual'),
  smartCasual('Smart casual'),
  formal('Formal');

  const Formality(this.label);
  final String label;
}

enum LaundryStatus {
  clean('Clean'),
  worn('Worn'),
  toWash('To wash');

  const LaundryStatus(this.label);
  final String label;
}

class Occasion {
  const Occasion(this.id, this.name);
  final String id, name;
  static const defaults = [
    Occasion('school', 'School'),
    Occasion('work', 'Work'),
    Occasion('church', 'Church'),
    Occasion('date', 'Date'),
  ];
}

class ClothingItem {
  const ClothingItem({
    required this.id,
    required this.name,
    required this.colorName,
    required this.category,
    required this.formality,
    required this.occasionIds,
    this.tracksLaundry = true,
    this.washAfterWears = 2,
    this.wearsSinceWash = 0,
    this.lastWorn,
    this.photoUrl,
  });
  final String id, name, colorName;
  final ClothingCategory category;
  final Formality formality;
  final List<String> occasionIds;
  final bool tracksLaundry;
  final int washAfterWears, wearsSinceWash;
  final DateTime? lastWorn;
  final String? photoUrl;
  LaundryStatus get laundryStatus => !tracksLaundry || wearsSinceWash == 0
      ? LaundryStatus.clean
      : wearsSinceWash >= washAfterWears
      ? LaundryStatus.toWash
      : LaundryStatus.worn;
  Map<String, Object?> toMap() => {
    'name': name,
    'colorName': colorName,
    'category': category.name,
    'formality': formality.name,
    'occasionIds': occasionIds,
    'tracksLaundry': tracksLaundry,
    'washAfterWears': washAfterWears,
    'wearsSinceWash': wearsSinceWash,
    'lastWorn': lastWorn?.toIso8601String(),
    'photoUrl': photoUrl,
  };
  factory ClothingItem.fromMap(String id, Map<String, dynamic> data) =>
      ClothingItem(
        id: id,
        name: data['name'] as String,
        colorName: data['colorName'] as String,
        category: ClothingCategory.values.byName(data['category'] as String),
        formality: Formality.values.byName(data['formality'] as String),
        occasionIds: List<String>.from(data['occasionIds'] as List),
        tracksLaundry: data['tracksLaundry'] as bool,
        washAfterWears: data['washAfterWears'] as int,
        wearsSinceWash: data['wearsSinceWash'] as int,
        lastWorn: data['lastWorn'] == null
            ? null
            : DateTime.parse(data['lastWorn'] as String),
        photoUrl: data['photoUrl'] as String?,
      );
}

class ClothingDraft {
  const ClothingDraft({
    required this.name,
    required this.colorName,
    required this.category,
    required this.formality,
    required this.occasionIds,
    required this.tracksLaundry,
    required this.washAfterWears,
  });
  final String name, colorName;
  final ClothingCategory category;
  final Formality formality;
  final List<String> occasionIds;
  final bool tracksLaundry;
  final int washAfterWears;
  void validate() {
    if (name.trim().isEmpty || name.trim().length > 120) {
      throw ArgumentError('Enter a name up to 120 characters.');
    }
    if (colorName.trim().isEmpty || colorName.trim().length > 60) {
      throw ArgumentError('Enter a color up to 60 characters.');
    }
    if (washAfterWears < 1 || washAfterWears > 3) {
      throw ArgumentError('Wash-after must be 1–3 wears.');
    }
    if (occasionIds.isEmpty) {
      throw ArgumentError('Choose at least one occasion.');
    }
  }
}
