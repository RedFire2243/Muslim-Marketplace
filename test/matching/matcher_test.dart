import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/data/seed/seed_data.dart';
import 'package:muslim_marketplace/src/domain/activity.dart';
import 'package:muslim_marketplace/src/domain/goal.dart';
import 'package:muslim_marketplace/src/domain/listing.dart';
import 'package:muslim_marketplace/src/domain/profile.dart';
import 'package:muslim_marketplace/src/domain/taxonomy.dart';
import 'package:muslim_marketplace/src/matching/intent_parser.dart';
import 'package:muslim_marketplace/src/matching/matcher.dart';
import 'package:muslim_marketplace/src/matching/preference_model.dart';

final now = DateTime.utc(2026, 10, 24, 12);
final seed = SeedData.build(now);
const parser = DeterministicParser();
const matcher = ListingMatcher();

Listing listing(int n) =>
    seed.listings.firstWhere((l) => l.id == SeedIds.listing(n));
Profile profile(String id) => seed.profiles.firstWhere((p) => p.id == id);

Profile newMember({
  List<Goal> goals = const [],
  List<String> skills = const [],
  List<String> interests = const [],
  String? area,
  bool remote = true,
  bool personalization = true,
}) => Profile(
  id: 'viewer',
  displayName: 'Viewer',
  goals: goals,
  skills: skills,
  interests: interests,
  areaId: area,
  openToRemote: remote,
  personalizationEnabled: personalization,
  onboardingComplete: true,
  createdAt: now,
  updatedAt: now,
);

List<MatchResult> search(
  String text, {
  Profile? viewer,
  MatchFilters filters = MatchFilters.none,
}) => matcher.rank(
  seed.listings,
  MatchRequest(parsed: parser.parseSearch(text), filters: filters),
  MatchContext(now: now, viewerId: viewer?.id ?? 'viewer', profile: viewer),
);

List<String> ids(List<MatchResult> r) => [for (final x in r) x.listing.id];

void main() {
  group('role compatibility', () {
    test(
      'engineering student finds a mentor and internships, not other seekers',
      () {
        final r = search(
          "I'm an engineering student looking for a robotics mentor and a summer internship near New Brunswick.",
        );
        final found = ids(r);
        // Relevant existing listings for both intents.
        expect(
          found,
          contains(SeedIds.listing(1)),
        ); // Robotics mentorship offer
        expect(found, contains(SeedIds.listing(12))); // Engineering internship
        expect(
          found,
          contains(SeedIds.listing(11)),
        ); // Software engineering internship
        // Someone else seeking a mentor or an internship is not a result.
        expect(found, isNot(contains(SeedIds.listing(6))));
        expect(found, isNot(contains(SeedIds.listing(14))));
        // A group seeking a volunteer mentor does not mentor the student.
        expect(found, isNot(contains(SeedIds.listing(7))));
        // Both intents are represented and explained.
        final goals = {for (final x in r) x.matchedGoal?.type};
        expect(
          goals,
          containsAll([ListingType.mentorship, ListingType.internship]),
        );
        final mentor = r.firstWhere((x) => x.listing.id == SeedIds.listing(1));
        expect(
          mentor.reasons.map((e) => e.text),
          contains('Offers mentorship, which you’re looking for'),
        );
        expect(
          mentor.reasons.map((e) => e.text).join(' '),
          contains('robotics'),
        );
        // The best internship for this request is the local engineering one.
        final internships = r
            .where((x) => x.matchedGoal?.type == ListingType.internship)
            .toList();
        expect(internships.first.listing.id, SeedIds.listing(12));
      },
    );

    test(
      'someone offering mentorship sees mentees and volunteer mentor roles',
      () {
        final yusuf = profile(SeedIds.yusuf);
        final r = matcher.rank(
          seed.listings,
          const MatchRequest(mode: MatchMode.recommendations),
          MatchContext(now: now, viewerId: yusuf.id, profile: yusuf),
        );
        final found = ids(r);
        expect(
          found,
          contains(SeedIds.listing(6)),
        ); // student seeking a robotics mentor
        expect(
          found,
          contains(SeedIds.listing(7)),
        ); // volunteer robotics mentor needed
        expect(found, isNot(contains(SeedIds.listing(1)))); // own listing
        expect(
          found,
          isNot(contains(SeedIds.listing(2))),
        ); // another mentor's offer
        expect(
          found.indexOf(SeedIds.listing(6)),
          lessThan(found.indexOf(SeedIds.listing(7))),
        );
      },
    );

    test('hiring a tutor matches tutors, not another family needing one', () {
      final r = search('I need a calculus tutor');
      expect(ids(r).first, SeedIds.listing(21));
      expect(ids(r), isNot(contains(SeedIds.listing(23))));
    });

    test('a tutor offering help matches people who need tutoring', () {
      final r = search('I can tutor calculus');
      expect(ids(r), contains(SeedIds.listing(23)));
      expect(ids(r), isNot(contains(SeedIds.listing(21))));
    });

    test('collaboration is reciprocal', () {
      final r = search('looking for teammates for a hackathon');
      expect(ids(r), contains(SeedIds.listing(32)));
    });

    test('compatibility table', () {
      const seekMentor = Goal(
        type: ListingType.mentorship,
        role: GoalRole.seeking,
      );
      const offerMentor = Goal(
        type: ListingType.mentorship,
        role: GoalRole.offering,
      );
      expect(ListingMatcher.compatibility(seekMentor, listing(1)), 1.0);
      expect(ListingMatcher.compatibility(seekMentor, listing(6)), 0.0);
      expect(ListingMatcher.compatibility(seekMentor, listing(7)), 0.0);
      expect(ListingMatcher.compatibility(offerMentor, listing(6)), 1.0);
      expect(ListingMatcher.compatibility(offerMentor, listing(7)), 0.6);
    });
  });

  group('eligibility', () {
    test('inactive listings never appear', () {
      final all = matcher.rank(
        seed.listings,
        const MatchRequest(),
        MatchContext(now: now, viewerId: 'viewer'),
      );
      expect(ids(all), isNot(contains(SeedIds.listing(15)))); // closed
      expect(ids(all), isNot(contains(SeedIds.listing(20)))); // paused
      expect(all.length, seed.listings.where((l) => l.isActive).length);
    });

    test('own listings are excluded from discovery', () {
      final amina = profile(SeedIds.amina);
      final r = search('robotics', viewer: amina);
      expect(ids(r), isNot(contains(SeedIds.listing(6))));
    });

    test('remote-only filter and wording are hard constraints', () {
      final filtered = search(
        'tutoring',
        filters: const MatchFilters(remoteOnly: true),
      );
      expect(filtered, isNotEmpty);
      expect(filtered.every((r) => r.listing.remoteAvailable), isTrue);
      final worded = search('web development remote only');
      expect(worded.every((r) => r.listing.remoteAvailable), isTrue);
    });

    test('in-person-only wording excludes remote-only listings', () {
      final r = search('software mentorship in person only');
      expect(ids(r), isNot(contains(SeedIds.listing(2))));
    });

    test('area filter keeps nearby and remote listings', () {
      final r = matcher.rank(
        seed.listings,
        const MatchRequest(filters: MatchFilters(areaId: 'trenton')),
        MatchContext(now: now, viewerId: 'viewer'),
      );
      for (final x in r) {
        expect(x.listing.remoteAvailable || x.listing.areaId != null, isTrue);
      }
      // Sayreville is far from Trenton and in person only.
      expect(ids(r), isNot(contains(SeedIds.listing(27))));
    });

    test('type and category filters', () {
      final r = search(
        '',
        filters: const MatchFilters(types: {ListingType.volunteer}),
      );
      expect(r.every((x) => x.listing.type == ListingType.volunteer), isTrue);
      final c = search(
        '',
        filters: const MatchFilters(categories: {ListingCategory.food}),
      );
      expect(
        c.every((x) => x.listing.category == ListingCategory.food),
        isTrue,
      );
    });

    test('no fabricated results for an unmatched request', () {
      expect(search('quantum basket weaving lessons for llamas'), isEmpty);
    });

    test('profile goals never admit results to an unrelated search', () {
      // Zaid's profile seeks calculus tutoring; that must not leak into
      // results for words that match nothing.
      final zaid = profile(SeedIds.zaid);
      expect(search('quantum basket weaving', viewer: zaid), isEmpty);
      // But it still ranks relevant results for a related search.
      expect(
        ids(search('tutoring', viewer: zaid)),
        contains(SeedIds.listing(21)),
      );
    });
  });

  group('ranking and signals', () {
    test('a strong match ranks above a weak one', () {
      final r = search('robotics mentor');
      expect(ids(r).first, SeedIds.listing(1));
    });

    test('location changes ranking between equally relevant listings', () {
      final req = MatchRequest(
        parsed: parser.parseSearch('looking for an internship'),
      );
      Map<String, double> scores(String area) {
        final r = matcher.rank(
          seed.listings,
          req,
          MatchContext(
            now: now,
            viewerId: 'viewer',
            profile: newMember(area: area, remote: false),
          ),
        );
        return {for (final x in r) x.listing.id: x.score};
      }

      final nearPrinceton = scores('princeton');
      final nearEdison = scores('edison');
      // The Princeton accounting internship gains when the member is in Princeton.
      expect(
        nearPrinceton[SeedIds.listing(13)]!,
        greaterThan(nearEdison[SeedIds.listing(13)]!),
      );
    });

    test('missing member location is dropped, not penalised', () {
      final r = search(
        'looking for an internship',
        viewer: newMember(remote: false),
      );
      for (final x in r) {
        expect(x.factors[MatchFactor.geography], isNull);
      }
      expect(r, isNotEmpty);
    });

    test('remote preference makes remote listings fit', () {
      final remote = search('software career mentorship remote');
      final mentor = remote.firstWhere(
        (x) => x.listing.id == SeedIds.listing(2),
      );
      expect(mentor.factors[MatchFactor.geography], 1.0);
      expect(
        mentor.reasons.map((e) => e.text),
        contains('Remote, so it works from anywhere'),
      );
    });

    test('weights are configurable', () {
      const recencyOnly = ListingMatcher(
        weights: MatchWeights(
          goalFit: 0,
          skillsInterests: 0,
          description: 0,
          geography: 0,
          recency: 1,
          preferences: 0,
        ),
      );
      final r = recencyOnly.rank(
        seed.listings,
        MatchRequest(parsed: parser.parseSearch('looking for an internship')),
        MatchContext(now: now, viewerId: 'viewer'),
      );
      for (var i = 1; i < r.length; i++) {
        expect(
          r[i - 1].listing.createdAt.isAfter(r[i].listing.createdAt) ||
              r[i - 1].listing.createdAt == r[i].listing.createdAt,
          isTrue,
        );
      }
    });

    test('ties break by newest, then by id', () {
      final a = listing(21).copyWith(updatedAt: now);
      final twin = Listing.fromJson({
        ...a.toJson(),
        'id': '00000000-0000-4000-8000-000000000000',
      });
      final r = matcher.rank(
        [a, twin],
        const MatchRequest(),
        MatchContext(now: now),
      );
      expect(r.first.listing.id, '00000000-0000-4000-8000-000000000000');
      expect(r.first.score, r.last.score);
    });

    test('explanations only cite real fields', () {
      final r = search('graphic design flyers');
      expect(r, isNotEmpty);
      for (final x in r) {
        for (final reason in x.reasons) {
          if (reason.factor == MatchFactor.description) {
            final l = x.listing;
            final text = '${l.title} ${l.description} ${l.tags.join(' ')}'
                .toLowerCase();
            final quoted = RegExp(
              '"([^"]+)"',
            ).allMatches(reason.text).map((m) => m.group(1)!);
            for (final q in quoted) {
              expect(
                text.contains(q.substring(0, q.length - 1)),
                isTrue,
                reason: '$q in ${l.title}',
              );
            }
          }
        }
      }
    });

    test('an incidental mention is not treated as a fit', () {
      final tutor = newMember(
        goals: const [
          Goal(
            type: ListingType.service,
            role: GoalRole.offering,
            subjects: ['Tutoring', 'Math'],
          ),
        ],
      );
      final r = matcher.rank(
        seed.listings,
        const MatchRequest(mode: MatchMode.recommendations),
        MatchContext(now: now, viewerId: tutor.id, profile: tutor),
      );
      final calc = r.firstWhere((x) => x.listing.id == SeedIds.listing(23));
      expect(calc.reasons.map((e) => e.text), contains('Mentions tutoring'));
      final flyers = r
          .where((x) => x.listing.id == SeedIds.listing(29))
          .firstOrNull;
      if (flyers != null) {
        expect(
          flyers.reasons.map((e) => e.text),
          isNot(contains('Mentions tutoring')),
        );
        expect(flyers.score, lessThan(calc.score));
      }
    });
  });

  group('personalization', () {
    ActivityEvent ev(int n, ActivityType type, {int minutes = 0}) {
      final l = listing(n);
      return ActivityEvent(
        id: 'e$n-${type.wire}-$minutes',
        userId: 'viewer',
        listingId: l.id,
        type: type,
        listingType: l.type,
        category: l.category,
        tags: l.tags,
        createdAt: now.add(Duration(minutes: minutes)),
      );
    }

    test('saving raises similar listings, explainably', () {
      final viewer = newMember(
        goals: const [Goal(type: ListingType.service, role: GoalRole.seeking)],
      );
      List<MatchResult> recs(PreferenceModel prefs) => matcher.rank(
        seed.listings,
        const MatchRequest(mode: MatchMode.recommendations),
        MatchContext(
          now: now,
          viewerId: viewer.id,
          profile: viewer,
          preferences: prefs,
        ),
      );
      double gap(List<MatchResult> r) =>
          r.firstWhere((x) => x.listing.id == SeedIds.listing(22)).score -
          r.firstWhere((x) => x.listing.id == SeedIds.listing(26)).score;

      final before = recs(PreferenceModel.empty);
      final prefs = PreferenceModel.fromEvents([ev(21, ActivityType.saved)]);
      final after = recs(prefs);
      // The education listing gains on an unrelated design listing...
      expect(gap(after), greaterThan(gap(before)));
      expect(
        ids(after).indexOf(SeedIds.listing(22)),
        lessThanOrEqualTo(ids(before).indexOf(SeedIds.listing(22))),
      );
      // ...and says why.
      final quran = after.firstWhere(
        (x) => x.listing.id == SeedIds.listing(22),
      );
      expect(
        quran.reasons.map((e) => e.text),
        contains('Similar to listings you saved'),
      );
      expect(prefs.describe().first.label, ListingCategory.education.label);
    });

    test('unsave cancels a save', () {
      final prefs = PreferenceModel.fromEvents([
        ev(21, ActivityType.saved),
        ev(21, ActivityType.unsaved, minutes: 1),
      ]);
      expect(prefs.hasSignals, isFalse);
    });

    test('views are capped below one save', () {
      final views = PreferenceModel.fromEvents([
        for (final n in [21, 22, 23, 28, 13, 24]) ev(n, ActivityType.viewed),
      ]);
      final save = PreferenceModel.fromEvents([ev(21, ActivityType.saved)]);
      expect(
        views.categoryAffinity[ListingCategory.education]!,
        lessThan(save.categoryAffinity[ListingCategory.education]!),
      );
    });

    test(
      'show less hides the listing from recommendations and lowers its kind',
      () {
        final viewer = newMember(
          goals: const [
            Goal(type: ListingType.service, role: GoalRole.seeking),
          ],
        );
        final prefs = PreferenceModel.fromEvents([
          ev(26, ActivityType.dismissed),
        ]);
        final r = matcher.rank(
          seed.listings,
          const MatchRequest(mode: MatchMode.recommendations),
          MatchContext(
            now: now,
            viewerId: viewer.id,
            profile: viewer,
            preferences: prefs,
          ),
        );
        expect(ids(r), isNot(contains(SeedIds.listing(26))));
        expect(
          prefs.score(listing(31)),
          lessThan(0.5),
        ); // same category, lowered
      },
    );

    test('turning personalization off removes the activity factor', () {
      final viewer = newMember(personalization: false);
      final prefs = PreferenceModel.fromEvents([ev(21, ActivityType.saved)]);
      final r = matcher.rank(
        seed.listings,
        const MatchRequest(),
        MatchContext(
          now: now,
          viewerId: viewer.id,
          profile: viewer,
          preferences: prefs,
        ),
      );
      expect(
        r.every((x) => x.factors[MatchFactor.preferences] == null),
        isTrue,
      );
    });

    test('contact requests weigh more than saves', () {
      final saved = PreferenceModel.fromEvents([ev(21, ActivityType.saved)]);
      final contacted = PreferenceModel.fromEvents([
        ev(21, ActivityType.contactRequested),
      ]);
      expect(
        contacted.affinity(listing(22)),
        greaterThan(saved.affinity(listing(22))),
      );
    });
  });
}
