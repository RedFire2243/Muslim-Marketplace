import 'areas.dart';
import 'json.dart';
import 'taxonomy.dart';

/// A published offer or request. Listings are owned by a profile but are
/// separate records: one member can offer tutoring, seek a website, and post
/// a job independently.
class Listing {
  const Listing({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.type,
    required this.direction,
    required this.category,
    this.tags = const [],
    this.areaId,
    this.remoteAvailable = false,
    this.compensationType,
    this.compensationDetails,
    this.status = ListingStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
    this.isSample = false,
  });

  final String id;
  final String ownerId;
  final String title;
  final String description;
  final ListingType type;
  final ListingDirection direction;
  final ListingCategory category;
  final List<String> tags;

  /// Where it happens in person; null when remote-only or unspecified.
  final String? areaId;
  final bool remoteAvailable;
  final CompensationType? compensationType;
  final String? compensationDetails;
  final ListingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;

  /// Fictional seed content.
  final bool isSample;

  bool get isActive => status == ListingStatus.active;
  bool get isOffer => direction == ListingDirection.offer;
  Area? get area => Areas.byId(areaId);

  String get directionLabel => type.directionLabel(direction);

  /// "Piscataway · Remote OK", "Remote", or "Location not specified".
  String get locationLabel {
    final place = area?.name;
    if (place != null && remoteAvailable) return '$place · Remote OK';
    if (place != null) return place;
    if (remoteAvailable) return 'Remote';
    return 'Location not specified';
  }

  /// "Paid · \$22/hr", "Volunteer", or null when not supplied.
  String? get compensationLabel {
    final type = compensationType?.label;
    final details = compensationDetails?.trim();
    if (type != null && details != null && details.isNotEmpty) {
      return '$type · $details';
    }
    if (type != null) return type;
    if (details != null && details.isNotEmpty) return details;
    return null;
  }

  Listing copyWith({
    String? title,
    String? description,
    ListingType? type,
    ListingDirection? direction,
    ListingCategory? category,
    List<String>? tags,
    String? Function()? areaId,
    bool? remoteAvailable,
    CompensationType? Function()? compensationType,
    String? Function()? compensationDetails,
    ListingStatus? status,
    DateTime? updatedAt,
    DateTime? Function()? closedAt,
  }) => Listing(
    id: id,
    ownerId: ownerId,
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    direction: direction ?? this.direction,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    areaId: areaId != null ? areaId() : this.areaId,
    remoteAvailable: remoteAvailable ?? this.remoteAvailable,
    compensationType: compensationType != null
        ? compensationType()
        : this.compensationType,
    compensationDetails: compensationDetails != null
        ? compensationDetails()
        : this.compensationDetails,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    closedAt: closedAt != null ? closedAt() : this.closedAt,
    isSample: isSample,
  );

  Listing applyDraft(ListingDraft draft, DateTime now) => copyWith(
    title: draft.title.trim(),
    description: draft.description.trim(),
    type: draft.type,
    direction: draft.effectiveDirection,
    category: draft.category,
    tags: draft.normalizedTags,
    areaId: () => draft.areaId,
    remoteAvailable: draft.remoteAvailable,
    compensationType: () => draft.compensationType,
    compensationDetails: () => readOptionalString(draft.compensationDetails),
    updatedAt: now,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'title': title,
    'description': description,
    'type': type.wire,
    'direction': direction.wire,
    'category': category.wire,
    'tags': tags,
    'areaId': areaId,
    'remoteAvailable': remoteAvailable,
    'compensationType': compensationType?.wire,
    'compensationDetails': compensationDetails,
    'status': status.wire,
    'createdAt': writeDate(createdAt),
    'updatedAt': writeDate(updatedAt),
    'closedAt': writeDate(closedAt),
    'isSample': isSample,
  };

  factory Listing.fromJson(Map<String, Object?> json) => Listing(
    id: json['id'] as String,
    ownerId: json['ownerId'] as String,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    type: ListingType.fromWire(json['type'] as String? ?? 'service'),
    direction: ListingDirection.fromWire(
      json['direction'] as String? ?? 'offer',
    ),
    category: ListingCategory.fromWire(json['category'] as String? ?? 'other'),
    tags: readStrings(json['tags']),
    areaId: readOptionalString(json['areaId']),
    remoteAvailable: json['remoteAvailable'] as bool? ?? false,
    compensationType: CompensationType.fromWire(
      json['compensationType'] as String?,
    ),
    compensationDetails: readOptionalString(json['compensationDetails']),
    status: ListingStatus.fromWire(json['status'] as String? ?? 'active'),
    createdAt: readDate(json['createdAt']),
    updatedAt: readDate(json['updatedAt']),
    closedAt: readOptionalDate(json['closedAt']),
    isSample: json['isSample'] as bool? ?? false,
  );

  @override
  String toString() => 'Listing($id, $title)';
}

/// Form state for creating or editing a listing.
class ListingDraft {
  const ListingDraft({
    this.title = '',
    this.description = '',
    this.type,
    this.direction,
    this.category,
    this.tags = const [],
    this.areaId,
    this.remoteAvailable = false,
    this.compensationType,
    this.compensationDetails = '',
  });

  factory ListingDraft.fromListing(Listing l) => ListingDraft(
    title: l.title,
    description: l.description,
    type: l.type,
    direction: l.direction,
    category: l.category,
    tags: l.tags,
    areaId: l.areaId,
    remoteAvailable: l.remoteAvailable,
    compensationType: l.compensationType,
    compensationDetails: l.compensationDetails ?? '',
  );

  static const titleMax = 90;
  static const descriptionMin = 20;
  static const descriptionMax = 2000;
  static const maxTags = 8;

  final String title;
  final String description;
  final ListingType? type;
  final ListingDirection? direction;
  final ListingCategory? category;
  final List<String> tags;
  final String? areaId;
  final bool remoteAvailable;
  final CompensationType? compensationType;
  final String compensationDetails;

  /// Businesses are always offers.
  ListingDirection? get effectiveDirection =>
      type == ListingType.business ? ListingDirection.offer : direction;

  List<String> get normalizedTags => normalizeTags(tags);

  ListingDraft copyWith({
    String? title,
    String? description,
    ListingType? Function()? type,
    ListingDirection? Function()? direction,
    ListingCategory? Function()? category,
    List<String>? tags,
    String? Function()? areaId,
    bool? remoteAvailable,
    CompensationType? Function()? compensationType,
    String? compensationDetails,
  }) => ListingDraft(
    title: title ?? this.title,
    description: description ?? this.description,
    type: type != null ? type() : this.type,
    direction: direction != null ? direction() : this.direction,
    category: category != null ? category() : this.category,
    tags: tags ?? this.tags,
    areaId: areaId != null ? areaId() : this.areaId,
    remoteAvailable: remoteAvailable ?? this.remoteAvailable,
    compensationType: compensationType != null
        ? compensationType()
        : this.compensationType,
    compensationDetails: compensationDetails ?? this.compensationDetails,
  );

  /// Field name to message; empty when the draft can be published.
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (type == null) errors['type'] = 'Choose what kind of listing this is.';
    if (effectiveDirection == null) {
      errors['direction'] = 'Choose whether you are offering or looking.';
    }
    if (category == null) errors['category'] = 'Choose a category.';
    final t = title.trim();
    if (t.isEmpty) {
      errors['title'] = 'Add a short title.';
    } else if (t.length < 5) {
      errors['title'] = 'Use at least 5 characters.';
    } else if (t.length > titleMax) {
      errors['title'] = 'Keep the title under $titleMax characters.';
    }
    final d = description.trim();
    if (d.isEmpty) {
      errors['description'] = 'Describe the opportunity.';
    } else if (d.length < descriptionMin) {
      errors['description'] =
          'Add a little more detail (at least $descriptionMin characters).';
    } else if (d.length > descriptionMax) {
      errors['description'] =
          'Keep the description under $descriptionMax characters.';
    }
    if (areaId == null && !remoteAvailable) {
      errors['location'] = 'Choose an area, mark it as remote, or both.';
    }
    if (areaId != null && Areas.byId(areaId) == null) {
      errors['location'] = 'Choose an area from the list.';
    }
    if (normalizedTags.length > maxTags) {
      errors['tags'] = 'Use up to $maxTags tags.';
    }
    if (compensationDetails.trim().length > 80) {
      errors['compensation'] = 'Keep compensation details under 80 characters.';
    }
    return errors;
  }
}

/// Lowercases, trims, de-duplicates and caps tags.
List<String> normalizeTags(Iterable<String> raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final tag in raw) {
    final cleaned = tag.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final stripped = cleaned.replaceAll(RegExp(r'^#'), '');
    if (stripped.isEmpty || stripped.length > 32) continue;
    if (seen.add(stripped)) out.add(stripped);
  }
  return out;
}
