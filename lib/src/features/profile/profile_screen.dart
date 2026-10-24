import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/areas.dart';
import '../../domain/listing.dart';
import '../../domain/profile.dart';
import '../../state/data_providers.dart';
import '../../ui/icons.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/focusable_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final listings = ref.watch(myListingsProvider).value ?? const <Listing>[];
    return Scaffold(
      body: AsyncView(
        value: profile,
        onRetry: () => ref.invalidate(myProfileProvider),
        data: (p) => p == null
            ? const SizedBox.shrink()
            : _ProfileBody(profile: p, listings: listings),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile, required this.listings});
  final Profile profile;
  final List<Listing> listings;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final p = profile;
    final active = listings.where((l) => l.isActive).length;
    final wide = Breakpoints.isExpanded(context);

    final header = Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(name: p.displayName, id: p.id, size: 64),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(p.displayName, style: t.headlineSmall),
                    ),
                    if (p.headline.isNotEmpty)
                      Text(
                        p.headline,
                        style: t.bodyMedium?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        StatusBadge(
                          label: p.directoryVisible
                              ? 'In the directory'
                              : 'Not in the directory',
                          tone: p.directoryVisible
                              ? BadgeTone.positive
                              : BadgeTone.neutral,
                          icon: p.directoryVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        if (p.isSample) const SampleBadge(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/profile/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/profile/settings'),
                icon: const Icon(Icons.tune),
                label: const Text('Privacy and settings'),
              ),
            ],
          ),
        ],
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoBlock(
          title: 'You offer',
          text: p.offeringSummary,
          empty: 'Nothing yet',
        ),
        _InfoBlock(
          title: 'You’re looking for',
          text: p.seekingSummary,
          empty: 'Nothing yet',
        ),
        _ChipBlock(
          title: 'Goals used for matching',
          note: 'Private to you',
          items: [for (final g in p.goals) (typeIcon(g.type), g.fullLabel)],
          empty: 'Add a goal so we can recommend the right listings.',
        ),
        _ChipBlock(
          title: 'Skills',
          items: [for (final s in p.skills) (null, s)],
          empty: 'No skills added',
        ),
        _ChipBlock(
          title: 'Interests',
          items: [for (final s in p.interests) (null, s)],
          empty: 'No interests added',
        ),
        _InfoBlock(
          title: 'Area',
          text: [
            if (p.areaId != null) Areas.label(p.areaId),
            if (p.openToRemote) 'open to remote',
          ].join(', '),
          empty: 'Not specified',
        ),
        if (p.communityAffiliation != null)
          _InfoBlock(
            title: 'Community (self-reported)',
            text: p.communityAffiliation!,
            empty: '',
          ),
        if (p.linkedinUrl != null)
          _InfoBlock(title: 'LinkedIn link', text: p.linkedinUrl!, empty: ''),
      ],
    );

    final listingsCard = FocusableCard(
      onTap: () => context.go('/profile/listings'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(Icons.campaign_outlined, color: c.onPrimaryContainer),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your listings', style: t.titleSmall),
                Text(
                  listings.isEmpty
                      ? 'You haven’t posted anything yet'
                      : '$active active · ${listings.length} total',
                  style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xxl),
      children: [
        ContentWidth(
          maxWidth: 1000,
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          header,
                          const SizedBox(height: Space.md),
                          listingsCard,
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.lg),
                    Expanded(flex: 6, child: details),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: Space.md),
                    listingsCard,
                    const SizedBox(height: Space.lg),
                    details,
                  ],
                ),
        ),
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.title,
    required this.text,
    required this.empty,
  });
  final String title;
  final String text;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.labelLarge?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            text.isEmpty ? empty : text,
            style: t.bodyLarge?.copyWith(
              color: text.isEmpty ? c.onSurfaceVariant : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipBlock extends StatelessWidget {
  const _ChipBlock({
    required this.title,
    required this.items,
    required this.empty,
    this.note,
  });
  final String title;
  final List<(IconData?, String)> items;
  final String empty;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: t.labelLarge?.copyWith(color: c.onSurfaceVariant),
              ),
              if (note != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: c.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      note!,
                      style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          if (items.isEmpty)
            Text(
              empty,
              style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final (icon, label) in items)
                  Chip(
                    avatar: icon == null ? null : Icon(icon, size: 16),
                    label: Text(label),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
