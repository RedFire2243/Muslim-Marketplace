import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/activity.dart';
import '../../domain/connections.dart';
import '../../domain/json.dart';
import '../../domain/listing.dart';
import '../../domain/profile.dart';
import '../../domain/taxonomy.dart';
import '../../matching/extraction.dart';
import '../errors.dart';
import '../key_value_store.dart';
import '../repositories.dart';
import 'demo_database.dart';

/// A complete local backend for the demonstration.
///
/// Data lives on this device only and survives restarts and refreshes. The
/// same ownership, request and conversation rules that the connected
/// backend enforces in the database are enforced here in code.
class DemoBackend implements MarketplaceBackend, DemoControls {
  DemoBackend._(this._store, this._db, this._clock, this._latency);

  static const storageKey = 'mm.demo.database.v1';

  /// Loads the saved demo, or seeds a fresh one.
  static Future<DemoBackend> open(
    KeyValueStore store, {
    DateTime Function()? clock,
    Duration latency = const Duration(milliseconds: 120),
  }) async {
    final now = clock ?? DateTime.now;
    DemoDatabase? db;
    final raw = store.getString(storageKey);
    if (raw != null) {
      try {
        db = DemoDatabase.fromJson(asJsonMap(jsonDecode(raw)));
      } catch (_) {
        db = null; // Corrupt or incompatible: start over with sample data.
      }
    }
    final backend = DemoBackend._(
      store,
      db ?? DemoDatabase.seeded(now()),
      now,
      latency,
    );
    if (db == null) await backend._persist();
    return backend;
  }

  final KeyValueStore _store;
  DemoDatabase _db;
  final DateTime Function() _clock;
  final Duration _latency;
  final _changes = StreamController<DataTopic>.broadcast();
  final _uuid = const Uuid();

  /// Test hook: the next N message sends fail as if the network dropped.
  @visibleForTesting
  int failNextMessageSends = 0;

  @visibleForTesting
  DemoDatabase get database => _db;

  @override
  AppMode get mode => AppMode.demo;

  /// The member currently being demonstrated, if any.
  String? get activeUserId => _db.currentUserId;

  @override
  String get currentUserId {
    final id = _db.currentUserId;
    if (id == null) throw StateError('No demo member selected');
    return id;
  }

  @override
  Stream<DataTopic> get changes => _changes.stream;

  @override
  late final ProfileRepository profiles = _DemoProfiles(this);
  @override
  late final ListingRepository listings = _DemoListings(this);
  @override
  late final SavedRepository saved = _DemoSaved(this);
  @override
  late final ConnectionRepository connections = _DemoConnections(this);
  @override
  late final ActivityRepository activity = _DemoActivity(this);

  /// Demo mode never calls an AI service.
  @override
  final ProfileExtractor extractor = const RulesExtractor();

  @override
  DemoControls get demo => this;

  @override
  Future<void> dispose() async => _changes.close();

  // ------------------------------------------------------------------
  // Demo controls

  @override
  Future<List<Profile>> members() async {
    final list = _db.profiles.values.toList()
      ..sort((a, b) {
        if (a.isSample != b.isSample) return a.isSample ? 1 : -1;
        return a.displayName.compareTo(b.displayName);
      });
    return list;
  }

  @override
  Future<void> switchTo(String userId) async {
    if (!_db.profiles.containsKey(userId)) throw const NotFoundException();
    _db.currentUserId = userId;
    await _persist();
    _emitAll();
  }

  @override
  Future<String> createMember() async {
    final now = _now();
    final id = _uuid.v4();
    _db.profiles[id] = Profile(
      id: id,
      displayName: '',
      createdAt: now,
      updatedAt: now,
    );
    _db.currentUserId = id;
    await _persist();
    _emitAll();
    return id;
  }

  /// Leaves the demo without changing its data.
  Future<void> signOut() async {
    _db.currentUserId = null;
    await _persist();
  }

  @override
  Future<void> reset() async {
    _db = DemoDatabase.seeded(_now());
    await _persist();
    _emitAll();
  }

  // ------------------------------------------------------------------
  // Internals

  DateTime _now() => _clock().toUtc();

  Future<void> _delay() async {
    if (_latency > Duration.zero) await Future<void>.delayed(_latency);
  }

  Future<void> _persist() =>
      _store.setString(storageKey, jsonEncode(_db.toJson()));

  void _emit(Iterable<DataTopic> topics) {
    if (_changes.isClosed) return;
    for (final t in topics) {
      _changes.add(t);
    }
  }

  void _emitAll() => _emit(DataTopic.values);

  Profile get _me {
    final p = _db.profiles[currentUserId];
    if (p == null) throw const NotFoundException();
    return p;
  }

  bool _canSeeListing(Listing l, String viewer) =>
      l.isActive ||
      l.ownerId == viewer ||
      _db.requests.values.any((r) => r.listingId == l.id && r.involves(viewer));

  /// Mirrors the `get_member_cards` database function: names are visible
  /// for directory members, owners of active listings, and anyone who shares
  /// a request with the viewer.
  bool _canSeeName(String memberId, String viewer) {
    if (memberId == viewer) return true;
    final p = _db.profiles[memberId];
    if (p == null) return false;
    if (p.directoryVisible) return true;
    if (_db.listings.values.any((l) => l.ownerId == memberId && l.isActive)) {
      return true;
    }
    return _db.requests.values.any(
      (r) =>
          (r.senderId == viewer && r.recipientId == memberId) ||
          (r.recipientId == viewer && r.senderId == memberId),
    );
  }

  Listing _ownedListing(String id) {
    final l = _db.listings[id];
    if (l == null) throw const NotFoundException();
    if (l.ownerId != currentUserId) {
      throw const NotAllowedException(
        'Only the owner can change this listing.',
      );
    }
    return l;
  }

  Conversation _participantConversation(String id) {
    final c = _db.conversations[id];
    if (c == null) throw const NotFoundException();
    if (!c.hasParticipant(currentUserId)) {
      throw const NotAllowedException(
        'This conversation is private to its participants.',
      );
    }
    return c;
  }
}

class _DemoProfiles implements ProfileRepository {
  _DemoProfiles(this.b);
  final DemoBackend b;

  @override
  Future<Profile> me() async => b._me;

  @override
  Future<Profile> saveMine(
    ProfileDraft draft, {
    bool completeOnboarding = false,
  }) async {
    await b._delay();
    final errors = draft.validate();
    if (errors.isNotEmpty) throw ValidationException(errors);
    final current = b._me;
    final updated = current.copyWith(
      displayName: draft.displayName.trim(),
      headline: draft.headline.trim(),
      skills: draft.skills,
      interests: draft.interests,
      offeringSummary: draft.offeringSummary.trim(),
      seekingSummary: draft.seekingSummary.trim(),
      goals: draft.goals,
      areaId: () => draft.areaId,
      openToRemote: draft.openToRemote,
      communityAffiliation: () =>
          readOptionalString(draft.communityAffiliation),
      linkedinUrl: () => readOptionalString(draft.linkedinUrl),
      directoryVisible: draft.directoryVisible,
      onboardingComplete: completeOnboarding ? true : null,
      updatedAt: b._now(),
    );
    b._db.profiles[updated.id] = updated;
    await b._persist();
    b._emit(const [DataTopic.profile, DataTopic.members]);
    return updated;
  }

  @override
  Future<Profile> updateSettings({
    bool? directoryVisible,
    bool? personalizationEnabled,
  }) async {
    await b._delay();
    final updated = b._me.copyWith(
      directoryVisible: directoryVisible,
      personalizationEnabled: personalizationEnabled,
      updatedAt: b._now(),
    );
    b._db.profiles[updated.id] = updated;
    await b._persist();
    b._emit(const [DataTopic.profile, DataTopic.members]);
    return updated;
  }

  @override
  Future<List<MemberProfile>> directory() async {
    final me = b.currentUserId;
    return [
      for (final p in b._db.profiles.values)
        if (p.directoryVisible && p.id != me && p.onboardingComplete)
          p.toMember(),
    ];
  }

  @override
  Future<Map<String, MemberProfile>> members(Set<String> ids) async {
    final me = b.currentUserId;
    return {
      for (final id in ids)
        if (b._canSeeName(id, me)) id: b._db.profiles[id]!.toMember(),
    };
  }
}

class _DemoListings implements ListingRepository {
  _DemoListings(this.b);
  final DemoBackend b;

  @override
  Future<List<Listing>> visible() async {
    final me = b.currentUserId;
    return b._db.listings.values.where((l) => b._canSeeListing(l, me)).toList();
  }

  @override
  Future<List<Listing>> mine() async {
    final me = b.currentUserId;
    return b._db.listings.values.where((l) => l.ownerId == me).toList()
      ..sort((a, c) => c.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Listing?> byId(String id) async {
    final l = b._db.listings[id];
    if (l == null || !b._canSeeListing(l, b.currentUserId)) return null;
    return l;
  }

  @override
  Future<Listing> create(ListingDraft draft) async {
    await b._delay();
    final errors = draft.validate();
    if (errors.isNotEmpty) throw ValidationException(errors);
    final me = b.currentUserId;
    final now = b._now();
    // A repeated submission of the same listing within a minute returns the
    // original instead of creating a duplicate.
    for (final existing in b._db.listings.values) {
      if (existing.ownerId == me &&
          existing.title == draft.title.trim() &&
          now.difference(existing.createdAt).inSeconds.abs() < 60) {
        return existing;
      }
    }
    final listing = Listing(
      id: b._uuid.v4(),
      ownerId: me,
      title: draft.title.trim(),
      description: draft.description.trim(),
      type: draft.type!,
      direction: draft.effectiveDirection!,
      category: draft.category!,
      tags: draft.normalizedTags,
      areaId: draft.areaId,
      remoteAvailable: draft.remoteAvailable,
      compensationType: draft.compensationType,
      compensationDetails: readOptionalString(draft.compensationDetails),
      createdAt: now,
      updatedAt: now,
    );
    b._db.listings[listing.id] = listing;
    await b._persist();
    b._emit(const [DataTopic.listings, DataTopic.members]);
    return listing;
  }

  @override
  Future<Listing> update(String id, ListingDraft draft) async {
    await b._delay();
    final current = b._ownedListing(id);
    if (current.status == ListingStatus.closed) {
      throw const InvalidTransitionException(
        'Closed listings can no longer be edited.',
      );
    }
    final errors = draft.validate();
    if (errors.isNotEmpty) throw ValidationException(errors);
    final updated = current.applyDraft(draft, b._now());
    b._db.listings[id] = updated;
    await b._persist();
    b._emit(const [DataTopic.listings]);
    return updated;
  }

  @override
  Future<Listing> setStatus(String id, ListingStatus status) async {
    await b._delay();
    final current = b._ownedListing(id);
    if (!current.status.canTransitionTo(status)) {
      throw InvalidTransitionException(
        'A ${current.status.label.toLowerCase()} listing can\'t be ${status == ListingStatus.active ? 'reopened' : 'changed to ${status.label.toLowerCase()}'}.',
      );
    }
    final now = b._now();
    final updated = current.copyWith(
      status: status,
      updatedAt: now,
      closedAt: status == ListingStatus.closed ? () => now : null,
    );
    b._db.listings[id] = updated;
    await b._persist();
    b._emit(const [DataTopic.listings, DataTopic.members]);
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    await b._delay();
    b._ownedListing(id);
    b._db.listings.remove(id);
    b._db.saved.removeWhere((s) => s.listingId == id);
    for (final r in b._db.requests.values.toList()) {
      if (r.listingId == id) {
        b._db.requests[r.id] = ConnectionRequest(
          id: r.id,
          senderId: r.senderId,
          recipientId: r.recipientId,
          listingTitle: r.listingTitle,
          message: r.message,
          status: r.status,
          createdAt: r.createdAt,
          respondedAt: r.respondedAt,
          conversationId: r.conversationId,
        );
      }
    }
    await b._persist();
    b._emit(const [DataTopic.listings, DataTopic.saved, DataTopic.requests]);
  }
}

class _DemoSaved implements SavedRepository {
  _DemoSaved(this.b);
  final DemoBackend b;

  @override
  Future<List<SavedListing>> mine() async {
    final me = b.currentUserId;
    return b._db.saved.where((s) => s.userId == me).toList()
      ..sort((a, c) => c.savedAt.compareTo(a.savedAt));
  }

  @override
  Future<void> save(String listingId) async {
    await b._delay();
    final me = b.currentUserId;
    final l = b._db.listings[listingId];
    if (l == null || !b._canSeeListing(l, me)) throw const NotFoundException();
    if (b._db.saved.any((s) => s.userId == me && s.listingId == listingId)) {
      return;
    }
    b._db.saved.add(
      SavedListing(userId: me, listingId: listingId, savedAt: b._now()),
    );
    await b._persist();
    b._emit(const [DataTopic.saved]);
  }

  @override
  Future<void> unsave(String listingId) async {
    await b._delay();
    final me = b.currentUserId;
    b._db.saved.removeWhere((s) => s.userId == me && s.listingId == listingId);
    await b._persist();
    b._emit(const [DataTopic.saved]);
  }
}

class _DemoConnections implements ConnectionRepository {
  _DemoConnections(this.b);
  final DemoBackend b;

  @override
  Future<List<ConnectionRequest>> requests() async {
    final me = b.currentUserId;
    return b._db.requests.values.where((r) => r.involves(me)).toList()
      ..sort((a, c) => c.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ConnectionRequest> send({
    required String recipientId,
    String? listingId,
    required String message,
  }) async {
    await b._delay();
    final me = b.currentUserId;
    final text = message.trim();
    if (text.isEmpty) {
      throw const ValidationException({'message': 'Add a short message.'});
    }
    if (text.length > 1000) {
      throw const ValidationException({
        'message': 'Keep your message under 1,000 characters.',
      });
    }
    if (recipientId == me) {
      throw const NotAllowedException('You can’t send a request to yourself.');
    }
    final recipient = b._db.profiles[recipientId];
    if (recipient == null) throw const NotFoundException();
    Listing? listing;
    if (listingId != null) {
      listing = b._db.listings[listingId];
      if (listing == null) throw const NotFoundException();
      if (!listing.isActive) {
        throw const InvalidTransitionException(
          'This listing is no longer accepting requests.',
        );
      }
      if (listing.ownerId != recipientId) {
        throw const NotAllowedException(
          'Requests about a listing go to its owner.',
        );
      }
    } else if (!recipient.directoryVisible) {
      throw const NotAllowedException(
        'This member is not accepting introductions.',
      );
    }
    final duplicate = b._db.requests.values.any(
      (r) =>
          r.senderId == me &&
          r.recipientId == recipientId &&
          r.listingId == listingId &&
          r.status.isOpen,
    );
    if (duplicate) {
      throw const ConflictException(
        'You already have an open request for this.',
      );
    }
    final request = ConnectionRequest(
      id: b._uuid.v4(),
      senderId: me,
      recipientId: recipientId,
      listingId: listingId,
      listingTitle: listing?.title,
      message: text,
      createdAt: b._now(),
    );
    b._db.requests[request.id] = request;
    await b._persist();
    b._emit(const [DataTopic.requests, DataTopic.members]);
    return request;
  }

  @override
  Future<ConnectionRequest> respond(
    String requestId, {
    required bool accept,
  }) async {
    await b._delay();
    final me = b.currentUserId;
    final r = b._db.requests[requestId];
    if (r == null || !r.involves(me)) throw const NotFoundException();
    final target = accept ? RequestStatus.accepted : RequestStatus.declined;
    final actor = r.recipientId == me
        ? RequestActor.recipient
        : RequestActor.sender;
    if (actor != RequestActor.recipient) {
      throw const NotAllowedException(
        'Only the person who received this request can respond.',
      );
    }
    if (!canTransitionRequest(r.status, target, actor)) {
      throw const InvalidTransitionException(
        'This request has already been answered.',
      );
    }
    final now = b._now();
    String? conversationId;
    if (accept) {
      final c = Conversation(
        id: b._uuid.v4(),
        requestId: r.id,
        participantIds: [r.senderId, r.recipientId],
        listingId: r.listingId,
        listingTitle: r.listingTitle,
        createdAt: now,
      );
      b._db.conversations[c.id] = c;
      conversationId = c.id;
    }
    final updated = r.copyWith(
      status: target,
      respondedAt: now,
      conversationId: conversationId,
    );
    b._db.requests[r.id] = updated;
    await b._persist();
    b._emit(const [DataTopic.requests, DataTopic.conversations]);
    return updated;
  }

  @override
  Future<ConnectionRequest> withdraw(String requestId) async {
    await b._delay();
    final me = b.currentUserId;
    final r = b._db.requests[requestId];
    if (r == null || !r.involves(me)) throw const NotFoundException();
    final actor = r.senderId == me
        ? RequestActor.sender
        : RequestActor.recipient;
    if (!canTransitionRequest(r.status, RequestStatus.withdrawn, actor)) {
      throw const InvalidTransitionException(
        'Only pending requests you sent can be withdrawn.',
      );
    }
    final updated = r.copyWith(
      status: RequestStatus.withdrawn,
      respondedAt: b._now(),
    );
    b._db.requests[r.id] = updated;
    await b._persist();
    b._emit(const [DataTopic.requests]);
    return updated;
  }

  @override
  Future<List<Conversation>> conversations() async {
    final me = b.currentUserId;
    return b._db.conversations.values
        .where((c) => c.hasParticipant(me))
        .toList()
      ..sort((a, c) => c.sortTime.compareTo(a.sortTime));
  }

  @override
  Future<Conversation> conversation(String id) async =>
      b._participantConversation(id);

  @override
  Future<List<Message>> messages(String conversationId) async {
    b._participantConversation(conversationId);
    return b._db.messages
        .where((m) => m.conversationId == conversationId)
        .toList()
      ..sort((a, c) => a.createdAt.compareTo(c.createdAt));
  }

  @override
  Future<Message> sendMessage(
    String conversationId,
    String body, {
    required String clientId,
  }) async {
    await b._delay();
    final c = b._participantConversation(conversationId);
    final me = b.currentUserId;
    if (b.failNextMessageSends > 0) {
      b.failNextMessageSends--;
      throw const NetworkException();
    }
    final text = body.trim();
    if (text.isEmpty) {
      throw const ValidationException({'body': 'Write a message first.'});
    }
    if (text.length > Message.maxLength) {
      throw const ValidationException({
        'body': 'Messages can be up to 2,000 characters.',
      });
    }
    for (final m in b._db.messages) {
      if (m.senderId == me && m.clientId == clientId) return m; // Retry.
    }
    final message = Message(
      id: b._uuid.v4(),
      conversationId: conversationId,
      senderId: me,
      body: text,
      createdAt: b._now(),
      clientId: clientId,
    );
    b._db.messages.add(message);
    b._db.conversations[c.id] = c.withLastMessage(message);
    await b._persist();
    b._emit(const [DataTopic.messages, DataTopic.conversations]);
    return message;
  }
}

class _DemoActivity implements ActivityRepository {
  _DemoActivity(this.b);
  final DemoBackend b;

  @override
  Future<List<ActivityEvent>> mine() async {
    final me = b.currentUserId;
    return b._db.events.where((e) => e.userId == me).toList();
  }

  @override
  Future<void> record(ActivityType type, Listing listing) async {
    final me = b._me;
    if (!me.personalizationEnabled) return;
    b._db.events.add(
      ActivityEvent(
        id: b._uuid.v4(),
        userId: me.id,
        listingId: listing.id,
        type: type,
        listingType: listing.type,
        category: listing.category,
        tags: listing.tags,
        createdAt: b._now(),
      ),
    );
    await b._persist();
    b._emit(const [DataTopic.activity]);
  }

  @override
  Future<void> reset() async {
    await b._delay();
    final me = b.currentUserId;
    b._db.events.removeWhere((e) => e.userId == me);
    await b._persist();
    b._emit(const [DataTopic.activity]);
  }
}
