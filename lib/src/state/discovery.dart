import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/listing.dart';
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

/// Ranked results for the spoken or typed request, including all its intents.
final searchResultsProvider = FutureProvider<List<MatchResult>>((ref) async {
  final listings = await ref.watch(visibleListingsProvider.future);
  final ctx = await _context(ref);
  final parsed = ref.watch(parsedQueryProvider);
  return ref
      .watch(matcherProvider)
      .rank(
        listings,
        MatchRequest(parsed: parsed, mode: MatchMode.search),
        ctx,
      );
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
  final parsed = ref.watch(parsedQueryProvider);
  if (parsed.isEmpty) return const [];
  final directory = await ref.watch(directoryProvider.future);
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
