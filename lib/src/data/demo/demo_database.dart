import '../../domain/activity.dart';
import '../../domain/connections.dart';
import '../../domain/json.dart';
import '../../domain/listing.dart';
import '../../domain/profile.dart';
import '../seed/seed_data.dart';

/// The whole local demonstration dataset, serialized as one JSON document.
class DemoDatabase {
  DemoDatabase({
    required this.seededAt,
    this.currentUserId,
    Map<String, Profile>? profiles,
    Map<String, Listing>? listings,
    List<SavedListing>? saved,
    Map<String, ConnectionRequest>? requests,
    Map<String, Conversation>? conversations,
    List<Message>? messages,
    List<ActivityEvent>? events,
  }) : profiles = profiles ?? {},
       listings = listings ?? {},
       saved = saved ?? [],
       requests = requests ?? {},
       conversations = conversations ?? {},
       messages = messages ?? [],
       events = events ?? [];

  static const schemaVersion = 1;

  factory DemoDatabase.seeded(DateTime now) {
    final s = SeedData.build(now);
    return DemoDatabase(
      seededAt: now.toUtc(),
      profiles: {for (final p in s.profiles) p.id: p},
      listings: {for (final l in s.listings) l.id: l},
      saved: [...s.saved],
      requests: {for (final r in s.requests) r.id: r},
      conversations: {for (final c in s.conversations) c.id: c},
      messages: [...s.messages],
      events: [...s.events],
    );
  }

  final DateTime seededAt;
  String? currentUserId;
  final Map<String, Profile> profiles;
  final Map<String, Listing> listings;
  final List<SavedListing> saved;
  final Map<String, ConnectionRequest> requests;
  final Map<String, Conversation> conversations;
  final List<Message> messages;
  final List<ActivityEvent> events;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'seededAt': writeDate(seededAt),
    'currentUserId': currentUserId,
    'profiles': [for (final p in profiles.values) p.toJson()],
    'listings': [for (final l in listings.values) l.toJson()],
    'saved': [for (final s in saved) s.toJson()],
    'requests': [for (final r in requests.values) r.toJson()],
    'conversations': [for (final c in conversations.values) c.toJson()],
    'messages': [for (final m in messages) m.toJson()],
    'events': [for (final e in events) e.toJson()],
  };

  /// Returns null when the stored document is from an incompatible version.
  static DemoDatabase? fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) return null;
    List<Map<String, Object?>> list(String key) => [
      for (final item in (json[key] as List? ?? const [])) asJsonMap(item),
    ];
    return DemoDatabase(
      seededAt: readDate(json['seededAt']),
      currentUserId: readOptionalString(json['currentUserId']),
      profiles: {
        for (final m in list('profiles'))
          m['id'] as String: Profile.fromJson(m),
      },
      listings: {
        for (final m in list('listings'))
          m['id'] as String: Listing.fromJson(m),
      },
      saved: [for (final m in list('saved')) SavedListing.fromJson(m)],
      requests: {
        for (final m in list('requests'))
          m['id'] as String: ConnectionRequest.fromJson(m),
      },
      conversations: {
        for (final m in list('conversations'))
          m['id'] as String: Conversation.fromJson(m),
      },
      messages: [for (final m in list('messages')) Message.fromJson(m)],
      events: [for (final m in list('events')) ?ActivityEvent.fromJson(m)],
    );
  }
}
