import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/listing.dart';
import '../domain/taxonomy.dart';
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
  const DiscoveryState({
    this.query = '',
    this.filters = MatchFilters.none,
    this.goalIndex,
  });

  final String query;
  final MatchFilters filters;

  /// When the request had several intents, the one selected (null = all).
  final int? goalIndex;

  bool get hasQuery => query.trim().isNotEmpty;

  DiscoveryState copyWith({
    String? query,
    MatchFilters? filters,
    int? Function()? goalIndex,
  }) => DiscoveryState(
    query: query ?? this.query,
    filters: filters ?? this.filters,
    goalIndex: goalIndex != null ? goalIndex() : this.goalIndex,
  );
}

/// Search text and explicit filters, shared by the home feed and results.
class DiscoveryController extends Notifier<DiscoveryState> {
  @override
  DiscoveryState build() {
    ref.watch(currentUserIdProvider); // Fresh state per member.
    return const DiscoveryState();
  }

  void search(String query) =>
      state = state.copyWith(query: query.trim(), goalIndex: () => null);

  void clearQuery() => state = state.copyWith(query: '', goalIndex: () => null);

  void selectGoal(int? index) => state = state.copyWith(goalIndex: () => index);

  void setFilters(MatchFilters filters) =>
      state = state.copyWith(filters: filters);

  void toggleType(ListingType type) {
    final types = {...state.filters.types};
    if (!types.remove(type)) types.add(type);
    setFilters(state.filters.copyWith(types: types));
  }

  void setTypes(Set<ListingType> types) =>
      setFilters(state.filters.copyWith(types: types));

  void setCategory(ListingCategory? category) => setFilters(
    state.filters.copyWith(categories: category == null ? {} : {category}),
  );

  void setArea(String? areaId) =>
      setFilters(state.filters.copyWith(areaId: () => areaId));

  void setRemoteOnly(bool value) =>
      setFilters(state.filters.copyWith(remoteOnly: value));

  void clearFilters() => setFilters(MatchFilters.none);

  /// Quick actions: a type filter plus an optional query.
  void quick({Set<ListingType> types = const {}, String query = ''}) {
    state = DiscoveryState(
      query: query,
      filters: MatchFilters(types: types),
    );
  }
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

/// Ranked results for the typed request (all intents).
final searchResultsProvider = FutureProvider<List<MatchResult>>((ref) async {
  final state = ref.watch(discoveryProvider);
  final listings = await ref.watch(visibleListingsProvider.future);
  final ctx = await _context(ref);
  final parsed = ref.watch(parsedQueryProvider);
  return ref
      .watch(matcherProvider)
      .rank(
        listings,
        MatchRequest(
          parsed: parsed,
          filters: state.filters,
          mode: MatchMode.search,
        ),
        ctx,
      );
});

/// [searchResultsProvider] narrowed to the selected intent.
final visibleSearchResultsProvider = Provider<AsyncValue<List<MatchResult>>>((
  ref,
) {
  final results = ref.watch(searchResultsProvider);
  final goalIndex = ref.watch(discoveryProvider.select((s) => s.goalIndex));
  final goals = ref.watch(parsedQueryProvider).goals;
  if (goalIndex == null || goalIndex >= goals.length) return results;
  final goal = goals[goalIndex];
  return results.whenData(
    (list) => list.where((r) => r.matchedGoal == goal).toList(),
  );
});

/// Personalized recommendations from the member's profile goals.
final recommendationsProvider = FutureProvider<List<MatchResult>>((ref) async {
  final filters = ref.watch(discoveryProvider.select((s) => s.filters));
  final listings = await ref.watch(visibleListingsProvider.future);
  final ctx = await _context(ref);
  return ref
      .watch(matcherProvider)
      .rank(
        listings,
        MatchRequest(filters: filters, mode: MatchMode.recommendations),
        ctx,
      );
});

/// Newest active listings from other members, with explicit filters applied.
final latestListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final filters = ref.watch(discoveryProvider.select((s) => s.filters));
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
            MatchRequest(filters: filters, mode: MatchMode.search),
            ctx,
            applyThreshold: false,
          ) !=
          null)
        l,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return eligible;
});

/// Directory members who fit the typed request.
final memberMatchesProvider = FutureProvider<List<MemberMatch>>((ref) async {
  final parsed = ref.watch(parsedQueryProvider);
  if (parsed.isEmpty) return const [];
  final directory = await ref.watch(directoryProvider.future);
  return const MemberMatcher().rank(directory, parsed);
});

/// Active listing counts per category, for the browse grid.
final categoryCountsProvider = FutureProvider<Map<ListingCategory, int>>((
  ref,
) async {
  final listings = await ref.watch(visibleListingsProvider.future);
  final me = ref.watch(currentUserIdProvider);
  final counts = <ListingCategory, int>{};
  for (final l in listings) {
    if (!l.isActive || l.ownerId == me) continue;
    counts[l.category] = (counts[l.category] ?? 0) + 1;
  }
  return counts;
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
