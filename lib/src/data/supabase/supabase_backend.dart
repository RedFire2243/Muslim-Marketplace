import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/activity.dart';
import '../../domain/connections.dart';
import '../../domain/listing.dart';
import '../../domain/profile.dart';
import '../../domain/taxonomy.dart';
import '../../matching/extraction.dart';
import '../../matching/intent_parser.dart';
import '../errors.dart';
import '../repositories.dart';
import 'supabase_mappers.dart';

/// Connected mode: real accounts, shared data and private messaging through
/// Supabase. Every query runs as the signed-in member, so row-level security
/// and database functions decide what is allowed.
class SupabaseBackend implements MarketplaceBackend {
  SupabaseBackend(
    this.client, {
    required this.currentUserId,
    bool aiExtraction = false,
  }) : extractor = aiExtraction
           ? AiProfileExtractor(EdgeFunctionExtractionClient(client))
           : const RulesExtractor() {
    _subscribe();
  }

  final SupabaseClient client;

  @override
  final String currentUserId;

  @override
  final ProfileExtractor extractor;

  final _changes = StreamController<DataTopic>.broadcast();
  RealtimeChannel? _channel;

  @override
  AppMode get mode => AppMode.connected;

  @override
  Stream<DataTopic> get changes => _changes.stream;

  @override
  late final ProfileRepository profiles = _Profiles(this);
  @override
  late final ListingRepository listings = _Listings(this);
  @override
  late final SavedRepository saved = _Saved(this);
  @override
  late final ConnectionRepository connections = _Connections(this);
  @override
  late final ActivityRepository activity = _Activity(this);

  /// Connected mode never offers demo controls.
  @override
  DemoControls? get demo => null;

  void _emit(Iterable<DataTopic> topics) {
    if (_changes.isClosed) return;
    for (final t in topics) {
      _changes.add(t);
    }
  }

  void _subscribe() {
    void on(String table, List<DataTopic> topics) {
      _channel = (_channel ?? client.channel('marketplace-$currentUserId'))
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) => _emit(topics),
          );
    }

    on('messages', const [DataTopic.messages, DataTopic.conversations]);
    on('conversations', const [DataTopic.conversations]);
    on('connection_requests', const [DataTopic.requests, DataTopic.members]);
    on('listings', const [DataTopic.listings]);
    _channel?.subscribe();
  }

  @override
  Future<void> dispose() async {
    final ch = _channel;
    if (ch != null) await client.removeChannel(ch);
    await _changes.close();
  }

  /// Runs a backend call and translates failures into [MarketplaceException]s.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body().timeout(const Duration(seconds: 20));
    } on MarketplaceException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    } on AuthException catch (e) {
      throw AccountException(e.message);
    } on TimeoutException {
      throw const NetworkException();
    } catch (e) {
      final text = e.toString();
      if (text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('Failed host lookup') ||
          text.contains('XMLHttpRequest')) {
        throw const NetworkException();
      }
      rethrow;
    }
  }
}

/// Maps database errors. Functions in the migration attach a `hint` naming
/// the error kind; constraint and RLS failures map by SQLSTATE.
MarketplaceException mapPostgrestError(PostgrestException e) {
  switch (e.hint) {
    case 'not_allowed':
      return NotAllowedException(e.message);
    case 'not_found':
      return NotFoundException(e.message);
    case 'conflict':
      return ConflictException(e.message);
    case 'invalid_transition':
      return InvalidTransitionException(e.message);
    case 'validation':
      return ValidationException(const {}, e.message);
  }
  return switch (e.code) {
    '42501' => const NotAllowedException(),
    'PGRST116' => const NotFoundException(),
    '23505' => const ConflictException('That already exists.'),
    '23514' || '22001' || '23502' => const ValidationException({}),
    _ => const NetworkException(
      'The server couldn’t complete that. Please try again.',
    ),
  };
}

class _Profiles implements ProfileRepository {
  _Profiles(this.b);
  final SupabaseBackend b;
  SupabaseClient get db => b.client;

  @override
  Future<Profile> me() => b._guard(() async {
    final row = await db
        .from('profiles')
        .select()
        .eq('id', b.currentUserId)
        .single();
    final settings = await db
        .from('profile_settings')
        .select()
        .eq('id', b.currentUserId)
        .maybeSingle();
    return Rows.profile(row, settings);
  });

  @override
  Future<Profile> saveMine(
    ProfileDraft draft, {
    bool completeOnboarding = false,
  }) => b._guard(() async {
    final errors = draft.validate();
    if (errors.isNotEmpty) throw ValidationException(errors);
    await db
        .from('profiles')
        .update(Rows.profileUpdate(draft))
        .eq('id', b.currentUserId);
    await db
        .from('profile_settings')
        .update({
          'goals': [for (final g in draft.goals) g.toJson()],
          if (completeOnboarding) 'onboarding_complete': true,
        })
        .eq('id', b.currentUserId);
    b._emit(const [DataTopic.profile, DataTopic.members]);
    return me();
  });

  @override
  Future<Profile> updateSettings({
    bool? directoryVisible,
    bool? personalizationEnabled,
  }) => b._guard(() async {
    if (directoryVisible != null) {
      await db
          .from('profiles')
          .update({'directory_visible': directoryVisible})
          .eq('id', b.currentUserId);
    }
    if (personalizationEnabled != null) {
      await db
          .from('profile_settings')
          .update({'personalization_enabled': personalizationEnabled})
          .eq('id', b.currentUserId);
    }
    b._emit(const [DataTopic.profile, DataTopic.members]);
    return me();
  });

  @override
  Future<List<MemberProfile>> directory() => b._guard(() async {
    final rows = await db
        .from('profiles')
        .select()
        .eq('directory_visible', true)
        .neq('id', b.currentUserId)
        .neq('display_name', '');
    return [for (final r in rows) Rows.member(r)];
  });

  @override
  Future<Map<String, MemberProfile>> members(Set<String> ids) => b._guard(
    () async {
      if (ids.isEmpty) return const {};
      final rows = await db.rpc<List<dynamic>>(
        'get_member_cards',
        params: {'p_ids': ids.toList()},
      );
      return {
        for (final r in rows)
          (r as Map)['id'] as String: Rows.member(Map<String, dynamic>.from(r)),
      };
    },
  );
}

class _Listings implements ListingRepository {
  _Listings(this.b);
  final SupabaseBackend b;
  SupabaseClient get db => b.client;

  @override
  Future<List<Listing>> visible() => b._guard(() async {
    final rows = await db
        .from('listings')
        .select()
        .order('created_at', ascending: false);
    return [for (final r in rows) Rows.listing(r)];
  });

  @override
  Future<List<Listing>> mine() => b._guard(() async {
    final rows = await db
        .from('listings')
        .select()
        .eq('owner_id', b.currentUserId)
        .order('created_at', ascending: false);
    return [for (final r in rows) Rows.listing(r)];
  });

  @override
  Future<Listing?> byId(String id) => b._guard(() async {
    final row = await db.from('listings').select().eq('id', id).maybeSingle();
    return row == null ? null : Rows.listing(row);
  });

  @override
  Future<Listing> create(ListingDraft draft) => b._guard(() async {
    final errors = draft.validate();
    if (errors.isNotEmpty) throw ValidationException(errors);
    // A repeated submission within a minute returns the original.
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(seconds: 60))
        .toIso8601String();
    final recent = await db
        .from('listings')
        .select()
        .eq('owner_id', b.currentUserId)
        .eq('title', draft.title.trim())
        .gte('created_at', since)
        .limit(1);
    if (recent.isNotEmpty) return Rows.listing(recent.first);
    final row = await db
        .from('listings')
        .insert(Rows.listingWrite(draft))
        .select()
        .single();
    b._emit(const [DataTopic.listings, DataTopic.members]);
    return Rows.listing(row);
  });

  @override
  Future<Listing> update(String id, ListingDraft draft) => b._guard(() async {
    final errors = draft.validate();
    if (errors.isNotEmpty) throw ValidationException(errors);
    final rows = await db
        .from('listings')
        .update(Rows.listingWrite(draft))
        .eq('id', id)
        .select();
    if (rows.isEmpty) {
      throw const NotAllowedException(
        'Only the owner can change this listing.',
      );
    }
    b._emit(const [DataTopic.listings]);
    return Rows.listing(rows.first);
  });

  @override
  Future<Listing> setStatus(String id, ListingStatus status) =>
      b._guard(() async {
        final rows = await db
            .from('listings')
            .update({'status': status.wire})
            .eq('id', id)
            .select();
        if (rows.isEmpty) {
          throw const NotAllowedException(
            'Only the owner can change this listing.',
          );
        }
        b._emit(const [DataTopic.listings, DataTopic.members]);
        return Rows.listing(rows.first);
      });

  @override
  Future<void> delete(String id) => b._guard(() async {
    final rows = await db.from('listings').delete().eq('id', id).select('id');
    if (rows.isEmpty) {
      throw const NotAllowedException(
        'Only the owner can delete this listing.',
      );
    }
    b._emit(const [DataTopic.listings, DataTopic.saved, DataTopic.requests]);
  });
}

class _Saved implements SavedRepository {
  _Saved(this.b);
  final SupabaseBackend b;
  SupabaseClient get db => b.client;

  @override
  Future<List<SavedListing>> mine() => b._guard(() async {
    final rows = await db
        .from('saved_listings')
        .select()
        .eq('user_id', b.currentUserId)
        .order('saved_at', ascending: false);
    return [for (final r in rows) Rows.saved(r)];
  });

  @override
  Future<void> save(String listingId) => b._guard(() async {
    await db
        .from('saved_listings')
        .upsert(
          {'user_id': b.currentUserId, 'listing_id': listingId},
          onConflict: 'user_id,listing_id',
          ignoreDuplicates: true,
        );
    b._emit(const [DataTopic.saved]);
  });

  @override
  Future<void> unsave(String listingId) => b._guard(() async {
    await db
        .from('saved_listings')
        .delete()
        .eq('user_id', b.currentUserId)
        .eq('listing_id', listingId);
    b._emit(const [DataTopic.saved]);
  });
}

class _Connections implements ConnectionRepository {
  _Connections(this.b);
  final SupabaseBackend b;
  SupabaseClient get db => b.client;

  @override
  Future<List<ConnectionRequest>> requests() => b._guard(() async {
    final rows = await db
        .from('connection_requests')
        .select('*, conversations(id)')
        .order('created_at', ascending: false);
    return [for (final r in rows) Rows.request(r)];
  });

  @override
  Future<ConnectionRequest> send({
    required String recipientId,
    String? listingId,
    required String message,
  }) => b._guard(() async {
    final text = message.trim();
    if (text.isEmpty) {
      throw const ValidationException({'message': 'Add a short message.'});
    }
    final row = await db.rpc<Map<String, dynamic>>(
      'send_connection_request',
      params: {
        'p_recipient_id': recipientId,
        'p_listing_id': listingId,
        'p_message': text,
      },
    );
    b._emit(const [DataTopic.requests, DataTopic.members]);
    return Rows.request(row);
  });

  @override
  Future<ConnectionRequest> respond(String requestId, {required bool accept}) =>
      b._guard(() async {
        final result = await db.rpc<Map<String, dynamic>>(
          'respond_to_connection_request',
          params: {'p_request_id': requestId, 'p_accept': accept},
        );
        b._emit(const [DataTopic.requests, DataTopic.conversations]);
        return Rows.request(
          Map<String, dynamic>.from(result['request'] as Map),
          conversationId: result['conversation_id'] as String?,
        );
      });

  @override
  Future<ConnectionRequest> withdraw(String requestId) => b._guard(() async {
    final row = await db.rpc<Map<String, dynamic>>(
      'withdraw_connection_request',
      params: {'p_request_id': requestId},
    );
    b._emit(const [DataTopic.requests]);
    return Rows.request(row);
  });

  @override
  Future<List<Conversation>> conversations() => b._guard(() async {
    final rows = await db.from('conversations').select();
    final list = [for (final r in rows) Rows.conversation(r)]
      ..sort((x, y) => y.sortTime.compareTo(x.sortTime));
    return list;
  });

  @override
  Future<Conversation> conversation(String id) => b._guard(() async {
    final row = await db
        .from('conversations')
        .select()
        .eq('id', id)
        .maybeSingle();
    // Row-level security hides conversations from non-participants, so a
    // missing row means "not yours" as far as the member is concerned.
    if (row == null) {
      throw const NotAllowedException(
        'This conversation is private to its participants.',
      );
    }
    return Rows.conversation(row);
  });

  @override
  Future<List<Message>> messages(String conversationId) => b._guard(() async {
    await conversation(conversationId);
    final rows = await db
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return [for (final r in rows) Rows.message(r)];
  });

  @override
  Future<Message> sendMessage(
    String conversationId,
    String body, {
    required String clientId,
  }) => b._guard(() async {
    final text = body.trim();
    if (text.isEmpty) {
      throw const ValidationException({'body': 'Write a message first.'});
    }
    try {
      final row = await db
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'body': text,
            'client_id': clientId,
          })
          .select()
          .single();
      b._emit(const [DataTopic.messages, DataTopic.conversations]);
      return Rows.message(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Already delivered by an earlier attempt.
        final existing = await db
            .from('messages')
            .select()
            .eq('sender_id', b.currentUserId)
            .eq('client_id', clientId)
            .single();
        return Rows.message(existing);
      }
      if (e.code == '42501') {
        throw const NotAllowedException(
          'Only participants can send messages here.',
        );
      }
      rethrow;
    }
  });
}

class _Activity implements ActivityRepository {
  _Activity(this.b);
  final SupabaseBackend b;
  SupabaseClient get db => b.client;

  @override
  Future<List<ActivityEvent>> mine() => b._guard(() async {
    final rows = await db
        .from('recommendation_events')
        .select()
        .eq('user_id', b.currentUserId);
    return [for (final r in rows) ?Rows.event(r)];
  });

  @override
  Future<void> record(ActivityType type, Listing listing) => b._guard(() async {
    try {
      await db.from('recommendation_events').insert({
        'listing_id': listing.id,
        'event_type': type.wire,
        'listing_type': listing.type.wire,
        'category': listing.category.wire,
        'tags': listing.tags,
      });
      b._emit(const [DataTopic.activity]);
    } on PostgrestException catch (e) {
      // Recording is refused while personalization is off.
      if (e.code != '42501') rethrow;
    }
  });

  @override
  Future<void> reset() => b._guard(() async {
    await db
        .from('recommendation_events')
        .delete()
        .eq('user_id', b.currentUserId);
    b._emit(const [DataTopic.activity]);
  });
}

/// Calls the `extract-profile` Edge Function. The AI provider key stays in
/// the function's server-side environment.
class EdgeFunctionExtractionClient implements RemoteExtractionClient {
  EdgeFunctionExtractionClient(this.client);
  final SupabaseClient client;

  @override
  Future<Object?> requestExtraction(OnboardingAnswers answers) async {
    final res = await client.functions.invoke(
      'extract-profile',
      body: answers.toJson(),
    );
    return res.data;
  }
}
