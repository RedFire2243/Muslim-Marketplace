import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/areas.dart';
import '../../domain/listing.dart';
import '../../domain/taxonomy.dart';
import '../../matching/intent_parser.dart';
import '../../matching/matcher.dart';
import '../../routing/router.dart';
import '../../state/data_providers.dart';
import '../../state/discovery.dart';
import '../../state/session.dart';
import '../../ui/icons.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/focusable_card.dart';
import '../../ui/widgets/listing_card.dart';
import '../listing/connected_listing_card.dart';
import 'filter_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();

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
    }
    _searchFocus.unfocus();
  }

  void _clearSearch() {
    _search.clear();
    ref.read(discoveryProvider.notifier).clearQuery();
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
                  padding: const EdgeInsets.only(top: Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          profile == null
                              ? 'Discover'
                              : 'Salaam, ${profile.firstName}',
                          style: t.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        'What are you looking for in your community?',
                        style: t.titleMedium?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      _SearchField(
                        controller: _search,
                        focusNode: _searchFocus,
                        onSubmit: _submit,
                        onClear: _clearSearch,
                        hasQuery: state.hasQuery,
                      ),
                      const SizedBox(height: Space.md),
                      if (!state.hasQuery) ...[
                        _QuickActions(onSearch: _submit),
                        const SizedBox(height: Space.lg),
                      ],
                      const FilterBar(),
                      const SizedBox(height: Space.lg),
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onClear,
    required this.hasQuery,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function([String?]) onSubmit;
  final VoidCallback onClear;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Semantics(
        label: 'What are you looking for in your community?',
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          maxLines: 1,
          onSubmitted: (_) => onSubmit(),
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Try “robotics mentor”',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            prefixIcon: Icon(Icons.search, color: c.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.lg),
              borderSide: BorderSide(color: c.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.lg),
              borderSide: BorderSide(color: c.primary, width: 2),
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) =>
                        controller.text.isEmpty && !hasQuery
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: onClear,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  IconButton.filled(
                    tooltip: 'Search',
                    onPressed: onSubmit,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.onSearch});
  final void Function([String?]) onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.read(discoveryProvider.notifier);
    Widget action(IconData icon, String label, VoidCallback onTap) =>
        ActionChip(
          avatar: Icon(icon, size: 18),
          label: Text(label),
          onPressed: onTap,
        );
    final actions = [
      action(
        Icons.diversity_3_outlined,
        'Find a mentor',
        () => onSearch('Looking for a mentor'),
      ),
      action(
        Icons.school_outlined,
        'Explore internships',
        () => discovery.quick(types: {ListingType.internship}),
      ),
      action(
        Icons.work_outline,
        'Explore jobs',
        () => discovery.quick(types: {ListingType.job}),
      ),
      action(
        Icons.handyman_outlined,
        'Hire local help',
        () =>
            discovery.quick(types: {ListingType.service, ListingType.business}),
      ),
      action(
        Icons.volunteer_activism_outlined,
        'Volunteer',
        () => onSearch('I want to volunteer'),
      ),
      action(
        Icons.add_circle_outline,
        'Post an opportunity',
        () => context.openPost(),
      ),
    ];
    if (Breakpoints.isCompact(context)) {
      return _HorizontalStrip(children: actions);
    }
    return Wrap(spacing: Space.xs, runSpacing: Space.xs, children: actions);
  }
}

/// A single horizontally scrollable row of chips.
class _HorizontalStrip extends StatelessWidget {
  const _HorizontalStrip({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: Space.xs),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Recommendations, categories and newest listings.
class _DiscoverFeed extends ConsumerWidget {
  const _DiscoverFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(recommendationsProvider);
    final latest = ref.watch(latestListingsProvider);
    final profile = ref.watch(myProfileProvider).value;
    final filters = ref.watch(discoveryProvider.select((s) => s.filters));
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
              return EmptyState(
                compact: true,
                icon: Icons.travel_explore,
                title: filters.isEmpty
                    ? 'No recommendations yet'
                    : 'No recommendations with these filters',
                message: filters.isEmpty
                    ? 'Nothing currently matches your goals. Try a search, or check the newest listings below.'
                    : 'Clear a filter to see more of what fits you.',
                actions: [
                  if (!filters.isEmpty)
                    OutlinedButton(
                      onPressed: ref
                          .read(discoveryProvider.notifier)
                          .clearFilters,
                      child: const Text('Clear filters'),
                    ),
                ],
              );
            }
            return _ResultGrid(
              results: results.take(6).toList(),
              allowShowLess: personalizing,
            );
          },
        ),
        const SizedBox(height: Space.xl),
        if (filters.categories.isEmpty) ...[
          const SectionHeader(title: 'Browse by category'),
          const _CategoryGrid(),
          const SizedBox(height: Space.xl),
        ],
        SectionHeader(
          title: 'Newest in the community',
          subtitle: filters.isEmpty
              ? null
              : 'Filtered by your selections above.',
        ),
        AsyncView(
          value: latest,
          onRetry: () => ref.invalidate(visibleListingsProvider),
          data: (listings) => listings.isEmpty
              ? const EmptyState(
                  compact: true,
                  icon: Icons.inbox_outlined,
                  title: 'No listings match these filters',
                  message: 'Try a different area or category.',
                )
              : _ListingGrid(listings: listings.take(9).toList()),
        ),
      ],
    );
  }
}

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(categoryCountsProvider).value ?? const {};
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final categories = ListingCategory.values
        .where((cat) => (counts[cat] ?? 0) > 0)
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 600
            ? 4
            : 2;
        final width =
            (constraints.maxWidth - (columns - 1) * Space.sm) / columns;
        return Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final cat in categories)
              SizedBox(
                width: width,
                child: FocusableCard(
                  padding: const EdgeInsets.all(Space.sm),
                  onTap: () =>
                      ref.read(discoveryProvider.notifier).setCategory(cat),
                  semanticLabel: '${cat.label}, ${counts[cat]} listings',
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.primaryContainer,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Icon(
                          categoryIcon(cat),
                          size: 20,
                          color: c.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: ExcludeSemantics(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.shortLabel,
                                style: t.labelLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${counts[cat]} listing${counts[cat] == 1 ? '' : 's'}',
                                style: t.bodySmall?.copyWith(
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
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
    final results = ref.watch(visibleSearchResultsProvider);
    final all = ref.watch(searchResultsProvider).value ?? const <MatchResult>[];
    final members = ref.watch(memberMatchesProvider).value ?? const [];
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Interpretation(
          parsed: parsed,
          results: all,
          selected: state.goalIndex,
        ),
        const SizedBox(height: Space.md),
        AsyncView(
          value: results,
          onRetry: () => ref.invalidate(visibleListingsProvider),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.search_off,
                title: 'No listings match that yet',
                message:
                    'Nothing in the community matches “${state.query}”${state.filters.isEmpty ? '' : ' with these filters'}. Try fewer or different words, remove a filter, or post what you’re looking for so others can find you.',
                actions: [
                  if (!state.filters.isEmpty)
                    OutlinedButton(
                      onPressed: ref
                          .read(discoveryProvider.notifier)
                          .clearFilters,
                      child: const Text('Clear filters'),
                    ),
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

class _Interpretation extends ConsumerWidget {
  const _Interpretation({
    required this.parsed,
    required this.results,
    required this.selected,
  });
  final ParsedRequest parsed;
  final List<MatchResult> results;
  final int? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final controller = ref.read(discoveryProvider.notifier);
    final area = Areas.byId(parsed.areaId);
    final remote = switch (parsed.remote) {
      RemotePreference.remoteOk => 'Remote is fine',
      RemotePreference.remoteOnly => 'Remote only',
      RemotePreference.inPersonOnly => 'In person only',
      RemotePreference.unspecified => null,
    };
    final keywords = parsed.goals.isEmpty
        ? parsed.keywords
              .where((k) => k.weight >= 0.5)
              .map((k) => k.label)
              .toList()
        : const <String>[];

    int countFor(int i) =>
        results.where((r) => r.matchedGoal == parsed.goals[i]).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.md),
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
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              if (parsed.goals.length > 1)
                ChoiceChip(
                  label: Text('All (${results.length})'),
                  selected: selected == null,
                  onSelected: (_) => controller.selectGoal(null),
                ),
              for (var i = 0; i < parsed.goals.length; i++)
                parsed.goals.length > 1
                    ? ChoiceChip(
                        avatar: Icon(typeIcon(parsed.goals[i].type), size: 16),
                        label: Text(
                          '${parsed.goals[i].fullLabel} (${countFor(i)})',
                        ),
                        selected: selected == i,
                        onSelected: (_) => controller.selectGoal(i),
                      )
                    : Chip(
                        avatar: Icon(typeIcon(parsed.goals[i].type), size: 16),
                        label: Text(parsed.goals[i].fullLabel),
                      ),
              for (final k in keywords)
                Chip(avatar: const Icon(Icons.tag, size: 16), label: Text(k)),
              if (area != null)
                Chip(
                  avatar: const Icon(Icons.place_outlined, size: 16),
                  label: Text('Near ${area.name}'),
                ),
              if (remote != null)
                Chip(
                  avatar: const Icon(Icons.public, size: 16),
                  label: Text(remote),
                ),
              if (parsed.goals.isEmpty &&
                  keywords.isEmpty &&
                  area == null &&
                  remote == null)
                Text(
                  'Matching your words against listing titles, tags and descriptions.',
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
