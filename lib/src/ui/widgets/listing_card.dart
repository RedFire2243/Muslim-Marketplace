import 'package:flutter/material.dart';

import '../../domain/listing.dart';
import '../../domain/profile.dart';
import '../../domain/taxonomy.dart';
import '../icons.dart';
import '../theme.dart';
import 'common.dart';
import 'focusable_card.dart';

/// Type and role in one pill: "Mentorship · Offering mentorship". Offers and
/// requests differ by icon and wording as well as color.
class DirectionPill extends StatelessWidget {
  const DirectionPill({super.key, required this.type, required this.direction});

  final ListingType type;
  final ListingDirection direction;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final isOffer = direction == ListingDirection.offer;
    final bg = isOffer ? c.primaryContainer : c.secondaryContainer;
    final fg = isOffer ? c.onPrimaryContainer : c.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(typeIcon(type), size: 15, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              type.directionLabel(direction),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class SaveButton extends StatelessWidget {
  const SaveButton({
    super.key,
    required this.saved,
    required this.onPressed,
    this.busy = false,
  });

  final bool saved;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: saved ? 'Remove from saved' : 'Save',
      isSelected: saved,
      onPressed: busy ? null : onPressed,
      icon: Icon(Icons.bookmark_add_outlined, color: c.onSurfaceVariant),
      selectedIcon: Icon(Icons.bookmark_added, color: c.primary),
    );
  }
}

/// A listing summary with its role, place, pay, owner and, when present, the
/// reason it was recommended.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.now,
    this.owner,
    this.saved = false,
    this.onToggleSave,
    this.onTap,
    this.reason,
    this.secondaryReason,
    this.onShowLess,
    this.expand = false,
    this.showStatus = false,
  });

  final Listing listing;
  final DateTime now;
  final MemberProfile? owner;
  final bool saved;
  final VoidCallback? onToggleSave;
  final VoidCallback? onTap;
  final String? reason;
  final String? secondaryReason;
  final VoidCallback? onShowLess;

  /// Fill the available height (used in equal-height grid rows).
  final bool expand;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final comp = listing.compensationLabel;
    final ownerName = owner?.displayName ?? 'Community member';

    // Wraps instead of overflowing when text is enlarged.
    final footer = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MemberAvatar(name: ownerName, id: listing.ownerId, size: 26),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Wrap(
            spacing: Space.xs,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                ownerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelMedium?.copyWith(color: c.onSurfaceVariant),
              ),
              if (listing.isSample) const SampleBadge(),
              Text(
                relativeTime(listing.createdAt, now),
                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );

    return FocusableCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.sm,
        Space.xs,
        Space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DirectionPill(
                      type: listing.type,
                      direction: listing.direction,
                    ),
                    if (showStatus && !listing.isActive)
                      StatusBadge.listing(listing.status),
                  ],
                ),
              ),
              if (onShowLess != null)
                IconButton(
                  tooltip: 'Show less like this',
                  onPressed: onShowLess,
                  icon: Icon(
                    Icons.visibility_off_outlined,
                    size: 20,
                    color: c.onSurfaceVariant,
                  ),
                ),
              if (onToggleSave != null)
                SaveButton(saved: saved, onPressed: onToggleSave),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: Space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Space.xxs),
                Text(
                  listing.title,
                  style: t.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Space.xxs),
                Text(
                  listing.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.md,
                  runSpacing: Space.xxs,
                  children: [
                    MetaLine(
                      icon: listing.areaId == null && listing.remoteAvailable
                          ? Icons.public
                          : Icons.place_outlined,
                      text: listing.locationLabel,
                    ),
                    if (comp != null)
                      MetaLine(icon: Icons.payments_outlined, text: comp),
                    MetaLine(
                      icon: categoryIcon(listing.category),
                      text: listing.category.shortLabel,
                    ),
                  ],
                ),
                if (reason != null) ...[
                  const SizedBox(height: Space.sm),
                  _ReasonBox(reason: reason!, secondary: secondaryReason),
                ],
              ],
            ),
          ),
          if (expand) const Spacer() else const SizedBox(height: Space.sm),
          if (expand) const SizedBox(height: Space.sm),
          Padding(
            padding: const EdgeInsets.only(right: Space.xs),
            child: footer,
          ),
        ],
      ),
    );
  }
}

class _ReasonBox extends StatelessWidget {
  const _ReasonBox({required this.reason, this.secondary});
  final String reason;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.auto_awesome_outlined,
              size: 16,
              color: c.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: reason,
                    style: t.labelMedium?.copyWith(color: c.onPrimaryContainer),
                  ),
                  if (secondary != null)
                    TextSpan(
                      text: ' · $secondary',
                      style: t.bodySmall?.copyWith(
                        color: c.onPrimaryContainer.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays cards out in equal-height rows: one column on phones, two on
/// tablets, three on wide screens.
class CardGrid extends StatelessWidget {
  const CardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxColumns = 3,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index, bool expand)
  itemBuilder;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final columns =
            (w >= 980
                    ? 3
                    : w >= 620
                    ? 2
                    : 1)
                .clamp(1, maxColumns);
        if (columns == 1) {
          return Column(
            children: [
              for (var i = 0; i < itemCount; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: itemBuilder(context, i, false),
                ),
            ],
          );
        }
        final rows = <Widget>[];
        for (var start = 0; start < itemCount; start += columns) {
          final cells = <Widget>[];
          for (var j = 0; j < columns; j++) {
            final i = start + j;
            if (j > 0) cells.add(const SizedBox(width: Space.sm));
            cells.add(
              Expanded(
                child: i < itemCount
                    ? itemBuilder(context, i, true)
                    : const SizedBox(),
              ),
            );
          }
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: cells,
                ),
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}
