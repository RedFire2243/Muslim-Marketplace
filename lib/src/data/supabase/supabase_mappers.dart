import '../../domain/activity.dart';
import '../../domain/connections.dart';
import '../../domain/goal.dart';
import '../../domain/json.dart';
import '../../domain/listing.dart';
import '../../domain/profile.dart';
import '../../domain/taxonomy.dart';

/// Converts between database rows (snake_case) and domain models.
abstract final class Rows {
  static Profile profile(
    Map<String, dynamic> row,
    Map<String, dynamic>? settings,
  ) => Profile(
    id: row['id'] as String,
    displayName: row['display_name'] as String? ?? '',
    headline: row['headline'] as String? ?? '',
    skills: readStrings(row['skills']),
    interests: readStrings(row['interests']),
    offeringSummary: row['offering_summary'] as String? ?? '',
    seekingSummary: row['seeking_summary'] as String? ?? '',
    goals: [
      for (final g in (settings?['goals'] as List? ?? const []))
        Goal.fromJson(asJsonMap(g)),
    ],
    areaId: readOptionalString(row['area_id']),
    openToRemote: row['open_to_remote'] as bool? ?? true,
    communityAffiliation: readOptionalString(row['community_affiliation']),
    linkedinUrl: readOptionalString(row['linkedin_url']),
    directoryVisible: row['directory_visible'] as bool? ?? false,
    personalizationEnabled:
        settings?['personalization_enabled'] as bool? ?? true,
    onboardingComplete: settings?['onboarding_complete'] as bool? ?? false,
    isSample: row['is_sample'] as bool? ?? false,
    createdAt: readDate(row['created_at']),
    updatedAt: readDate(row['updated_at']),
  );

  /// A directory profile row (others' rows contain only public columns).
  static MemberProfile member(Map<String, dynamic> row) {
    final visible = row['directory_visible'] as bool? ?? false;
    return MemberProfile(
      id: row['id'] as String,
      displayName: row['display_name'] as String? ?? '',
      isSample: row['is_sample'] as bool? ?? false,
      details: visible
          ? MemberDetails(
              headline: row['headline'] as String? ?? '',
              skills: readStrings(row['skills']),
              interests: readStrings(row['interests']),
              offeringSummary: row['offering_summary'] as String? ?? '',
              seekingSummary: row['seeking_summary'] as String? ?? '',
              areaId: readOptionalString(row['area_id']),
              communityAffiliation: readOptionalString(
                row['community_affiliation'],
              ),
              linkedinUrl: readOptionalString(row['linkedin_url']),
            )
          : null,
    );
  }

  static Map<String, dynamic> profileUpdate(ProfileDraft d) => {
    'display_name': d.displayName.trim(),
    'headline': d.headline.trim(),
    'skills': d.skills,
    'interests': d.interests,
    'offering_summary': d.offeringSummary.trim(),
    'seeking_summary': d.seekingSummary.trim(),
    'area_id': d.areaId,
    'open_to_remote': d.openToRemote,
    'community_affiliation': readOptionalString(d.communityAffiliation),
    'linkedin_url': readOptionalString(d.linkedinUrl),
    'directory_visible': d.directoryVisible,
  };

  static Listing listing(Map<String, dynamic> row) => Listing(
    id: row['id'] as String,
    ownerId: row['owner_id'] as String,
    title: row['title'] as String? ?? '',
    description: row['description'] as String? ?? '',
    type: ListingType.fromWire(row['listing_type'] as String? ?? 'service'),
    direction: ListingDirection.fromWire(
      row['direction'] as String? ?? 'offer',
    ),
    category: ListingCategory.fromWire(row['category'] as String? ?? 'other'),
    tags: readStrings(row['tags']),
    areaId: readOptionalString(row['area_id']),
    remoteAvailable: row['remote_available'] as bool? ?? false,
    compensationType: CompensationType.fromWire(
      row['compensation_type'] as String?,
    ),
    compensationDetails: readOptionalString(row['compensation_details']),
    status: ListingStatus.fromWire(row['status'] as String? ?? 'active'),
    createdAt: readDate(row['created_at']),
    updatedAt: readDate(row['updated_at']),
    closedAt: readOptionalDate(row['closed_at']),
    isSample: row['is_sample'] as bool? ?? false,
  );

  static Map<String, dynamic> listingWrite(ListingDraft d) => {
    'title': d.title.trim(),
    'description': d.description.trim(),
    'listing_type': d.type!.wire,
    'direction': d.effectiveDirection!.wire,
    'category': d.category!.wire,
    'tags': d.normalizedTags,
    'area_id': d.areaId,
    'remote_available': d.remoteAvailable,
    'compensation_type': d.compensationType?.wire,
    'compensation_details': readOptionalString(d.compensationDetails),
  };

  static SavedListing saved(Map<String, dynamic> row) => SavedListing(
    userId: row['user_id'] as String,
    listingId: row['listing_id'] as String,
    savedAt: readDate(row['saved_at']),
  );

  static ConnectionRequest request(
    Map<String, dynamic> row, {
    String? conversationId,
  }) {
    // `conversations(id)` embeds as an object (one-to-one) or a list.
    final embedded = row['conversations'];
    String? convId = conversationId;
    if (convId == null) {
      if (embedded is Map) convId = embedded['id'] as String?;
      if (embedded is List && embedded.isNotEmpty) {
        convId = (embedded.first as Map)['id'] as String?;
      }
    }
    return ConnectionRequest(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      recipientId: row['recipient_id'] as String,
      listingId: readOptionalString(row['listing_id']),
      listingTitle: readOptionalString(row['listing_title']),
      message: row['message'] as String? ?? '',
      status: RequestStatus.fromWire(row['status'] as String? ?? 'pending'),
      createdAt: readDate(row['created_at']),
      respondedAt: readOptionalDate(row['responded_at']),
      conversationId: convId,
    );
  }

  static Conversation conversation(Map<String, dynamic> row) => Conversation(
    id: row['id'] as String,
    requestId: row['request_id'] as String,
    participantIds: [
      row['participant_a'] as String,
      row['participant_b'] as String,
    ],
    listingId: readOptionalString(row['listing_id']),
    listingTitle: readOptionalString(row['listing_title']),
    createdAt: readDate(row['created_at']),
    lastMessageAt: readOptionalDate(row['last_message_at']),
    lastMessagePreview: readOptionalString(row['last_message_preview']),
    lastMessageSenderId: readOptionalString(row['last_message_sender_id']),
  );

  static Message message(Map<String, dynamic> row) => Message(
    id: row['id'] as String,
    conversationId: row['conversation_id'] as String,
    senderId: row['sender_id'] as String,
    body: row['body'] as String? ?? '',
    createdAt: readDate(row['created_at']),
    clientId: row['client_id'] as String,
  );

  static ActivityEvent? event(Map<String, dynamic> row) =>
      ActivityEvent.fromJson({
        'id': row['id'],
        'userId': row['user_id'],
        'listingId': row['listing_id'],
        'type': row['event_type'],
        'listingType': row['listing_type'],
        'category': row['category'],
        'tags': row['tags'],
        'createdAt': row['created_at'],
      });
}
