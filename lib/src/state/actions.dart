import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../domain/activity.dart';
import '../domain/connections.dart';
import '../domain/listing.dart';
import '../domain/profile.dart';
import '../domain/taxonomy.dart';
import 'data_providers.dart';

/// User actions that change data. Each validates on the backend (which
/// enforces ownership and participation) and records the matching feedback
/// event where one is defined.
class MarketplaceActions {
  MarketplaceActions(this.ref);
  final Ref ref;

  MarketplaceBackend get _b {
    final b = ref.read(backendProvider);
    if (b == null) throw StateError('Signed out');
    return b;
  }

  ActivityRecorder get _activity => ref.read(activityRecorderProvider);

  /// Returns the new saved state.
  Future<bool> toggleSave(Listing listing) async {
    final saved = ref.read(savedIdsProvider).contains(listing.id);
    if (saved) {
      await _b.saved.unsave(listing.id);
      _activity.record(ActivityType.unsaved, listing);
      return false;
    }
    await _b.saved.save(listing.id);
    _activity.record(ActivityType.saved, listing);
    return true;
  }

  Future<void> unsave(String listingId) => _b.saved.unsave(listingId);

  /// "Show less like this".
  void dismiss(Listing listing) =>
      _activity.record(ActivityType.dismissed, listing);

  void viewed(Listing listing) =>
      _activity.record(ActivityType.viewed, listing);

  Future<ConnectionRequest> sendRequest({
    required String recipientId,
    Listing? listing,
    required String message,
  }) async {
    final r = await _b.connections.send(
      recipientId: recipientId,
      listingId: listing?.id,
      message: message,
    );
    if (listing != null) {
      _activity.record(ActivityType.contactRequested, listing);
    }
    return r;
  }

  Future<ConnectionRequest> respond(String requestId, {required bool accept}) =>
      _b.connections.respond(requestId, accept: accept);

  Future<ConnectionRequest> withdraw(String requestId) =>
      _b.connections.withdraw(requestId);

  Future<Listing> createListing(ListingDraft draft) =>
      _b.listings.create(draft);

  Future<Listing> updateListing(String id, ListingDraft draft) =>
      _b.listings.update(id, draft);

  Future<Listing> setListingStatus(String id, ListingStatus status) =>
      _b.listings.setStatus(id, status);

  Future<void> deleteListing(String id) => _b.listings.delete(id);

  Future<Profile> saveProfile(ProfileDraft draft) =>
      _b.profiles.saveMine(draft);

  Future<Profile> setDirectoryVisible(bool value) =>
      _b.profiles.updateSettings(directoryVisible: value);

  Future<Profile> setPersonalization(bool value) =>
      _b.profiles.updateSettings(personalizationEnabled: value);

  Future<void> resetPersonalization() => _b.activity.reset();
}

final actionsProvider = Provider<MarketplaceActions>(MarketplaceActions.new);
