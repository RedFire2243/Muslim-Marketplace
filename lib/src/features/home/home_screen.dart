import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/areas.dart';
import '../../domain/listing.dart';
import '../../matching/intent_parser.dart';
import '../../matching/matcher.dart';
import '../../routing/router.dart';
import '../../state/data_providers.dart';
import '../../state/discovery.dart';
import '../../state/session.dart';
import '../../state/voice_search.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/focusable_card.dart';
import '../../ui/widgets/listing_card.dart';
import '../listing/connected_listing_card.dart';
import 'voice_search_hero.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  final _searchPanelKey = GlobalKey();
  var _revealScheduled = false;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(discoveryProvider).query;
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit([String? text]) {
    final q = (text ?? _search.text).trim();
    if (text != null) _search.text = text;
    if (q.isEmpty) {
      ref.read(discoveryProvider.notifier).clearQuery();
    } else {
      ref.read(discoveryProvider.notifier).search(q);
      _revealResults();
    }
    _searchFocus.unfocus();
  }

  void _clearSearch() {
    _search.clear();
    ref.read(discoveryProvider.notifier).clearQuery();
    _scrollTo(0);
  }

  void _scrollTo(double offset) {
    if (!_scroll.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(offset);
    } else {
      _scroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _revealResults() {
    if (_revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted || !_scroll.hasClients) return;
      final panel = _searchPanelKey.currentContext?.findRenderObject();
      if (panel is! RenderBox || !panel.hasSize) return;
      final offset = (panel.size.height - Space.lg).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scrollTo(offset);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(visibleListingsProvider);
    ref.invalidate(activityProvider);
    await ref.read(visibleListingsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryProvider);
    final profile = ref.watch(myProfileProvider).value;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final compact = Breakpoints.isCompact(context);

    ref.listen(discoveryProvider.select((s) => s.query), (prev, next) {
      if (_search.text.trim() != next) _search.text = next;
      if (next.isNotEmpty && prev != next) _revealResults();
    });
    final voiceAvailable = ref.watch(speechTranscriberProvider) != null;
    final voice = voiceAvailable ? ref.watch(voiceSearchProvider) : null;
    ref.listen(voiceSearchProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        showMessage(context, next.error!);
      }
      if (prev?.phase == VoicePhase.transcribing &&
          next.phase == VoicePhase.idle &&
          next.error == null) {
        _revealResults();
      }
    });

    return Scaffold(
      floatingActionButton: compact
          ? FloatingActionButton.extended(
              heroTag: 'home-post',
              onPressed: () => context.openPost(),
              icon: const Icon(Icons.add),
              label: const Text('Post'),
              tooltip: 'Post an opportunity',
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: ContentWidth(
                child: Padding(
                  key: _searchPanelKey,
                  padding: const EdgeInsets.only(top: Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                profile == null
                                    ? 'Discover'
                                    : 'Salaam, ${profile.firstName}',
                                style: t.titleLarge,
                              ),
                            ),
                          ),
                          Text(
                            'Discover',
                            style: t.labelMedium?.copyWith(
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.lg),
                      VoiceSearchHero(
                        voice: voice,
                        hasQuery: state.hasQuery,
                        controller: _search,
                        focusNode: _searchFocus,
                        onSubmit: _submit,
                        onClear: _clearSearch,
                        onVoice: () {
                          _searchFocus.unfocus();
                          ref.read(voiceSearchProvider.notifier).toggle();
                        },
                      ),
                      const SizedBox(height: Space.xl),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ContentWidth(
                child: state.hasQuery
                    ? _SearchResults(onClearSearch: _clearSearch)
                    : const _DiscoverFeed(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

/// Personalized recommendations and the newest community listings.
class _DiscoverFeed extends ConsumerWidget {
  const _DiscoverFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(recommendationsProvider);
    final latest = ref.watch(latestListingsProvider);
    final profile = ref.watch(myProfileProvider).value;
    final personalizing = profile?.personalizationEnabled ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recommended for you',
          subtitle: profile == null || profile.goals.isEmpty
              ? 'Add goals to your profile to get recommendations.'
              : 'Based on your goals${personalizing ? ', interests and activity' : ' and interests'}.',
          action: profile != null && profile.goals.isEmpty
              ? TextButton(
                  onPressed: () => context.go('/profile/edit'),
                  child: const Text('Add goals'),
                )
              : null,
        ),
        AsyncView(
          value: recs,
          onRetry: () => ref.invalidate(visibleListingsProvider),
          data: (results) {
            if (results.isEmpty) {
              return const EmptyState(
                compact: true,
                icon: Icons.travel_explore,
                title: 'No recommendations yet',
                message:
                    'Tell us what you’re looking for, or explore the newest listings below.',
              );
            }
            return _ResultGrid(
              results: results.take(6).toList(),
              allowShowLess: personalizing,
            );
          },
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(title: 'Newest in the community'),
        AsyncView(
          value: latest,
          onRetry: () => ref.invalidate(visibleListingsProvider),
          data: (listings) => listings.isEmpty
              ? const EmptyState(
                  compact: true,
                  icon: Icons.inbox_outlined,
                  title: 'Your community is just getting started',
                  message:
                      'Check back soon, or post an opportunity of your own.',
                )
              : _ListingGrid(listings: listings.take(9).toList()),
        ),
      ],
    );
  }
}

/// Search results with the interpreted request and directory matches.
class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.onClearSearch});
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoveryProvider);
    final parsed = ref.watch(parsedQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final members = ref.watch(memberMatchesProvider).value ?? const [];
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your matches', style: t.titleLarge),
                  const SizedBox(height: Space.xs),
                  SelectableText('“${state.query}”', style: t.bodyLarge),
                ],
              ),
            ),
            const SizedBox(width: Space.xs),
            TextButton(
              onPressed: onClearSearch,
              child: const Text('Start over'),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        _Interpretation(parsed: parsed),
        const SizedBox(height: Space.lg),
        AsyncView(
          value: results,
          onRetry: () => ref.invalidate(visibleListingsProvider),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.search_off,
                title: 'No listings match that yet',
                message:
                    'Nothing in the community matches “${state.query}” yet. Try describing it another way, or post what you’re looking for so others can find you.',
                actions: [
                  OutlinedButton(
                    onPressed: onClearSearch,
                    child: const Text('Clear search'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => context.openPost(),
                    child: const Text('Post a request'),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${list.length} result${list.length == 1 ? '' : 's'}, best match first',
                    style: t.labelLarge?.copyWith(color: c.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: Space.sm),
                _ResultGrid(results: list),
              ],
            );
          },
        ),
        if (members.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          const SectionHeader(
            title: 'Members who might help',
            subtitle: 'People in the directory whose profiles mention this.',
          ),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final m in members)
                SizedBox(
                  width: 280,
                  child: FocusableCard(
                    padding: const EdgeInsets.all(Space.sm),
                    onTap: () => context.openMember(m.member.id),
                    child: Row(
                      children: [
                        MemberAvatar(
                          name: m.member.displayName,
                          id: m.member.id,
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      m.member.displayName,
                                      style: t.labelLarge,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (m.member.isSample) ...[
                                    const SizedBox(width: 6),
                                    const SampleBadge(),
                                  ],
                                ],
                              ),
                              Text(
                                m.reason,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A read-only explanation of the whole request, with no result filters.
class _Interpretation extends StatelessWidget {
  const _Interpretation({required this.parsed});
  final ParsedRequest parsed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final area = Areas.byId(parsed.areaId);
    final remote = switch (parsed.remote) {
      RemotePreference.remoteOk => 'Remote is fine',
      RemotePreference.remoteOnly => 'Remote only',
      RemotePreference.inPersonOnly => 'In person only',
      RemotePreference.unspecified => null,
    };
    final details = [
      for (final goal in parsed.goals) goal.fullLabel,
      if (parsed.goals.isEmpty)
        for (final keyword in parsed.keywords)
          if (keyword.weight >= 0.5) keyword.label,
      if (area != null) 'Near ${area.name}',
      ?remote,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        border: Border(left: BorderSide(color: c.primaryContainer, width: 3)),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parsed.goals.length > 1
                ? 'We found ${parsed.goals.length} things you’re looking for'
                : 'What we understood',
            style: t.labelLarge,
          ),
          const SizedBox(height: Space.xxs),
          if (details.isEmpty)
            Text(
              'Matching your words against listing titles, tags and descriptions.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: Space.md,
              runSpacing: Space.xxs,
              children: [
                for (final detail in details)
                  Text(
                    detail,
                    style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ResultGrid extends ConsumerWidget {
  const _ResultGrid({required this.results, this.allowShowLess = false});
  final List<MatchResult> results;
  final bool allowShowLess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedIdsProvider);
    final now = ref.watch(clockProvider)();
    return CardGrid(
      itemCount: results.length,
      itemBuilder: (context, i, expand) {
        final r = results[i];
        return ConnectedListingCard(
          listing: r.listing,
          expand: expand,
          saved: saved.contains(r.listing.id),
          now: now,
          reason: r.primaryReason,
          secondaryReason: r.reasons.length > 1 ? r.reasons[1].text : null,
          allowShowLess: allowShowLess,
        );
      },
    );
  }
}

class _ListingGrid extends ConsumerWidget {
  const _ListingGrid({required this.listings});
  final List<Listing> listings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedIdsProvider);
    final now = ref.watch(clockProvider)();
    return CardGrid(
      itemCount: listings.length,
      itemBuilder: (context, i, expand) => ConnectedListingCard(
        listing: listings[i],
        expand: expand,
        saved: saved.contains(listings[i].id),
        now: now,
      ),
    );
  }
}
