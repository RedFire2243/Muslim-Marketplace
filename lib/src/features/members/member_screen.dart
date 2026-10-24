import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/areas.dart';
import '../../domain/connections.dart';
import '../../state/data_providers.dart';
import '../../state/session.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/listing_card.dart';
import '../listing/connected_listing_card.dart';
import '../listing/request_sheet.dart';

/// A directory member's public profile. Members who have not opted in are
/// not shown.
class MemberScreen extends ConsumerWidget {
  const MemberScreen({super.key, required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directory = ref.watch(directoryProvider);
    final listings = ref.watch(visibleListingsProvider).value ?? const [];
    final requests =
        ref.watch(requestsProvider).value ?? const <ConnectionRequest>[];
    final me = ref.watch(currentUserIdProvider);
    final saved = ref.watch(savedIdsProvider);
    final now = ref.watch(clockProvider)();
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Member')),
      body: AsyncView(
        value: directory,
        onRetry: () => ref.invalidate(directoryProvider),
        data: (members) {
          final m = members.where((x) => x.id == memberId).firstOrNull;
          final d = m?.details;
          if (m == null || d == null) {
            return const EmptyState(
              icon: Icons.visibility_off_outlined,
              title: 'This profile isn’t in the directory',
              message:
                  'The member may have chosen to keep their profile private.',
            );
          }
          final theirs = listings
              .where((l) => l.ownerId == m.id && l.isActive)
              .toList();
          final open = requests.any(
            (r) =>
                r.senderId == me &&
                r.recipientId == m.id &&
                r.listingId == null &&
                r.status.isOpen,
          );
          return ListView(
            padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xxl),
            children: [
              ContentWidth(
                maxWidth: 900,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MemberAvatar(name: m.displayName, id: m.id, size: 64),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Semantics(
                                      header: true,
                                      child: Text(
                                        m.displayName,
                                        style: t.headlineSmall,
                                      ),
                                    ),
                                  ),
                                  if (m.isSample) ...[
                                    const SizedBox(width: Space.xs),
                                    const SampleBadge(),
                                  ],
                                ],
                              ),
                              if (d.headline.isNotEmpty)
                                Text(
                                  d.headline,
                                  style: t.bodyMedium?.copyWith(
                                    color: c.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    Wrap(
                      spacing: Space.lg,
                      runSpacing: Space.xs,
                      children: [
                        if (d.areaId != null)
                          MetaLine(
                            icon: Icons.place_outlined,
                            text: Areas.label(d.areaId),
                          ),
                        if (d.communityAffiliation != null)
                          MetaLine(
                            icon: Icons.mosque_outlined,
                            text: '${d.communityAffiliation} (self-reported)',
                            maxLines: 2,
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: open
                              ? null
                              : () async {
                                  final sent = await showRequestSheet(
                                    context,
                                    recipientId: m.id,
                                    recipientName: m.displayName,
                                  );
                                  if (context.mounted) {
                                    confirmRequestSent(context, sent);
                                  }
                                },
                          icon: Icon(
                            open ? Icons.schedule : Icons.waving_hand_outlined,
                          ),
                          label: Text(
                            open ? 'Request sent' : 'Request to connect',
                          ),
                        ),
                        if (d.linkedinUrl != null)
                          OutlinedButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(d.linkedinUrl!),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('LinkedIn'),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    if (d.offeringSummary.isNotEmpty) ...[
                      Text(
                        'Offers',
                        style: t.labelLarge?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                      Text(d.offeringSummary, style: t.bodyLarge),
                      const SizedBox(height: Space.md),
                    ],
                    if (d.seekingSummary.isNotEmpty) ...[
                      Text(
                        'Looking for',
                        style: t.labelLarge?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                      Text(d.seekingSummary, style: t.bodyLarge),
                      const SizedBox(height: Space.md),
                    ],
                    if (d.skills.isNotEmpty || d.interests.isNotEmpty)
                      Wrap(
                        spacing: Space.xs,
                        runSpacing: Space.xs,
                        children: [
                          for (final s in d.skills) Chip(label: Text(s)),
                          for (final s in d.interests)
                            Chip(
                              avatar: const Icon(
                                Icons.favorite_outline,
                                size: 14,
                              ),
                              label: Text(s),
                            ),
                        ],
                      ),
                    const SizedBox(height: Space.xl),
                    SectionHeader(
                      title: 'Listings by ${m.displayName.split(' ').first}',
                    ),
                    if (theirs.isEmpty)
                      Text(
                        'No active listings right now.',
                        style: t.bodyMedium?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      )
                    else
                      CardGrid(
                        itemCount: theirs.length,
                        maxColumns: 2,
                        itemBuilder: (context, i, expand) =>
                            ConnectedListingCard(
                              listing: theirs[i],
                              saved: saved.contains(theirs[i].id),
                              now: now,
                              expand: expand,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
