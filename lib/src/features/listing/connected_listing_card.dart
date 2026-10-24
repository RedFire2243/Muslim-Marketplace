import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/errors.dart';
import '../../domain/listing.dart';
import '../../routing/router.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/listing_card.dart';

/// A listing card wired to open, save and "show less" actions.
class ConnectedListingCard extends ConsumerWidget {
  const ConnectedListingCard({
    super.key,
    required this.listing,
    required this.saved,
    required this.now,
    this.expand = false,
    this.reason,
    this.secondaryReason,
    this.allowShowLess = false,
    this.showStatus = false,
  });

  final Listing listing;
  final bool expand;
  final bool saved;
  final DateTime now;
  final String? reason;
  final String? secondaryReason;
  final bool allowShowLess;
  final bool showStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(memberProvider(listing.ownerId));
    final mine = ref.watch(currentUserIdProvider) == listing.ownerId;
    return ListingCard(
      listing: listing,
      owner: owner,
      now: now,
      expand: expand,
      saved: saved,
      reason: reason,
      secondaryReason: secondaryReason,
      showStatus: showStatus,
      onTap: () => context.openListing(listing.id),
      onToggleSave: mine
          ? null
          : () async {
              try {
                final nowSaved = await ref
                    .read(actionsProvider)
                    .toggleSave(listing);
                if (context.mounted) {
                  showMessage(
                    context,
                    nowSaved ? 'Saved' : 'Removed from saved',
                  );
                }
              } catch (e) {
                if (context.mounted) showMessage(context, friendlyError(e));
              }
            },
      onShowLess: allowShowLess
          ? () {
              ref.read(actionsProvider).dismiss(listing);
              showMessage(
                context,
                'Got it. We’ll show fewer listings like this. You can reset this in Settings.',
              );
            }
          : null,
    );
  }
}
