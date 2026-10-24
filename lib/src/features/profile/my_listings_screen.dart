import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/taxonomy.dart';
import '../../routing/router.dart';
import '../../state/data_providers.dart';
import '../../state/session.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/listing_card.dart';
import '../listing/connected_listing_card.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider);
    final now = ref.watch(clockProvider)();
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Your listings')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'my-listings-post',
        onPressed: () => context.openPost(),
        icon: const Icon(Icons.add),
        label: const Text('Post'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: Space.sm, bottom: 96),
        children: [
          ContentWidth(
            child: AsyncView(
              value: listings,
              onRetry: () => ref.invalidate(myListingsProvider),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'You haven’t posted anything yet',
                    message:
                        'Offer a skill or service, or ask for what you need. It takes a minute.',
                    actions: [
                      FilledButton(
                        onPressed: () => context.openPost(),
                        child: const Text('Post an opportunity'),
                      ),
                    ],
                  );
                }
                final groups = {
                  for (final s in ListingStatus.values)
                    s: list.where((l) => l.status == s).toList(),
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in ListingStatus.values)
                      if (groups[s]!.isNotEmpty) ...[
                        SectionHeader(
                          title: switch (s) {
                            ListingStatus.active => 'Active',
                            ListingStatus.paused => 'Paused',
                            ListingStatus.closed => 'Closed',
                          },
                          subtitle: switch (s) {
                            ListingStatus.active =>
                              'Visible to members and open to requests',
                            ListingStatus.paused =>
                              'Hidden from discovery until you resume',
                            ListingStatus.closed => 'No longer available',
                          },
                        ),
                        CardGrid(
                          itemCount: groups[s]!.length,
                          itemBuilder: (context, i, expand) =>
                              ConnectedListingCard(
                                listing: groups[s]![i],
                                saved: false,
                                now: now,
                                expand: expand,
                                showStatus: true,
                              ),
                        ),
                        const SizedBox(height: Space.lg),
                      ],
                    Text(
                      'Open a listing to edit, pause, close or delete it.',
                      style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
