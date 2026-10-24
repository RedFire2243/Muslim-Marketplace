import 'json.dart';
import 'taxonomy.dart';

/// Recommendation feedback events. Each has one precise meaning:
enum ActivityType {
  /// Opened a listing's details. Small, capped influence.
  viewed('viewed'),

  /// Saved a listing.
  saved('saved'),

  /// Removed a saved listing; cancels the earlier save's influence.
  unsaved('unsaved'),

  /// Sent a connection request about a listing. This records interest only;
  /// it is not an application, hire, or acceptance of any job.
  contactRequested('contact_requested'),

  /// Chose "Show less like this". Hides the listing from recommendations and
  /// lowers similar listings.
  dismissed('dismissed');

  const ActivityType(this.wire);
  final String wire;

  static ActivityType? fromWire(String value) {
    for (final t in values) {
      if (t.wire == value) return t;
    }
    return null;
  }
}

/// One recorded feedback event, with a snapshot of the listing's facets so
/// preferences stay explainable even if the listing later changes.
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.userId,
    required this.listingId,
    required this.type,
    required this.listingType,
    required this.category,
    this.tags = const [],
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String listingId;
  final ActivityType type;
  final ListingType listingType;
  final ListingCategory category;
  final List<String> tags;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'listingId': listingId,
    'type': type.wire,
    'listingType': listingType.wire,
    'category': category.wire,
    'tags': tags,
    'createdAt': writeDate(createdAt),
  };

  static ActivityEvent? fromJson(Map<String, Object?> json) {
    final type = ActivityType.fromWire(json['type'] as String? ?? '');
    if (type == null) return null;
    return ActivityEvent(
      id: json['id'] as String,
      userId: json['userId'] as String,
      listingId: json['listingId'] as String,
      type: type,
      listingType: ListingType.fromWire(json['listingType'] as String? ?? ''),
      category: ListingCategory.fromWire(json['category'] as String? ?? ''),
      tags: readStrings(json['tags']),
      createdAt: readDate(json['createdAt']),
    );
  }
}
