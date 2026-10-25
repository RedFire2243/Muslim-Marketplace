import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_marketplace/src/ai/gemini_client.dart';
import 'package:muslim_marketplace/src/domain/goal.dart';
import 'package:muslim_marketplace/src/domain/listing.dart';
import 'package:muslim_marketplace/src/domain/profile.dart';
import 'package:muslim_marketplace/src/domain/taxonomy.dart';
import 'package:muslim_marketplace/src/matching/gemini_search.dart';
import 'package:muslim_marketplace/src/matching/intent_parser.dart';
import 'package:muslim_marketplace/src/matching/matcher.dart';
import 'package:muslim_marketplace/src/state/data_providers.dart';
import 'package:muslim_marketplace/src/state/discovery.dart';
import 'package:muslim_marketplace/src/state/session.dart';

final now = DateTime.utc(2026, 10, 25);
const parser = DeterministicParser();
const matcher = ListingMatcher();

Listing listing(
  String id, {
  String ownerId = 'owner',
  ListingType type = ListingType.service,
  ListingDirection direction = ListingDirection.offer,
  ListingStatus status = ListingStatus.active,
  String title = 'Audio restoration',
  String description = 'Removes hiss and crackles from podcasts.',
}) => Listing(
  id: id,
  ownerId: ownerId,
  title: title,
  description: description,
  type: type,
  direction: direction,
  category: ListingCategory.creative,
  compensationDetails: 'CONTACT_NOT_NEEDED',
  status: status,
  createdAt: now,
  updatedAt: now,
);

MemberProfile member(
  String id, {
  MemberDetails? details = const MemberDetails(
    headline: 'Audio engineer',
    skills: ['audio restoration'],
    offeringSummary: 'Restores damaged sound recordings',
    seekingSummary: 'Looking for collaborators',
    interests: ['INTEREST_NOT_NEEDED'],
    communityAffiliation: 'AFFILIATION_NOT_NEEDED',
    linkedinUrl: 'https://linkedin.com/in/CONTACT_NOT_NEEDED',
  ),
}) => MemberProfile(id: id, displayName: 'NAME_NOT_NEEDED', details: details);

http.Response response(Map<String, Object?> result) => http.Response(
  jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': jsonEncode(result)},
          ],
        },
      },
    ],
  }),
  200,
);

GeminiSearch searchWith(Future<http.Response> Function(http.Request) handler) =>
    GeminiSearch(
      client: GeminiClient(
        apiKey: 'test-key',
        model: 'test-model',
        client: MockClient(handler),
      ),
    );

ProviderContainer containerFor(
  GeminiSearch? search, {
  List<Listing>? listings,
  List<MemberProfile>? members,
}) {
  final container = ProviderContainer(
    overrides: [
      geminiSearchProvider.overrideWithValue(search),
      currentUserIdProvider.overrideWithValue('viewer'),
      clockProvider.overrideWithValue(() => now),
      myProfileProvider.overrideWith((ref) async => null),
      visibleListingsProvider.overrideWith(
        (ref) async => listings ?? [listing('audio')],
      ),
      directoryProvider.overrideWith(
        (ref) async => members ?? [member('sound-expert')],
      ),
      activityProvider.overrideWith((ref) async => []),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'only eligible existing IDs survive unknown IDs and duplicates',
    () async {
      Map<String, dynamic>? sent;
      final search = searchWith((request) async {
        sent = jsonDecode(
          (jsonDecode(request.body)['contents'][0]['parts'][0]['text'])
              as String,
        );
        return response({
          'listingIds': [
            'missing',
            'paused',
            'own',
            'request',
            'offer',
            'offer',
            4,
          ],
          'memberIds': ['private', 'viewer', 'missing', 'public', 'public'],
        });
      });
      final query = 'I am looking for a robotics mentor';
      final result = await search.search(
        query: query,
        listings: [
          listing('offer', type: ListingType.mentorship),
          listing(
            'request',
            type: ListingType.mentorship,
            direction: ListingDirection.request,
          ),
          listing(
            'paused',
            type: ListingType.mentorship,
            status: ListingStatus.paused,
          ),
          listing('own', ownerId: 'viewer', type: ListingType.mentorship),
        ],
        members: [
          member('public'),
          member('private', details: null),
          member('viewer'),
        ],
        parsed: parser.parseSearch(query),
        context: MatchContext(now: now, viewerId: 'viewer'),
      );
      expect(result.listingIds, ['offer']);
      expect(result.memberIds, ['public']);
      expect((sent!['listings'] as List).map((candidate) => candidate['id']), [
        'offer',
      ]);
      expect((sent!['members'] as List).map((candidate) => candidate['id']), [
        'public',
      ]);
    },
  );

  test('request contains only query and public professional fields', () async {
    late String sent;
    final search = searchWith((request) async {
      sent = request.body;
      return response({
        'listingIds': ['audio'],
        'memberIds': ['public'],
      });
    });
    await search.search(
      query: 'audio restoration',
      listings: [listing('audio')],
      members: [member('public')],
      parsed: parser.parseSearch('audio restoration'),
      context: MatchContext(
        now: now,
        viewerId: 'viewer',
        profile: Profile(
          id: 'viewer',
          displayName: 'PRIVATE_VIEWER',
          goals: const [
            Goal(
              type: ListingType.job,
              role: GoalRole.seeking,
              subjects: ['PRIVATE_GOAL'],
            ),
          ],
          communityAffiliation: 'PRIVATE_VIEWER_AFFILIATION',
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
    for (final forbidden in [
      'PRIVATE_VIEWER',
      'PRIVATE_GOAL',
      'AFFILIATION_NOT_NEEDED',
      'CONTACT_NOT_NEEDED',
      'NAME_NOT_NEEDED',
      'INTEREST_NOT_NEEDED',
      'communityAffiliation',
      'linkedinUrl',
      'personalizationEnabled',
      'goals',
      'ownerId',
      'compensationDetails',
    ]) {
      expect(sent, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(sent, contains('Removes hiss and crackles'));
    expect(sent, contains('Restores damaged sound'));
  });

  test(
    'semantic selection admits an eligible match beyond keyword thresholds',
    () async {
      const query = 'make a noisy recording sound clean';
      final parsed = parser.parseSearch(query);
      final audio = listing('audio');
      final context = MatchContext(now: now, viewerId: 'viewer');
      expect(
        matcher.rank([audio], MatchRequest(parsed: parsed), context),
        isEmpty,
      );
      final search = searchWith(
        (request) async => response({
          'listingIds': ['audio'],
          'memberIds': [],
        }),
      );
      final container = containerFor(search, listings: [audio], members: []);
      container.read(discoveryProvider.notifier).search(query);
      final results = await container.read(searchResultsProvider.future);
      expect(results.map((result) => result.listing.id), ['audio']);
      final grounded = matcher.evaluate(
        audio,
        MatchRequest(parsed: parsed),
        context,
        applyThreshold: false,
      )!;
      expect(
        results.single.reasons.map((reason) => reason.text),
        grounded.reasons.map((reason) => reason.text),
      );
    },
  );

  test('listing and member providers share one cached Gemini call', () async {
    var calls = 0;
    final search = searchWith((request) async {
      calls++;
      return response({
        'listingIds': ['audio'],
        'memberIds': ['sound-expert'],
      });
    });
    final container = containerFor(search);
    container
        .read(discoveryProvider.notifier)
        .search('restore my damaged recording');
    final results = await Future.wait([
      container.read(searchResultsProvider.future),
      container.read(memberMatchesProvider.future),
    ]);
    expect(results[0], hasLength(1));
    expect(results[1], hasLength(1));
    expect(calls, 1);
    await container.read(searchResultsProvider.future);
    await container.read(memberMatchesProvider.future);
    expect(calls, 1);
    final members = await container.read(memberMatchesProvider.future);
    expect(members.single.reason, 'Offers: Restores damaged sound recordings');
  });

  test(
    'a genuine empty AI selection stays empty instead of using local matches',
    () async {
      final search = searchWith(
        (request) async => response({'listingIds': [], 'memberIds': []}),
      );
      final container = containerFor(search);
      container.read(discoveryProvider.notifier).search('audio restoration');
      expect(await container.read(searchResultsProvider.future), isEmpty);
      expect(await container.read(memberMatchesProvider.future), isEmpty);
    },
  );

  test(
    'API errors and malformed selections fall back to deterministic search',
    () async {
      for (final badResponse in [
        http.Response('unavailable', 503),
        response({'listingIds': 'wrong shape', 'memberIds': []}),
      ]) {
        final search = searchWith((request) async => badResponse);
        final container = containerFor(search);
        container.read(discoveryProvider.notifier).search('audio restoration');
        expect(
          (await container.read(
            searchResultsProvider.future,
          )).map((result) => result.listing.id),
          ['audio'],
        );
      }
    },
  );

  test(
    'no direct mode uses deterministic search and no query never calls Gemini',
    () async {
      var calls = 0;
      final search = searchWith((request) async {
        calls++;
        return response({'listingIds': [], 'memberIds': []});
      });
      final empty = containerFor(search);
      await empty.read(searchResultsProvider.future);
      await empty.read(memberMatchesProvider.future);
      expect(calls, 0);
      final local = containerFor(null);
      local.read(discoveryProvider.notifier).search('audio restoration');
      expect(
        (await local.read(
          searchResultsProvider.future,
        )).map((result) => result.listing.id),
        ['audio'],
      );
      expect(calls, 0);
    },
  );

  test('a directory fetch failure still allows listing search', () async {
    final search = searchWith(
      (request) async => response({
        'listingIds': ['audio'],
        'memberIds': [],
      }),
    );
    final container = ProviderContainer(
      overrides: [
        geminiSearchProvider.overrideWithValue(search),
        currentUserIdProvider.overrideWithValue('viewer'),
        clockProvider.overrideWithValue(() => now),
        myProfileProvider.overrideWith((ref) async => null),
        visibleListingsProvider.overrideWith((ref) async => [listing('audio')]),
        directoryProvider.overrideWith(
          (ref) async => throw StateError('offline directory'),
        ),
        activityProvider.overrideWith((ref) async => []),
      ],
    );
    addTearDown(container.dispose);
    container.read(discoveryProvider.notifier).search('audio restoration');
    expect(
      (await container.read(
        searchResultsProvider.future,
      )).map((result) => result.listing.id),
      ['audio'],
    );
    expect(await container.read(memberMatchesProvider.future), isEmpty);
  });

  test(
    'model output is capped and offer-only searches exclude seeker-only profiles',
    () async {
      final listings = List.generate(40, (i) => listing('listing-$i'));
      final members = List.generate(10, (i) => member('member-$i'));
      final search = searchWith(
        (request) async => response({
          'listingIds': listings.map((listing) => listing.id).toList(),
          'memberIds': members.map((member) => member.id).toList(),
        }),
      );
      final result = await search.search(
        query: 'audio restoration',
        listings: listings,
        members: members,
        parsed: parser.parseSearch('audio restoration'),
        context: MatchContext(now: now, viewerId: 'viewer'),
      );
      expect(result.listingIds, hasLength(GeminiSearch.maxListingResults));
      expect(result.memberIds, hasLength(GeminiSearch.maxMemberResults));
      final seeker = member(
        'seeker',
        details: const MemberDetails(seekingSummary: 'I need a mentor'),
      );
      expect(
        GeminiSearch.eligibleMember(
          seeker,
          parser.parseSearch('looking for a mentor'),
          'viewer',
        ),
        isFalse,
      );
    },
  );
}
