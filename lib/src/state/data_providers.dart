import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../domain/activity.dart';
import '../domain/connections.dart';
import '../domain/listing.dart';
import '../domain/profile.dart';
import '../domain/taxonomy.dart';
import '../matching/preference_model.dart';
import 'session.dart';

/// The active backend, or null when signed out.
final backendProvider = Provider<MarketplaceBackend?>(
  (ref) => ref.watch(sessionProvider).value?.backend,
);

/// The signed-in member's id, or null.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider).value?.userId,
);

/// Per-topic change counters. Queries watch their topic so any local or
/// remote change refreshes exactly the affected data.
class DataRevisions extends Notifier<Map<DataTopic, int>> {
  @override
  Map<DataTopic, int> build() {
    final backend = ref.watch(backendProvider);
    ref.watch(currentUserIdProvider);
    if (backend != null) {
      final sub = backend.changes.listen((topic) {
        if (!ref.mounted) return;
        state = {...state, topic: (state[topic] ?? 0) + 1};
      });
      ref.onDispose(sub.cancel);
    }
    return const {};
  }
}

final revisionsProvider = NotifierProvider<DataRevisions, Map<DataTopic, int>>(
  DataRevisions.new,
);

MarketplaceBackend? _watch(Ref ref, List<DataTopic> topics) {
  final backend = ref.watch(backendProvider);
  ref.watch(currentUserIdProvider);
  for (final t in topics) {
    ref.watch(revisionsProvider.select((m) => m[t] ?? 0));
  }
  return backend;
}

final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final b = _watch(ref, const [DataTopic.profile]);
  return b?.profiles.me();
});

final visibleListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final b = _watch(ref, const [DataTopic.listings]);
  return b == null ? const [] : b.listings.visible();
});

final myListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final b = _watch(ref, const [DataTopic.listings]);
  return b == null ? const [] : b.listings.mine();
});

final listingByIdProvider = FutureProvider.family<Listing?, String>((
  ref,
  id,
) async {
  final b = _watch(ref, const [DataTopic.listings]);
  return b?.listings.byId(id);
});

final savedListingsProvider = FutureProvider<List<SavedListing>>((ref) async {
  final b = _watch(ref, const [DataTopic.saved]);
  return b == null ? const [] : b.saved.mine();
});

final savedIdsProvider = Provider<Set<String>>((ref) {
  final saved = ref.watch(savedListingsProvider).value ?? const [];
  return {for (final s in saved) s.listingId};
});

final requestsProvider = FutureProvider<List<ConnectionRequest>>((ref) async {
  final b = _watch(ref, const [DataTopic.requests]);
  return b == null ? const [] : b.connections.requests();
});

/// Pending requests the member needs to answer.
final pendingIncomingCountProvider = Provider<int>((ref) {
  final me = ref.watch(currentUserIdProvider);
  final requests = ref.watch(requestsProvider).value ?? const [];
  return requests
      .where((r) => r.recipientId == me && r.status == RequestStatus.pending)
      .length;
});

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final b = _watch(ref, const [DataTopic.conversations]);
  return b == null ? const [] : b.connections.conversations();
});

final conversationProvider = FutureProvider.family<Conversation, String>((
  ref,
  id,
) async {
  final b = _watch(ref, const [DataTopic.conversations]);
  if (b == null) throw StateError('Signed out');
  return b.connections.conversation(id);
});

final messagesProvider = FutureProvider.family<List<Message>, String>((
  ref,
  conversationId,
) async {
  final b = _watch(ref, const [DataTopic.messages]);
  if (b == null) return const [];
  return b.connections.messages(conversationId);
});

final activityProvider = FutureProvider<List<ActivityEvent>>((ref) async {
  final b = _watch(ref, const [DataTopic.activity]);
  return b == null ? const [] : b.activity.mine();
});

final preferenceModelProvider = Provider<PreferenceModel>((ref) {
  final events = ref.watch(activityProvider).value;
  if (events == null || events.isEmpty) return PreferenceModel.empty;
  return PreferenceModel.fromEvents(events);
});

final directoryProvider = FutureProvider<List<MemberProfile>>((ref) async {
  final b = _watch(ref, const [DataTopic.members, DataTopic.profile]);
  return b == null ? const [] : b.profiles.directory();
});

/// Names (and public details where shared) for everyone the member can
/// currently see: listing owners, request counterparts and conversation
/// participants. Fetched in one batch.
final knownMembersProvider = FutureProvider<Map<String, MemberProfile>>((
  ref,
) async {
  final b = _watch(ref, const [DataTopic.members, DataTopic.profile]);
  if (b == null) return const {};
  final listings = await ref.watch(visibleListingsProvider.future);
  final requests = await ref.watch(requestsProvider.future);
  final conversations = await ref.watch(conversationsProvider.future);
  final ids = <String>{
    for (final l in listings) l.ownerId,
    for (final r in requests) ...[r.senderId, r.recipientId],
    for (final c in conversations) ...c.participantIds,
  };
  if (ids.isEmpty) return const {};
  return b.profiles.members(ids);
});

/// Convenience lookup that tolerates loading and missing members.
final memberProvider = Provider.family<MemberProfile?, String>((ref, id) {
  return ref.watch(knownMembersProvider).value?[id];
});

/// Records a feedback event without blocking the interface. Views are
/// recorded at most once per listing per app session.
class ActivityRecorder {
  ActivityRecorder(this.ref);
  final Ref ref;
  final _viewed = <String>{};

  void record(ActivityType type, Listing listing) {
    final backend = ref.read(backendProvider);
    if (backend == null) return;
    if (type == ActivityType.viewed &&
        !_viewed.add('${backend.currentUserId}:${listing.id}')) {
      return;
    }
    unawaited(backend.activity.record(type, listing).catchError((_) {}));
  }
}

final activityRecorderProvider = Provider<ActivityRecorder>(
  ActivityRecorder.new,
);
