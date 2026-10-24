import '../domain/activity.dart';
import '../domain/connections.dart';
import '../domain/listing.dart';
import '../domain/profile.dart';
import '../domain/taxonomy.dart';
import '../matching/extraction.dart';

/// Which backend the session uses.
enum AppMode {
  /// Local, fictional data on this device. No account or network.
  demo,

  /// Real accounts and shared data through the configured backend.
  connected,
}

/// Areas of data that can change; the UI refreshes the matching queries.
enum DataTopic {
  profile,
  members,
  listings,
  saved,
  requests,
  conversations,
  messages,
  activity,
}

/// Everything the app needs from a backend, scoped to the signed-in member.
///
/// Demo and connected modes implement the same contract so screens, state
/// and matching logic are shared. Authorization is enforced inside each
/// implementation (in connected mode, by database row-level security and
/// functions), never only by hiding controls.
abstract interface class MarketplaceBackend {
  AppMode get mode;

  /// The signed-in member.
  String get currentUserId;

  /// Emits when data changes, locally or (in connected mode) remotely.
  Stream<DataTopic> get changes;

  ProfileRepository get profiles;
  ListingRepository get listings;
  SavedRepository get saved;
  ConnectionRepository get connections;
  ActivityRepository get activity;
  ProfileExtractor get extractor;

  /// Demo-only controls. Always null in connected mode.
  DemoControls? get demo;

  Future<void> dispose();
}

abstract interface class ProfileRepository {
  Future<Profile> me();

  /// Saves editable fields. [completeOnboarding] marks onboarding done.
  Future<Profile> saveMine(
    ProfileDraft draft, {
    bool completeOnboarding = false,
  });

  Future<Profile> updateSettings({
    bool? directoryVisible,
    bool? personalizationEnabled,
  });

  /// Members who opted into the directory, excluding the viewer.
  Future<List<MemberProfile>> directory();

  /// Names for the given members, plus directory details for those who
  /// opted in. Unknown or hidden members are omitted.
  Future<Map<String, MemberProfile>> members(Set<String> ids);
}

abstract interface class ListingRepository {
  /// Listings the viewer may see: every active listing, plus the viewer's
  /// own in any status.
  Future<List<Listing>> visible();

  Future<List<Listing>> mine();

  /// A single listing, or null when it does not exist or is not visible.
  Future<Listing?> byId(String id);

  Future<Listing> create(ListingDraft draft);

  /// Owner only.
  Future<Listing> update(String id, ListingDraft draft);

  /// Owner only; follows [ListingStatus.canTransitionTo].
  Future<Listing> setStatus(String id, ListingStatus status);

  /// Owner only. Requests keep their snapshot title.
  Future<void> delete(String id);
}

abstract interface class SavedRepository {
  Future<List<SavedListing>> mine();
  Future<void> save(String listingId);
  Future<void> unsave(String listingId);
}

abstract interface class ConnectionRepository {
  /// Requests the viewer sent or received.
  Future<List<ConnectionRequest>> requests();

  /// Sends a request about [listingId] (to its owner) or, with no listing,
  /// a general introduction to a member who is in the directory.
  Future<ConnectionRequest> send({
    required String recipientId,
    String? listingId,
    required String message,
  });

  /// Recipient only, from pending. Accepting opens a conversation.
  Future<ConnectionRequest> respond(String requestId, {required bool accept});

  /// Sender only, from pending.
  Future<ConnectionRequest> withdraw(String requestId);

  /// Conversations the viewer participates in.
  Future<List<Conversation>> conversations();

  /// Participants only; throws [NotAllowedException] otherwise.
  Future<Conversation> conversation(String id);

  /// Participants only.
  Future<List<Message>> messages(String conversationId);

  /// Participants only. [clientId] makes retries idempotent.
  Future<Message> sendMessage(
    String conversationId,
    String body, {
    required String clientId,
  });
}

abstract interface class ActivityRepository {
  Future<List<ActivityEvent>> mine();
  Future<void> record(ActivityType type, Listing listing);

  /// Deletes the viewer's feedback events (resets personalization).
  Future<void> reset();
}

/// Controls that exist only for the local demonstration.
abstract interface class DemoControls {
  /// All fictional members plus any created on this device.
  Future<List<Profile>> members();

  Future<void> switchTo(String userId);

  /// Creates a new local member who has not completed onboarding.
  Future<String> createMember();

  /// Restores the original fictional data. Affects demo data only.
  Future<void> reset();
}
