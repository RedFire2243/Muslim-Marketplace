import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/errors.dart';
import '../../domain/listing.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../state/session.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/listing_card.dart';
import '../listing/connected_listing_card.dart';

final _savedListingsResolvedProvider = FutureProvider<List<(Listing?, String)>>(
  (ref) async {
    final saved = await ref.watch(savedListingsProvider.future);
    final visible = await ref.watch(visibleListingsProvider.future);
    final byId = {for (final l in visible) l.id: l};
    return [for (final s in saved) (byId[s.listingId], s.listingId)];
  },
);

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_savedListingsResolvedProvider);
    final now = ref.watch(clockProvider)();
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.only(top: Space.lg, bottom: Space.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Saved', style: t.headlineMedium),
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      'Listings you’ve kept for later. Only you can see this list.',
                      style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentWidth(
              child: AsyncView(
                value: items,
                onRetry: () => ref.invalidate(savedListingsProvider),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.bookmarks_outlined,
                      title: 'Nothing saved yet',
                      message:
                          'Tap the bookmark on any listing to keep it here. Saving also helps us recommend similar listings.',
                      actions: [
                        FilledButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Discover listings'),
                        ),
                      ],
                    );
                  }
                  final available = [for (final (l, _) in list) ?l];
                  final missing = [
                    for (final (l, id) in list)
                      if (l == null) id,
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardGrid(
                        itemCount: available.length,
                        itemBuilder: (context, i, expand) =>
                            ConnectedListingCard(
                              listing: available[i],
                              saved: true,
                              now: now,
                              expand: expand,
                              showStatus: true,
                            ),
                      ),
                      for (final id in missing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: _Unavailable(listingId: id),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
        ],
      ),
    );
  }
}

/// A saved listing that is no longer visible (paused or closed by another
/// member, or removed).
class _Unavailable extends ConsumerWidget {
  const _Unavailable({required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.link_off, color: c.onSurfaceVariant),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              'A saved listing is no longer available.',
              style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(actionsProvider).unsave(listingId);
              } catch (e) {
                if (context.mounted) showMessage(context, friendlyError(e));
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
