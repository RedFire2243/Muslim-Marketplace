import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/data/demo/demo_backend.dart';
import 'package:muslim_marketplace/src/data/errors.dart';
import 'package:muslim_marketplace/src/data/key_value_store.dart';
import 'package:muslim_marketplace/src/data/seed/seed_data.dart';
import 'package:muslim_marketplace/src/domain/activity.dart';
import 'package:muslim_marketplace/src/domain/goal.dart';
import 'package:muslim_marketplace/src/domain/listing.dart';
import 'package:muslim_marketplace/src/domain/profile.dart';
import 'package:muslim_marketplace/src/domain/taxonomy.dart';

final now = DateTime.utc(2026, 10, 24, 12);

Future<DemoBackend> open(MemoryStore store, {String? as}) async {
  var t = now;
  final b = await DemoBackend.open(
    store,
    clock: () => t = t.add(const Duration(seconds: 1)),
    latency: Duration.zero,
  );
  if (as != null) await b.switchTo(as);
  return b;
}

const draft = ListingDraft(
  title: 'Arabic conversation practice',
  description: 'Weekly conversation practice for adult beginners, online.',
  type: ListingType.service,
  direction: ListingDirection.offer,
  category: ListingCategory.education,
  tags: ['Arabic', ' arabic ', 'Conversation'],
  remoteAvailable: true,
);

void main() {
  late MemoryStore store;
  setUp(() => store = MemoryStore());

  group('listings and ownership', () {
    test('create, edit, pause, resume and close own listing', () async {
      final b = await open(store, as: SeedIds.amina);
      final l = await b.listings.create(draft);
      expect(l.ownerId, SeedIds.amina);
      expect(l.tags, ['arabic', 'conversation']);
      final edited = await b.listings.update(
        l.id,
        ListingDraft.fromListing(
          l,
        ).copyWith(title: 'Arabic conversation circle'),
      );
      expect(edited.title, 'Arabic conversation circle');
      expect(
        (await b.listings.setStatus(l.id, ListingStatus.paused)).status,
        ListingStatus.paused,
      );
      expect(
        (await b.listings.setStatus(l.id, ListingStatus.active)).status,
        ListingStatus.active,
      );
      final closed = await b.listings.setStatus(l.id, ListingStatus.closed);
      expect(closed.closedAt, isNotNull);
      await expectLater(
        b.listings.setStatus(l.id, ListingStatus.active),
        throwsA(isA<InvalidTransitionException>()),
      );
      await expectLater(
        b.listings.update(l.id, draft),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('other members cannot edit, close or delete a listing', () async {
      final b = await open(store, as: SeedIds.zaid);
      final yusufListing = SeedIds.listing(1);
      await expectLater(
        b.listings.update(yusufListing, draft),
        throwsA(isA<NotAllowedException>()),
      );
      await expectLater(
        b.listings.setStatus(yusufListing, ListingStatus.closed),
        throwsA(isA<NotAllowedException>()),
      );
      await expectLater(
        b.listings.delete(yusufListing),
        throwsA(isA<NotAllowedException>()),
      );
    });

    test('invalid drafts are rejected with field errors', () async {
      final b = await open(store, as: SeedIds.amina);
      try {
        await b.listings.create(const ListingDraft(title: 'Hi'));
        fail('expected validation error');
      } on ValidationException catch (e) {
        expect(
          e.fieldErrors.keys,
          containsAll([
            'type',
            'direction',
            'category',
            'title',
            'description',
            'location',
          ]),
        );
      }
    });

    test('a repeated submission does not create a duplicate', () async {
      final b = await open(store, as: SeedIds.amina);
      final first = await b.listings.create(draft);
      final second = await b.listings.create(draft);
      expect(second.id, first.id);
      expect(
        (await b.listings.mine()).where((l) => l.title == draft.title),
        hasLength(1),
      );
    });

    test('paused and closed listings are hidden from others', () async {
      final b = await open(store, as: SeedIds.amina);
      final visible = await b.listings.visible();
      expect(visible.map((l) => l.id), isNot(contains(SeedIds.listing(15))));
      expect(visible.map((l) => l.id), isNot(contains(SeedIds.listing(20))));
      expect(await b.listings.byId(SeedIds.listing(20)), isNull);
    });

    test('deleting keeps requests readable by title', () async {
      final b = await open(store, as: SeedIds.yusuf);
      await b.listings.delete(SeedIds.listing(1));
      final requests = await b.connections.requests();
      final r = requests.firstWhere((r) => r.id == SeedIds.request(1));
      expect(r.listingId, isNull);
      expect(r.listingTitle, 'Robotics mentorship for students');
    });
  });

  group('requests and conversations', () {
    test(
      'request lifecycle: send, accept, message, and only participants read',
      () async {
        final b = await open(store, as: SeedIds.zaid);
        final r = await b.connections.send(
          recipientId: SeedIds.yusuf,
          listingId: SeedIds.listing(1),
          message: 'Could you mentor me on a robotics project?',
        );
        expect(r.status, RequestStatus.pending);
        // Duplicate open requests are refused.
        await expectLater(
          b.connections.send(
            recipientId: SeedIds.yusuf,
            listingId: SeedIds.listing(1),
            message: 'again',
          ),
          throwsA(isA<ConflictException>()),
        );
        // The sender cannot accept their own request.
        await expectLater(
          b.connections.respond(r.id, accept: true),
          throwsA(isA<NotAllowedException>()),
        );

        await b.switchTo(SeedIds.yusuf);
        final accepted = await b.connections.respond(r.id, accept: true);
        expect(accepted.status, RequestStatus.accepted);
        final convId = accepted.conversationId!;
        await expectLater(
          b.connections.respond(r.id, accept: false),
          throwsA(isA<InvalidTransitionException>()),
        );
        await b.connections.sendMessage(
          convId,
          'Happy to help!',
          clientId: 'c1',
        );
        // Retrying with the same client id does not duplicate.
        await b.connections.sendMessage(
          convId,
          'Happy to help!',
          clientId: 'c1',
        );
        expect(await b.connections.messages(convId), hasLength(1));

        await b.switchTo(SeedIds.zaid);
        final msgs = await b.connections.messages(convId);
        expect(msgs.single.body, 'Happy to help!');
        await b.connections.sendMessage(convId, 'Thank you!', clientId: 'c2');

        // An unrelated member cannot read or write.
        await b.switchTo(SeedIds.sarah);
        await expectLater(
          b.connections.conversation(convId),
          throwsA(isA<NotAllowedException>()),
        );
        await expectLater(
          b.connections.messages(convId),
          throwsA(isA<NotAllowedException>()),
        );
        await expectLater(
          b.connections.sendMessage(convId, 'hi', clientId: 'x'),
          throwsA(isA<NotAllowedException>()),
        );
        expect(
          (await b.connections.conversations()).map((c) => c.id),
          isNot(contains(convId)),
        );
      },
    );

    test('decline and withdraw follow their roles', () async {
      final b = await open(store, as: SeedIds.fatima);
      await expectLater(
        b.connections.withdraw(SeedIds.request(2)),
        throwsA(isA<InvalidTransitionException>()),
      );
      final declined = await b.connections.respond(
        SeedIds.request(2),
        accept: false,
      );
      expect(declined.status, RequestStatus.declined);
      expect(declined.conversationId, isNull);

      await b.switchTo(SeedIds.hana);
      final withdrawn = await b.connections.withdraw(SeedIds.request(4));
      expect(withdrawn.status, RequestStatus.withdrawn);
    });

    test(
      'requests about inactive listings or to hidden members are refused',
      () async {
        final b = await open(store, as: SeedIds.amina);
        await expectLater(
          b.connections.send(
            recipientId: SeedIds.hassan,
            listingId: SeedIds.listing(20),
            message: 'hi',
          ),
          throwsA(isA<InvalidTransitionException>()),
        );
        await expectLater(
          b.connections.send(recipientId: SeedIds.ibrahim, message: 'hi'),
          throwsA(isA<NotAllowedException>()),
        );
        await expectLater(
          b.connections.send(
            recipientId: SeedIds.fatima,
            listingId: SeedIds.listing(1),
            message: 'hi',
          ),
          throwsA(isA<NotAllowedException>()),
        );
      },
    );

    test('failed sends can be retried', () async {
      final b = await open(store, as: SeedIds.amina);
      b.failNextMessageSends = 1;
      final conv = SeedIds.conversation(1);
      await expectLater(
        b.connections.sendMessage(conv, 'hello', clientId: 'r1'),
        throwsA(isA<NetworkException>()),
      );
      final m = await b.connections.sendMessage(conv, 'hello', clientId: 'r1');
      expect(m.body, 'hello');
    });
  });

  group('visibility', () {
    test('directory visibility controls discovery and details', () async {
      final b = await open(store, as: SeedIds.zaid);
      expect(
        (await b.profiles.directory()).map((m) => m.id),
        contains(SeedIds.yusuf),
      );
      final card = (await b.profiles.members({SeedIds.yusuf}))[SeedIds.yusuf]!;
      expect(card.details, isNotNull);

      await b.switchTo(SeedIds.yusuf);
      await b.profiles.updateSettings(directoryVisible: false);

      await b.switchTo(SeedIds.zaid);
      expect(
        (await b.profiles.directory()).map((m) => m.id),
        isNot(contains(SeedIds.yusuf)),
      );
      final hidden = (await b.profiles.members({
        SeedIds.yusuf,
      }))[SeedIds.yusuf]!;
      expect(hidden.displayName, 'Yusuf Karim'); // owner of an active listing
      expect(hidden.details, isNull);
      // Published listings stay visible until paused or closed.
      expect(
        (await b.listings.visible()).map((l) => l.id),
        contains(SeedIds.listing(1)),
      );
      // Introductions to hidden members are refused.
      await expectLater(
        b.connections.send(recipientId: SeedIds.yusuf, message: 'hi'),
        throwsA(isA<NotAllowedException>()),
      );
    });

    test('new members start outside the directory', () async {
      final b = await open(store);
      final id = await b.createMember();
      final me = await b.profiles.me();
      expect(me.id, id);
      expect(me.directoryVisible, isFalse);
      expect(me.onboardingComplete, isFalse);
    });
  });

  group('persistence', () {
    test('everything survives reopening from storage', () async {
      final b = await open(store);
      final id = await b.createMember();
      await b.profiles.saveMine(
        const ProfileDraft(
          displayName: 'Test Member',
          goals: [
            Goal(
              type: ListingType.mentorship,
              role: GoalRole.seeking,
              subjects: ['Robotics'],
            ),
          ],
          areaId: 'edison',
        ),
        completeOnboarding: true,
      );
      final l = await b.listings.create(draft);
      await b.saved.save(SeedIds.listing(1));
      await b.activity.record(
        ActivityType.saved,
        (await b.listings.byId(SeedIds.listing(1)))!,
      );
      final r = await b.connections.send(
        recipientId: SeedIds.yusuf,
        listingId: SeedIds.listing(1),
        message: 'Salaam',
      );

      final reopened = await open(store);
      expect(reopened.activeUserId, id);
      final me = await reopened.profiles.me();
      expect(me.displayName, 'Test Member');
      expect(me.onboardingComplete, isTrue);
      expect(me.goals.single.subjects, ['Robotics']);
      expect((await reopened.listings.mine()).map((x) => x.id), contains(l.id));
      expect(
        (await reopened.saved.mine()).map((s) => s.listingId),
        contains(SeedIds.listing(1)),
      );
      expect((await reopened.activity.mine()), hasLength(1));
      expect(
        (await reopened.connections.requests()).map((x) => x.id),
        contains(r.id),
      );
    });

    test('reset restores sample data only', () async {
      store.values['unrelated.key'] = 'keep me';
      final b = await open(store, as: SeedIds.amina);
      await b.listings.create(draft);
      await b.reset();
      final reopened = await open(store, as: SeedIds.amina);
      expect(
        (await reopened.listings.mine()).map((l) => l.title),
        isNot(contains(draft.title)),
      );
      expect(store.values['unrelated.key'], 'keep me');
      expect(
        (await reopened.members()).length,
        SeedData.build(now).profiles.length,
      );
    });

    test('corrupt storage falls back to fresh sample data', () async {
      store.values[DemoBackend.storageKey] = '{not json';
      final b = await open(store);
      expect((await b.members()), isNotEmpty);
    });

    test('personalization off stops recording', () async {
      final b = await open(store, as: SeedIds.amina);
      await b.profiles.updateSettings(personalizationEnabled: false);
      final before = (await b.activity.mine()).length;
      await b.activity.record(
        ActivityType.viewed,
        (await b.listings.byId(SeedIds.listing(12)))!,
      );
      expect((await b.activity.mine()).length, before);
      await b.activity.reset();
      expect(await b.activity.mine(), isEmpty);
    });
  });

  test(
    'demo backend exposes demo controls; it is the only one that does',
    () async {
      final b = await open(store);
      expect(b.demo, same(b));
    },
  );
}
