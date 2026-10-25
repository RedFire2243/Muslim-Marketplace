import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/data/seed/seed_data.dart';
import 'package:muslim_marketplace/src/domain/listing.dart';
import 'package:muslim_marketplace/src/domain/taxonomy.dart';

void main() {
  final s = SeedData.build(DateTime.utc(2026, 10, 24, 12));
  final profileIds = {for (final p in s.profiles) p.id};
  final listingIds = {for (final l in s.listings) l.id};

  test('identifiers and sign-in emails are unique', () {
    expect(profileIds, hasLength(s.profiles.length));
    expect(listingIds, hasLength(s.listings.length));
    final emails = s.profiles.map(SeedData.emailFor).toSet();
    expect(emails, hasLength(s.profiles.length));
  });

  test('every listing would pass the create-listing form', () {
    for (final l in s.listings) {
      final errors = ListingDraft.fromListing(l).validate();
      expect(errors, isEmpty, reason: '${l.title}: $errors');
      expect(profileIds, contains(l.ownerId), reason: l.title);
      expect(l.tags, normalizeTags(l.tags), reason: l.title);
      if (l.type == ListingType.business) {
        expect(l.direction, ListingDirection.offer, reason: l.title);
      }
    }
  });

  test('requests, conversations and saves point at real records', () {
    final byId = {for (final l in s.listings) l.id: l};
    for (final r in s.requests) {
      expect(profileIds, containsAll([r.senderId, r.recipientId]));
      if (r.listingId case final id?) {
        expect(byId[id]?.ownerId, r.recipientId, reason: r.message);
        expect(byId[id]?.title, r.listingTitle, reason: r.message);
      }
      expect(
        r.conversationId != null,
        r.status == RequestStatus.accepted,
        reason: r.message,
      );
    }
    final conversationIds = {for (final c in s.conversations) c.id};
    for (final m in s.messages) {
      expect(conversationIds, contains(m.conversationId));
    }
    for (final x in s.saved) {
      expect(listingIds, contains(x.listingId));
      expect(profileIds, contains(x.userId));
    }
  });

  test('the demo covers every listing type and category', () {
    final active = s.listings.where((l) => l.isActive);
    expect(active.map((l) => l.type).toSet(), ListingType.values.toSet());
    expect(
      active.map((l) => l.category).toSet(),
      containsAll(
        ListingCategory.values.where((c) => c != ListingCategory.other),
      ),
    );
  });
}
