// Connected mode against a real Supabase backend (local or hosted).
//
//   supabase start && supabase db reset
//   flutter test test/connected --dart-define-from-file=config/local.json
//
// Skipped when no backend is configured. Uses three separate clients, so
// every check goes through real authentication, row-level security and the
// database functions.
@Tags(['connected'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/config/app_config.dart';
import 'package:muslim_marketplace/src/data/errors.dart';
import 'package:muslim_marketplace/src/data/repositories.dart';
import 'package:muslim_marketplace/src/data/seed/seed_data.dart';
import 'package:muslim_marketplace/src/data/supabase/supabase_backend.dart';
import 'package:muslim_marketplace/src/domain/activity.dart';
import 'package:muslim_marketplace/src/domain/goal.dart';
import 'package:muslim_marketplace/src/domain/listing.dart';
import 'package:muslim_marketplace/src/domain/profile.dart';
import 'package:muslim_marketplace/src/domain/taxonomy.dart';
import 'package:muslim_marketplace/src/matching/extraction.dart';
import 'package:muslim_marketplace/src/matching/intent_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final config = AppConfig.fromEnvironment();
final runId = DateTime.now().millisecondsSinceEpoch;

class Member {
  Member(this.client, this.backend);
  final SupabaseClient client;
  final SupabaseBackend backend;
  String get id => backend.currentUserId;
}

Future<Member> signUp(String name) async {
  final client = SupabaseClient(
    config.supabaseUrl,
    config.supabaseKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  final email = '${name.toLowerCase()}.$runId@example.test';
  final res = await client.auth.signUp(
    email: email,
    password: 'test-password-$runId',
    data: {'display_name': name},
  );
  expect(
    res.session,
    isNotNull,
    reason: 'Local Supabase should not require email confirmation',
  );
  final backend = SupabaseBackend(client, currentUserId: res.user!.id);
  await backend.profiles.saveMine(
    ProfileDraft(
      displayName: '$name Test',
      goals: const [Goal(type: ListingType.mentorship, role: GoalRole.seeking)],
      areaId: 'edison',
    ),
    completeOnboarding: true,
  );
  return Member(client, backend);
}

const draft = ListingDraft(
  title: 'Weekend robotics mentoring (test)',
  description:
      'Two hours on Saturdays helping students build competition robots.',
  type: ListingType.mentorship,
  direction: ListingDirection.offer,
  category: ListingCategory.engineering,
  tags: ['robotics'],
  areaId: 'edison',
  remoteAvailable: true,
);

void main() {
  final skip = config.hasBackend
      ? null
      : 'No backend configured (pass --dart-define-from-file=config/local.json)';

  late Member owner;
  late Member requester;
  late Member outsider;
  late Listing listing;
  late String conversationId;

  setUpAll(() async {
    if (skip != null) return;
    owner = await signUp('Owner');
    requester = await signUp('Requester');
    outsider = await signUp('Outsider');
  });

  tearDownAll(() async {
    if (skip != null) return;
    for (final m in [owner, requester, outsider]) {
      await m.backend.dispose();
      await m.client.dispose();
    }
  });

  test('new accounts get a private profile outside the directory', () async {
    final me = await outsider.backend.profiles.me();
    expect(me.onboardingComplete, isTrue);
    expect(me.directoryVisible, isFalse);
    expect(me.goals.single.type, ListingType.mentorship);
    expect(
      owner.backend.demo,
      isNull,
      reason: 'Connected mode has no demo controls',
    );
  }, skip: skip);

  test(
    'owners create listings; others see them but cannot change them',
    () async {
      listing = await owner.backend.listings.create(draft);
      expect(listing.ownerId, owner.id);
      expect(listing.isSample, isFalse);
      // Duplicate submission returns the same listing.
      expect((await owner.backend.listings.create(draft)).id, listing.id);

      final seen = await requester.backend.listings.byId(listing.id);
      expect(seen?.title, draft.title);
      await expectLater(
        requester.backend.listings.update(listing.id, draft),
        throwsA(isA<NotAllowedException>()),
      );
      await expectLater(
        requester.backend.listings.setStatus(listing.id, ListingStatus.closed),
        throwsA(isA<NotAllowedException>()),
      );
      await expectLater(
        requester.backend.listings.delete(listing.id),
        throwsA(isA<NotAllowedException>()),
      );
      // Spoofing another owner on insert is impossible: the database sets it.
      final spoof = await requester.client
          .from('listings')
          .insert({
            ...{'owner_id': owner.id},
            'title': 'Spoofed listing title',
            'description':
                'This should belong to the requester, not the owner.',
            'listing_type': 'service',
            'direction': 'offer',
            'category': 'other',
            'remote_available': true,
          })
          .select()
          .single()
          .then<Object?>((r) => r, onError: (Object e) => e);
      if (spoof is Map) {
        expect(spoof['owner_id'], requester.id);
        await requester.backend.listings.delete(spoof['id'] as String);
      } else {
        expect(spoof, isA<PostgrestException>());
      }
      // Edits by the owner work.
      final edited = await owner.backend.listings.update(
        listing.id,
        draft.copyWith(title: 'Saturday robotics mentoring'),
      );
      expect(edited.title, 'Saturday robotics mentoring');
      listing = edited;
    },
    skip: skip,
  );

  test('saved listings are private to their owner', () async {
    await requester.backend.saved.save(listing.id);
    await requester.backend.saved.save(listing.id); // idempotent
    expect((await requester.backend.saved.mine()).map((s) => s.listingId), [
      listing.id,
    ]);
    final peek = await outsider.client
        .from('saved_listings')
        .select()
        .eq('user_id', requester.id);
    expect(peek, isEmpty);
  }, skip: skip);

  test('request, accept, and message between two clients', () async {
    final sent = await requester.backend.connections.send(
      recipientId: owner.id,
      listingId: listing.id,
      message: 'Salaam! Could I join on Saturday?',
    );
    expect(sent.status, RequestStatus.pending);
    expect(sent.listingTitle, listing.title);
    await expectLater(
      requester.backend.connections.send(
        recipientId: owner.id,
        listingId: listing.id,
        message: 'again',
      ),
      throwsA(isA<ConflictException>()),
    );
    // Only the recipient may accept.
    await expectLater(
      requester.backend.connections.respond(sent.id, accept: true),
      throwsA(isA<MarketplaceException>()),
    );
    await expectLater(
      outsider.backend.connections.respond(sent.id, accept: true),
      throwsA(isA<NotFoundException>()),
    );
    // Direct writes that bypass the functions are refused by row-level security.
    final directInsert = await outsider.client
        .from('connection_requests')
        .insert({
          'sender_id': outsider.id,
          'recipient_id': owner.id,
          'kind': 'introduction',
          'message': 'bypass',
        })
        .then<Object?>((_) => null, onError: (Object e) => e);
    expect(directInsert, isA<PostgrestException>());
    final directUpdate = await requester.client
        .from('connection_requests')
        .update({'status': 'accepted'})
        .eq('id', sent.id)
        .select();
    expect(directUpdate, isEmpty);

    // The owner sees and accepts it on their own client.
    final incoming = await owner.backend.connections.requests();
    expect(incoming.map((r) => r.id), contains(sent.id));
    final accepted = await owner.backend.connections.respond(
      sent.id,
      accept: true,
    );
    expect(accepted.status, RequestStatus.accepted);
    conversationId = accepted.conversationId!;
    await expectLater(
      owner.backend.connections.respond(sent.id, accept: false),
      throwsA(isA<InvalidTransitionException>()),
    );

    // Live update reaches the requester's client.
    final live = requester.backend.changes
        .firstWhere((t) => t == DataTopic.messages)
        .timeout(const Duration(seconds: 10));
    await Future<void>.delayed(const Duration(seconds: 1));
    await owner.backend.connections.sendMessage(
      conversationId,
      'Wa alaikum salaam, of course!',
      clientId: _uuid(1),
    );
    await live;

    final inbox = await requester.backend.connections.messages(conversationId);
    expect(inbox.single.body, 'Wa alaikum salaam, of course!');
    await requester.backend.connections.sendMessage(
      conversationId,
      'JazakAllah khair!',
      clientId: _uuid(2),
    );
    // A retried send with the same client id is not duplicated.
    await requester.backend.connections.sendMessage(
      conversationId,
      'JazakAllah khair!',
      clientId: _uuid(2),
    );
    final thread = await owner.backend.connections.messages(conversationId);
    expect(thread.map((m) => m.body), [
      'Wa alaikum salaam, of course!',
      'JazakAllah khair!',
    ]);
    final conversations = await owner.backend.connections.conversations();
    expect(conversations.first.lastMessagePreview, 'JazakAllah khair!');
  }, skip: skip);

  test('an unrelated member cannot reach the conversation', () async {
    expect(
      (await outsider.backend.connections.conversations()).map((c) => c.id),
      isNot(contains(conversationId)),
    );
    await expectLater(
      outsider.backend.connections.conversation(conversationId),
      throwsA(isA<NotAllowedException>()),
    );
    await expectLater(
      outsider.backend.connections.messages(conversationId),
      throwsA(isA<NotAllowedException>()),
    );
    await expectLater(
      outsider.backend.connections.sendMessage(
        conversationId,
        'let me in',
        clientId: _uuid(3),
      ),
      throwsA(isA<NotAllowedException>()),
    );
    final raw = await outsider.client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId);
    expect(raw, isEmpty);
    expect(await outsider.backend.connections.requests(), isEmpty);
  }, skip: skip);

  test('directory visibility changes what others can discover', () async {
    await owner.backend.profiles.updateSettings(directoryVisible: true);
    expect(
      (await outsider.backend.profiles.directory()).map((m) => m.id),
      contains(owner.id),
    );
    final card = (await outsider.backend.profiles.members({
      owner.id,
    }))[owner.id]!;
    expect(card.details, isNotNull);

    await owner.backend.profiles.updateSettings(directoryVisible: false);
    expect(
      (await outsider.backend.profiles.directory()).map((m) => m.id),
      isNot(contains(owner.id)),
    );
    final hidden = (await outsider.backend.profiles.members({
      owner.id,
    }))[owner.id]!;
    expect(hidden.displayName, 'Owner Test');
    expect(hidden.details, isNull);
    // Private settings are never readable by others.
    final settings = await outsider.client
        .from('profile_settings')
        .select()
        .eq('id', owner.id);
    expect(settings, isEmpty);
    // Introductions to members outside the directory are refused.
    await expectLater(
      outsider.backend.connections.send(recipientId: owner.id, message: 'hi'),
      throwsA(isA<NotAllowedException>()),
    );
  }, skip: skip);

  test('listing status transitions are enforced by the database', () async {
    await owner.backend.listings.setStatus(listing.id, ListingStatus.paused);
    expect(await outsider.backend.listings.byId(listing.id), isNull);
    expect(
      await requester.backend.listings.byId(listing.id),
      isNotNull,
      reason: 'has a request about it',
    );
    await expectLater(
      outsider.backend.connections.send(
        recipientId: owner.id,
        listingId: listing.id,
        message: 'hi',
      ),
      throwsA(isA<MarketplaceException>()),
    );
    await owner.backend.listings.setStatus(listing.id, ListingStatus.active);
    final closed = await owner.backend.listings.setStatus(
      listing.id,
      ListingStatus.closed,
    );
    expect(closed.closedAt, isNotNull);
    await expectLater(
      owner.backend.listings.setStatus(listing.id, ListingStatus.active),
      throwsA(isA<InvalidTransitionException>()),
    );
  }, skip: skip);

  test('activity is private and respects the personalization switch', () async {
    await requester.backend.activity.record(ActivityType.saved, listing);
    expect(await requester.backend.activity.mine(), hasLength(1));
    expect(
      await outsider.client
          .from('recommendation_events')
          .select()
          .eq('user_id', requester.id),
      isEmpty,
    );
    await requester.backend.profiles.updateSettings(
      personalizationEnabled: false,
    );
    await requester.backend.activity.record(ActivityType.viewed, listing);
    expect(await requester.backend.activity.mine(), hasLength(1));
    await requester.backend.activity.reset();
    expect(await requester.backend.activity.mine(), isEmpty);
  }, skip: skip);

  test('deleting a listing keeps the request title', () async {
    final second = await owner.backend.listings.create(
      draft.copyWith(title: 'Robotics office hours (test)'),
    );
    await outsider.backend.connections.send(
      recipientId: owner.id,
      listingId: second.id,
      message: 'Interested!',
    );
    await owner.backend.listings.delete(second.id);
    final r = (await outsider.backend.connections.requests()).firstWhere(
      (r) => r.listingTitle == 'Robotics office hours (test)',
    );
    expect(r.listingId, isNull);
  }, skip: skip);

  test('seeded fictional accounts work for local testing', () async {
    final client = SupabaseClient(
      config.supabaseUrl,
      config.supabaseKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    final res = await client.auth.signInWithPassword(
      email: 'amina@example.test',
      password: 'community-demo-2026',
    );
    final amina = SupabaseBackend(client, currentUserId: res.user!.id);
    expect(res.user!.id, SeedIds.amina);
    expect(
      (await amina.connections.conversations()).map((c) => c.id),
      contains(SeedIds.conversation(1)),
    );
    expect(
      (await amina.listings.visible())
          .where((l) => l.isSample && l.isActive)
          .length,
      greaterThan(25),
    );
    await amina.dispose();
    await client.dispose();
  }, skip: skip);

  test(
    'AI extraction falls back to rules when the function is unavailable',
    () async {
      final extractor = AiProfileExtractor(
        EdgeFunctionExtractionClient(requester.client),
        timeout: const Duration(seconds: 8),
      );
      final out = await extractor.extract(
        const OnboardingAnswers(seek: 'A robotics mentor'),
      );
      // With no ANTHROPIC_API_KEY configured the function answers 503 (or is not
      // served); either way members still get rule-based suggestions.
      if (out.source == ExtractionSource.rules) {
        expect(out.fallbackReason, isNotNull);
      }
      expect(out.extraction.goals.single.type, ListingType.mentorship);
    },
    skip: skip,
  );
}

String _uuid(int n) =>
    '99999999-9999-4999-8999-${runId.toString().padLeft(12, '0').substring(0, 9)}${n.toString().padLeft(3, '0')}';
