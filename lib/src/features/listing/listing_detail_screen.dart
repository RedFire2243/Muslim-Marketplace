import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/errors.dart';
import '../../domain/areas.dart';
import '../../domain/connections.dart';
import '../../domain/listing.dart';
import '../../domain/profile.dart';
import '../../domain/taxonomy.dart';
import '../../matching/matcher.dart';
import '../../routing/router.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../state/discovery.dart';
import '../../state/session.dart';
import '../../ui/icons.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/listing_card.dart';
import 'request_sheet.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});
  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _recordedView = false;
  bool _busy = false;

  void _recordView(Listing l) {
    if (_recordedView) return;
    _recordedView = true;
    if (l.ownerId == ref.read(currentUserIdProvider) || !l.isActive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(actionsProvider).viewed(l);
    });
  }

  Future<void> _guard(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && success != null) showMessage(context, success);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSave(Listing l) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final nowSaved = await ref.read(actionsProvider).toggleSave(l);
      if (!mounted) return;
      showMessage(context, nowSaved ? 'Saved' : 'Removed from saved');
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(Listing l, ListingStatus status) async {
    if (status == ListingStatus.closed) {
      final ok = await confirmAction(
        context,
        title: 'Close this listing?',
        message:
            'It will leave discovery and stop accepting requests. Existing conversations stay open. Closed listings can’t be reopened.',
        confirmLabel: 'Close listing',
      );
      if (!ok) return;
    }
    await _guard(
      () => ref.read(actionsProvider).setListingStatus(l.id, status),
      success: switch (status) {
        ListingStatus.active => 'Listing is visible again',
        ListingStatus.paused => 'Listing paused and hidden from discovery',
        ListingStatus.closed => 'Listing closed',
      },
    );
  }

  Future<void> _delete(Listing l) async {
    final ok = await confirmAction(
      context,
      title: 'Delete this listing?',
      message:
          'This permanently removes it, including from other members’ saved lists. Requests and conversations keep its title.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final router = GoRouter.of(context);
    await _guard(() async {
      await ref.read(actionsProvider).deleteListing(l.id);
      if (router.canPop()) router.pop();
    }, success: 'Listing deleted');
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(listingByIdProvider(widget.listingId));
    final me = ref.watch(currentUserIdProvider);

    return listingAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const ContentWidth(child: LoadingBlocks(count: 2, height: 200)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          error: e,
          onRetry: () => ref.invalidate(listingByIdProvider(widget.listingId)),
        ),
      ),
      data: (listing) {
        if (listing == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.link_off,
              title: 'This listing isn’t available',
              message:
                  'It may have been removed, paused or closed by its owner.',
              actions: [
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to Discover'),
                ),
              ],
            ),
          );
        }
        _recordView(listing);
        final isOwner = listing.ownerId == me;
        return _buildPage(context, listing, isOwner);
      },
    );
  }

  Widget _buildPage(BuildContext context, Listing listing, bool isOwner) {
    final saved = ref.watch(savedIdsProvider).contains(listing.id);
    final owner = ref.watch(memberProvider(listing.ownerId));
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    final personalization =
        ref.watch(myProfileProvider).value?.personalizationEnabled ?? false;

    final actionPanel = _ActionPanel(
      listing: listing,
      isOwner: isOwner,
      saved: saved,
      busy: _busy,
      ownerName: owner?.displayName ?? 'the owner',
      onToggleSave: () => _toggleSave(listing),
      onSetStatus: (s) => _setStatus(listing, s),
      onDelete: () => _delete(listing),
    );
    final ownerCard = _OwnerCard(
      listing: listing,
      owner: owner,
      isOwner: isOwner,
    );
    Widget main(_Part part) => _MainColumn(
      listing: listing,
      showMatch: !isOwner,
      isOwner: isOwner,
      part: part,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing'),
        actions: [
          if (!isOwner && listing.isActive)
            SaveButton(
              saved: saved,
              busy: _busy,
              onPressed: () => _toggleSave(listing),
            ),
          if (!isOwner && personalization)
            PopupMenuButton<String>(
              tooltip: 'More options',
              onSelected: (_) {
                ref.read(actionsProvider).dismiss(listing);
                showMessage(context, 'We’ll show fewer listings like this.');
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'less',
                  child: ListTile(
                    leading: Icon(Icons.visibility_off_outlined),
                    title: Text('Show less like this'),
                  ),
                ),
              ],
            ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xxl),
        child: ContentWidth(
          maxWidth: 1080,
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: main(_Part.all)),
                    const SizedBox(width: Space.xl),
                    SizedBox(
                      width: 340,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          actionPanel,
                          const SizedBox(height: Space.md),
                          ownerCard,
                        ],
                      ),
                    ),
                  ],
                )
              // Narrow screens: the primary action sits right under the title.
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    main(_Part.header),
                    const SizedBox(height: Space.md),
                    actionPanel,
                    const SizedBox(height: Space.lg),
                    main(_Part.body),
                    const SizedBox(height: Space.lg),
                    ownerCard,
                  ],
                ),
        ),
      ),
    );
  }
}

enum _Part { header, body, all }

class _MainColumn extends ConsumerWidget {
  const _MainColumn({
    required this.listing,
    required this.showMatch,
    required this.isOwner,
    this.part = _Part.all,
  });
  final Listing listing;
  final bool showMatch;
  final bool isOwner;
  final _Part part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)();
    final comp = listing.compensationLabel;
    final match = showMatch && listing.isActive
        ? ref.watch(listingMatchProvider(listing.id)).value
        : null;

    final showHeader = part != _Part.body;
    final showBody = part != _Part.header;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          if (!listing.isActive) ...[
            _StatusBanner(status: listing.status),
            const SizedBox(height: Space.md),
          ],
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DirectionPill(type: listing.type, direction: listing.direction),
              if (listing.isSample) const SampleBadge(),
            ],
          ),
          const SizedBox(height: Space.sm),
          Semantics(
            header: true,
            child: Text(listing.title, style: t.headlineSmall),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.lg,
            runSpacing: Space.xs,
            children: [
              MetaLine(icon: Icons.place_outlined, text: listing.locationLabel),
              if (comp != null)
                MetaLine(icon: Icons.payments_outlined, text: comp),
              MetaLine(
                icon: categoryIcon(listing.category),
                text: listing.category.label,
              ),
              MetaLine(
                icon: Icons.schedule,
                text:
                    'Posted ${relativeTime(listing.createdAt, now).toLowerCase()}',
              ),
            ],
          ),
        ],
        if (showBody) ...[
          if (showHeader) const SizedBox(height: Space.lg),
          SelectableText(listing.description, style: t.bodyLarge),
          if (listing.tags.isNotEmpty) ...[
            const SizedBox(height: Space.lg),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final tag in listing.tags) Chip(label: Text(tag)),
              ],
            ),
          ],
          if (match != null) ...[
            const SizedBox(height: Space.lg),
            _WhyItFits(result: match),
          ],
          const SizedBox(height: Space.lg),
          _Details(listing: listing, isOwner: isOwner),
        ],
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final ListingStatus status;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final text = switch (status) {
      ListingStatus.paused =>
        'Paused by its owner. It’s hidden from discovery and not accepting new requests.',
      ListingStatus.closed =>
        'This listing is closed and no longer accepting requests.',
      ListingStatus.active => '',
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: c.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            StatusBadge.listing(status),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(text, style: t.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.listing, required this.isOwner});
  final Listing listing;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: t.labelMedium?.copyWith(color: c.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: t.bodyMedium)),
        ],
      ),
    );
    final area = Areas.byId(listing.areaId);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Column(
        children: [
          row(
            'Kind',
            '${listing.type.label} · ${listing.direction.label.toLowerCase()}',
          ),
          row(
            'What it means',
            isOwner
                ? listing.type.directionHelp(listing.direction)
                : listing.type.directionMeaning(listing.direction),
          ),
          row('In person', area?.name ?? 'No'),
          row('Remote', listing.remoteAvailable ? 'Yes' : 'No'),
          row('Compensation', listing.compensationLabel ?? 'Not specified'),
          row('Status', listing.status.label),
          row(
            'Last updated',
            DateFormat.yMMMd().format(listing.updatedAt.toLocal()),
          ),
        ],
      ),
    );
  }
}

class _WhyItFits extends StatelessWidget {
  const _WhyItFits({required this.result});
  final MatchResult result;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    // A Material (not a decorated box) so the expansion tile's ink shows.
    return Material(
      color: Color.alphaBlend(
        c.primaryContainer.withValues(alpha: 0.35),
        c.surface,
      ),
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: c.primary),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text('Why this might fit you', style: t.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            for (final r in result.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check, size: 18, color: c.primary),
                    const SizedBox(width: Space.xs),
                    Expanded(child: Text(r.text, style: t.bodyMedium)),
                  ],
                ),
              ),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: Space.xs),
                title: Text('How this was ranked', style: t.labelLarge),
                subtitle: Text(
                  'Overall fit ${(result.score * 100).round()}%',
                  style: t.bodySmall,
                ),
                children: [
                  for (final f in MatchFactor.values)
                    _FactorRow(factor: f, value: result.factors[f]),
                  const SizedBox(height: Space.xs),
                  Text(
                    'Signals we don’t have are left out rather than guessed. Weights are a starting design, not a trained model.',
                    style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor, required this.value});
  final MatchFactor factor;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final weight = (MatchWeights.defaults.of(factor) * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text('${factor.label} ($weight%)', style: t.bodySmall),
          ),
          Expanded(
            child: value == null
                ? Text(
                    'Not used',
                    style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: c.surfaceContainerHigh,
                      semanticsLabel: factor.label,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends ConsumerWidget {
  const _ActionPanel({
    required this.listing,
    required this.isOwner,
    required this.saved,
    required this.busy,
    required this.ownerName,
    required this.onToggleSave,
    required this.onSetStatus,
    required this.onDelete,
  });

  final Listing listing;
  final bool isOwner;
  final bool saved;
  final bool busy;
  final String ownerName;
  final VoidCallback onToggleSave;
  final ValueChanged<ListingStatus> onSetStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final me = ref.watch(currentUserIdProvider);
    final requests =
        ref.watch(requestsProvider).value ?? const <ConnectionRequest>[];

    final card = BoxDecoration(
      color: c.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: c.outlineVariant),
    );

    if (isOwner) {
      final incoming = requests
          .where((r) => r.listingId == listing.id && r.recipientId == me)
          .toList();
      final pending = incoming
          .where((r) => r.status == RequestStatus.pending)
          .length;
      return Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Your listing', style: t.titleMedium),
                const Spacer(),
                StatusBadge.listing(listing.status),
              ],
            ),
            const SizedBox(height: Space.xxs),
            Text(
              incoming.isEmpty
                  ? 'No requests yet.'
                  : '${incoming.length} request${incoming.length == 1 ? '' : 's'}${pending > 0 ? ', $pending waiting for you' : ''}.',
              style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: Space.md),
            if (listing.status != ListingStatus.closed)
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => context.openListingEditor(listing.id),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit listing'),
              ),
            if (incoming.isNotEmpty) ...[
              const SizedBox(height: Space.xs),
              OutlinedButton.icon(
                onPressed: () => context.go('/inbox'),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('See requests'),
              ),
            ],
            const SizedBox(height: Space.xs),
            if (listing.status == ListingStatus.active)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => onSetStatus(ListingStatus.paused),
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('Pause'),
              ),
            if (listing.status == ListingStatus.paused)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => onSetStatus(ListingStatus.active),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Resume'),
              ),
            if (listing.status != ListingStatus.closed) ...[
              const SizedBox(height: Space.xs),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => onSetStatus(ListingStatus.closed),
                icon: const Icon(Icons.do_not_disturb_on_outlined),
                label: const Text('Close listing'),
              ),
            ],
            const SizedBox(height: Space.xs),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: c.error),
              onPressed: busy ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
      );
    }

    final mine =
        requests
            .where((r) => r.listingId == listing.id && r.senderId == me)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = mine.isEmpty ? null : mine.first;

    Widget primary;
    String caption;
    if (latest != null &&
        latest.status == RequestStatus.accepted &&
        latest.conversationId != null) {
      primary = FilledButton.icon(
        onPressed: () => context.openConversation(latest.conversationId!),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Open conversation'),
      );
      caption = '${ownerName.split(' ').first} accepted your request.';
    } else if (latest != null && latest.status == RequestStatus.pending) {
      primary = FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.schedule),
        label: const Text('Request pending'),
      );
      caption =
          'Sent ${relativeTime(latest.createdAt, ref.watch(clockProvider)()).toLowerCase()}. You’ll see their answer in your inbox.';
    } else if (latest != null && latest.status == RequestStatus.declined) {
      primary = FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.block),
        label: const Text('Request declined'),
      );
      caption =
          'They weren’t able to take this on. Keep exploring similar listings.';
    } else if (!listing.isActive) {
      primary = FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.lock_outline),
        label: const Text('Not accepting requests'),
      );
      caption = 'This listing is ${listing.status.label.toLowerCase()}.';
    } else {
      primary = FilledButton.icon(
        onPressed: busy
            ? null
            : () async {
                final sent = await showRequestSheet(
                  context,
                  recipientId: listing.ownerId,
                  recipientName: ownerName,
                  listing: listing,
                );
                if (context.mounted) confirmRequestSent(context, sent);
              },
        icon: const Icon(Icons.waving_hand_outlined),
        label: const Text('Request to connect'),
      );
      caption =
          'Introduce yourself. If ${ownerName.split(' ').first} accepts, you can message privately.';
    }

    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          const SizedBox(height: Space.xs),
          Text(
            caption,
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (latest != null && latest.status == RequestStatus.pending) ...[
            const SizedBox(height: Space.xs),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      try {
                        await ref.read(actionsProvider).withdraw(latest.id);
                        if (context.mounted) {
                          showMessage(context, 'Request withdrawn');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showMessage(context, friendlyError(e));
                        }
                      }
                    },
              child: const Text('Withdraw request'),
            ),
          ],
          if (listing.isActive) ...[
            const SizedBox(height: Space.sm),
            OutlinedButton.icon(
              onPressed: busy ? null : onToggleSave,
              icon: Icon(
                saved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
              ),
              label: Text(saved ? 'Saved' : 'Save for later'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OwnerCard extends ConsumerWidget {
  const _OwnerCard({
    required this.listing,
    required this.owner,
    required this.isOwner,
  });
  final Listing listing;
  final MemberProfile? owner;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final name = owner?.displayName ?? 'Community member';
    final details = owner?.details;
    final isDemo = ref.watch(sessionProvider).value?.isDemo ?? false;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isOwner ? 'Posted by you' : 'Posted by',
            style: t.labelMedium?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              MemberAvatar(name: name, id: listing.ownerId, size: 44),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: t.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (owner?.isSample ?? false) ...[
                          const SizedBox(width: 6),
                          const SampleBadge(),
                        ],
                      ],
                    ),
                    if (details != null && details.headline.isNotEmpty)
                      Text(
                        details.headline,
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (details == null)
            Text(
              isOwner
                  ? 'You’re not in the member directory, so others see only your name.'
                  : 'This member keeps their profile details private.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            )
          else ...[
            if (details.areaId != null)
              MetaLine(
                icon: Icons.place_outlined,
                text: Areas.label(details.areaId),
              ),
            if (details.communityAffiliation != null) ...[
              const SizedBox(height: 4),
              MetaLine(
                icon: Icons.mosque_outlined,
                text: '${details.communityAffiliation} (self-reported)',
                maxLines: 2,
              ),
            ],
            if (details.linkedinUrl != null) ...[
              const SizedBox(height: Space.xs),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => launchUrl(
                  Uri.parse(details.linkedinUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('LinkedIn profile'),
              ),
            ],
            if (!isOwner) ...[
              const SizedBox(height: Space.xs),
              OutlinedButton(
                onPressed: () => context.openMember(listing.ownerId),
                child: const Text('View profile'),
              ),
            ],
          ],
          if (listing.isSample && isDemo) ...[
            const SizedBox(height: Space.sm),
            Text(
              'Fictional member created for the demo.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
