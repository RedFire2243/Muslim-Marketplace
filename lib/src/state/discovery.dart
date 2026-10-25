import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/gemini_client.dart';
import '../domain/listing.dart';
import '../domain/profile.dart';
import '../matching/gemini_search.dart';
import '../matching/intent_parser.dart';
import '../matching/matcher.dart';
import '../matching/member_matcher.dart';
import 'data_providers.dart';
import 'session.dart';

final matcherProvider = Provider<ListingMatcher>(
  (ref) => const ListingMatcher(),
);
final parserProvider = Provider<DeterministicParser>(
  (ref) => const DeterministicParser(),
);

class DiscoveryState {
  const DiscoveryState({this.query = ''});

  final String query;

  bool get hasQuery => query.trim().isNotEmpty;
}

/// The spoken or typed request shared by the home feed and results.
class DiscoveryController extends Notifier<DiscoveryState> {
  @override
  DiscoveryState build() {
    ref.watch(currentUserIdProvider); // Fresh state per member.
    return const DiscoveryState();
  }

  void search(String query) => state = DiscoveryState(query: query.trim());

  void clearQuery() => state = const DiscoveryState();
}

final discoveryProvider = NotifierProvider<DiscoveryController, DiscoveryState>(
  DiscoveryController.new,
);

final parsedQueryProvider = Provider<ParsedRequest>((ref) {
  final q = ref.watch(discoveryProvider.select((s) => s.query));
  return ref.watch(parserProvider).parseSearch(q);
});

Future<MatchContext> _context(Ref ref) async {
  final profile = await ref.watch(myProfileProvider.future);
  return MatchContext(
    now: ref.watch(clockProvider)().toUtc(),
    viewerId: ref.watch(currentUserIdProvider),
    profile: profile,
    preferences: ref.watch(preferenceModelProvider),
  );
}

/// Direct Gemini access is an explicit private-test configuration. The same
/// client handles one joint listing/directory selection for each request.
final geminiSearchProvider = Provider<GeminiSearch?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasDirectGemini) return null;
  // A slow answer falls back to the local ranking instead of holding results.
  final client = GeminiClient(
    apiKey: config.geminiApiKey,
    model: config.geminiModel,
    timeout: const Duration(seconds: 10),
  );
  ref.onDispose(client.dispose);
  return GeminiSearch(client: client, matcher: ref.watch(matcherProvider));
});

/// This cache depends only on the query, session and visible candidate data.
/// Private preference/activity changes may re-score results locally without
/// sending another Gemini request or exposing those fields.
final geminiSearchSelectionProvider = FutureProvider<GeminiSearchSelection?>((
  ref,
) async {
  final query = ref.watch(discoveryProvider.select((state) => state.query));
  final search = ref.watch(geminiSearchProvider);
  if (query.trim().isEmpty || search == null) return null;
  final viewerId = ref.watch(currentUserIdProvider);
  final parsed = ref.watch(parsedQueryProvider);
  final now = ref.watch(clockProvider)();
  final listingsFuture = ref.watch(visibleListingsProvider.future);
  final directoryFuture = ref
      .watch(directoryProvider.future)
      .catchError((Object _) => <MemberProfile>[]);
  final listings = await listingsFuture;
  final directory = await directoryFuture;
  if (!ref.mounted) return null;
  try {
    return await search.search(
      query: query,
      listings: listings,
      members: directory,
      parsed: parsed,
      context: MatchContext(now: now.toUtc(), viewerId: viewerId),
    );
  } catch (_) {
    // Invalid AI output, denied access and network failures keep search usable.
    return null;
  }
});

/// Ranked results for the spoken or typed request, including all its intents.
final searchResultsProvider = FutureProvider<List<MatchResult>>((ref) async {
  final listingsFuture = ref.watch(visibleListingsProvider.future);
  final selectionFuture = ref.watch(geminiSearchSelectionProvider.future);
  final parsed = ref.watch(parsedQueryProvider);
  final matcher = ref.watch(matcherProvider);
  final ctx = await _context(ref);
  final listings = await listingsFuture;
  final selection = await selectionFuture;
  final request = MatchRequest(parsed: parsed, mode: MatchMode.search);
  if (selection != null) {
    final byId = {for (final listing in listings) listing.id: listing};
    return [
      for (final id in selection.listingIds)
        if (byId[id] case final listing?)
          if (matcher.evaluate(listing, request, ctx, applyThreshold: false)
              case final result?)
            result,
    ];
  }
  return matcher.rank(listings, request, ctx);
});

/// Personalized recommendations from the member's profile goals.
final recommendationsProvider = FutureProvider<List<MatchResult>>((ref) async {
  final listings = await ref.watch(visibleListingsProvider.future);
  final ctx = await _context(ref);
  return ref
      .watch(matcherProvider)
      .rank(listings, const MatchRequest(mode: MatchMode.recommendations), ctx);
});

/// Newest active listings from other members.
final latestListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final listings = await ref.watch(visibleListingsProvider.future);
  final me = ref.watch(currentUserIdProvider);
  final matcher = ref.watch(matcherProvider);
  final ctx = MatchContext(
    now: ref.watch(clockProvider)().toUtc(),
    viewerId: me,
  );
  final eligible = [
    for (final l in listings)
      if (matcher.evaluate(
            l,
            const MatchRequest(mode: MatchMode.search),
            ctx,
            applyThreshold: false,
          ) !=
          null)
        l,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return eligible;
});

/// Directory members who fit the spoken or typed request.
final memberMatchesProvider = FutureProvider<List<MemberMatch>>((ref) async {
  final hasQuery = ref.watch(
    discoveryProvider.select((state) => state.hasQuery),
  );
  if (!hasQuery) return const [];
  final parsed = ref.watch(parsedQueryProvider);
  final viewerId = ref.watch(currentUserIdProvider);
  final directoryFuture = ref
      .watch(directoryProvider.future)
      .catchError((Object _) => <MemberProfile>[]);
  final selectionFuture = ref.watch(geminiSearchSelectionProvider.future);
  final directory = (await directoryFuture)
      .where((member) => member.id != viewerId && member.isDiscoverable)
      .toList();
  final selection = await selectionFuture;
  if (selection != null) {
    final byId = {for (final member in directory) member.id: member};
    return [
      for (var i = 0; i < selection.memberIds.length; i++)
        if (byId[selection.memberIds[i]] case final member?)
          if (GeminiSearch.eligibleMember(member, parsed, viewerId))
            GeminiSearch.memberMatch(member, parsed, i),
    ];
  }
  if (parsed.isEmpty) return const [];
  return const MemberMatcher().rank(directory, parsed);
});

/// Explanation for one listing against the member's profile (detail page).
final listingMatchProvider = FutureProvider.family<MatchResult?, String>((
  ref,
  id,
) async {
  final listing = await ref.watch(listingByIdProvider(id).future);
  if (listing == null) return null;
  final ctx = await _context(ref);
  final matcher = ref.watch(matcherProvider);
  final state = ref.watch(discoveryProvider);
  // Prefer the reasons from the current search when the listing is in it.
  if (state.hasQuery) {
    final r = matcher.evaluate(
      listing,
      MatchRequest(
        parsed: ref.watch(parsedQueryProvider),
        mode: MatchMode.search,
      ),
      ctx,
    );
    if (r != null) return r;
  }
  return matcher.evaluate(
    listing,
    const MatchRequest(mode: MatchMode.recommendations),
    ctx,
  );
});
