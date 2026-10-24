import 'dart:math' as math;

import '../domain/areas.dart';
import '../domain/goal.dart';
import '../domain/listing.dart';
import '../domain/profile.dart';
import '../domain/taxonomy.dart';
import 'intent_parser.dart';
import 'lexicon.dart';
import 'preference_model.dart';
import 'text.dart';

/// Ranking factors, in the order they are documented.
enum MatchFactor {
  goalFit('Goal and listing type'),
  skillsInterests('Skills and interests'),
  description('Description relevance'),
  geography('Location'),
  recency('Recency'),
  preferences('Your activity');

  const MatchFactor(this.label);
  final String label;
}

/// Configurable weights. Defaults are the initial design weights from the
/// planning documents; they are not validated model performance.
class MatchWeights {
  const MatchWeights({
    this.goalFit = 0.30,
    this.skillsInterests = 0.25,
    this.description = 0.25,
    this.geography = 0.10,
    this.recency = 0.05,
    this.preferences = 0.05,
  });

  static const defaults = MatchWeights();

  final double goalFit;
  final double skillsInterests;
  final double description;
  final double geography;
  final double recency;
  final double preferences;

  double of(MatchFactor f) => switch (f) {
    MatchFactor.goalFit => goalFit,
    MatchFactor.skillsInterests => skillsInterests,
    MatchFactor.description => description,
    MatchFactor.geography => geography,
    MatchFactor.recency => recency,
    MatchFactor.preferences => preferences,
  };

  double get total =>
      goalFit +
      skillsInterests +
      description +
      geography +
      recency +
      preferences;
}

/// Tunable thresholds.
class MatchConfig {
  const MatchConfig({
    this.minSearchScore = 0.25,
    this.minRecommendationScore = 0.30,
    this.distanceFalloffMiles = 25,
    this.recencyHalfLifeDays = 30,
    this.areaFilterRadiusMiles = 15,
  });

  final double minSearchScore;
  final double minRecommendationScore;

  /// Distance at which the location score reaches zero.
  final double distanceFalloffMiles;
  final double recencyHalfLifeDays;

  /// Radius used by the explicit area filter.
  final double areaFilterRadiusMiles;
}

/// Explicit filters chosen in the interface. These are hard constraints.
class MatchFilters {
  const MatchFilters({
    this.types = const {},
    this.categories = const {},
    this.areaId,
    this.remoteOnly = false,
  });

  static const none = MatchFilters();

  final Set<ListingType> types;
  final Set<ListingCategory> categories;

  /// Only listings within the configured radius (or remote ones).
  final String? areaId;
  final bool remoteOnly;

  bool get isEmpty =>
      types.isEmpty && categories.isEmpty && areaId == null && !remoteOnly;

  int get activeCount =>
      (types.isEmpty ? 0 : 1) +
      (categories.isEmpty ? 0 : 1) +
      (areaId == null ? 0 : 1) +
      (remoteOnly ? 1 : 0);

  MatchFilters copyWith({
    Set<ListingType>? types,
    Set<ListingCategory>? categories,
    String? Function()? areaId,
    bool? remoteOnly,
  }) => MatchFilters(
    types: types ?? this.types,
    categories: categories ?? this.categories,
    areaId: areaId != null ? areaId() : this.areaId,
    remoteOnly: remoteOnly ?? this.remoteOnly,
  );
}

enum MatchMode {
  /// A typed request. Its own goals are enforced; results need evidence.
  search,

  /// The personalized home feed, driven by the member's profile.
  recommendations,
}

class MatchRequest {
  const MatchRequest({
    this.parsed = ParsedRequest.empty,
    this.filters = MatchFilters.none,
    this.mode = MatchMode.search,
  });

  final ParsedRequest parsed;
  final MatchFilters filters;
  final MatchMode mode;
}

class MatchContext {
  MatchContext({
    required this.now,
    this.viewerId,
    this.profile,
    PreferenceModel? preferences,
    this.excludeDismissed = true,
  }) : preferences = preferences ?? PreferenceModel.empty;

  final DateTime now;
  final String? viewerId;
  final Profile? profile;
  final PreferenceModel preferences;
  final bool excludeDismissed;
}

class MatchReason {
  const MatchReason(this.factor, this.text);
  final MatchFactor factor;
  final String text;

  @override
  String toString() => text;
}

class MatchResult {
  const MatchResult({
    required this.listing,
    required this.score,
    required this.factors,
    required this.reasons,
    this.matchedGoal,
  });

  final Listing listing;

  /// 0..1 after renormalizing over available factors.
  final double score;

  /// Factor value 0..1, or null when the signal was missing.
  final Map<MatchFactor, double?> factors;
  final List<MatchReason> reasons;

  /// The member's goal this listing serves, when there is one.
  final Goal? matchedGoal;

  String? get primaryReason => reasons.isEmpty ? null : reasons.first.text;
}

/// Ranks existing listings. Never creates results: an empty list is a valid
/// answer.
///
/// Pipeline: eligibility (active, not own, not dismissed, filters, explicit
/// remote/in-person constraints) → participant-role compatibility → weighted
/// factors → minimum relevance → stable sort (score, newest, id).
class ListingMatcher {
  const ListingMatcher({
    this.weights = MatchWeights.defaults,
    this.config = const MatchConfig(),
  });

  final MatchWeights weights;
  final MatchConfig config;

  List<MatchResult> rank(
    Iterable<Listing> listings,
    MatchRequest request,
    MatchContext context,
  ) {
    final results = <MatchResult>[];
    for (final l in listings) {
      final r = evaluate(l, request, context);
      if (r != null) results.add(r);
    }
    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byDate = b.listing.createdAt.compareTo(a.listing.createdAt);
      if (byDate != 0) return byDate;
      return a.listing.id.compareTo(b.listing.id);
    });
    return results;
  }

  /// Scores one listing, or returns null when it is ineligible or below the
  /// relevance threshold.
  MatchResult? evaluate(
    Listing l,
    MatchRequest request,
    MatchContext context, {
    bool applyThreshold = true,
  }) {
    final parsed = request.parsed;
    final profile = context.profile;
    final filters = request.filters;
    final isSearch = request.mode == MatchMode.search;

    // 1. Eligibility.
    if (!l.isActive) return null;
    if (context.viewerId != null && l.ownerId == context.viewerId) return null;
    if (!isSearch &&
        context.excludeDismissed &&
        context.preferences.dismissedListingIds.contains(l.id)) {
      return null;
    }
    if (filters.types.isNotEmpty && !filters.types.contains(l.type)) {
      return null;
    }
    if (filters.categories.isNotEmpty &&
        !filters.categories.contains(l.category)) {
      return null;
    }
    if (filters.remoteOnly && !l.remoteAvailable) return null;
    final filterArea = Areas.byId(filters.areaId);
    if (filterArea != null && !l.remoteAvailable) {
      final la = l.area;
      if (la == null ||
          Areas.distanceMiles(la, filterArea) > config.areaFilterRadiusMiles) {
        return null;
      }
    }
    if (parsed.remote == RemotePreference.remoteOnly && !l.remoteAvailable) {
      return null;
    }
    if (parsed.remote == RemotePreference.inPersonOnly && l.areaId == null) {
      return null;
    }

    // 2. Participant-role compatibility.
    final queryGoals = parsed.goals;
    final profileGoals = profile?.goals ?? const <Goal>[];
    final goals = isSearch && queryGoals.isNotEmpty ? queryGoals : profileGoals;
    final enforceRoles = isSearch
        ? queryGoals.isNotEmpty
        : profileGoals.isNotEmpty;

    Goal? matchedGoal;
    var fit = 0.0;
    for (final g in goals) {
      final c = compatibility(g, l);
      if (c > fit) {
        fit = c;
        matchedGoal = g;
      }
    }
    if (enforceRoles && fit == 0) return null;

    // 3. Factors.
    final text = _ListingText(l);
    final factors = <MatchFactor, double?>{};
    final reasons = <MatchReason>[];

    factors[MatchFactor.goalFit] = goals.isEmpty ? null : fit;

    // Skills and interests.
    final goalSubjects = matchedGoal?.subjects ?? const <String>[];
    final context_ = isSearch ? parsed.contextTerms : const <String>[];
    // A subject counts fully only when it fits the listing (same category,
    // or named in its tags); an incidental mention ("designer needed for
    // tutoring flyers" for a tutor) counts a little and is never a reason.
    final subjectHits = [
      for (final s in goalSubjects)
        if (text.fits(s)) s,
    ];
    final incidental = [
      for (final s in goalSubjects)
        if (!subjectHits.contains(s) && text.has(s)) s,
    ];
    final contextHits = [
      for (final s in context_)
        if (text.has(s)) s,
    ];
    final skills = _unique([...?profile?.skills, ...parsed.skills]);
    final interests = _unique([...?profile?.interests, ...parsed.interests]);
    final skillHits = [
      for (final s in skills)
        if (text.fits(s)) s,
    ];
    final interestHits = [
      for (final s in interests)
        if (text.fits(s) && !skillHits.contains(s)) s,
    ];
    double? statedScore;
    if (goalSubjects.isNotEmpty || context_.isNotEmpty) {
      final denom = goalSubjects.length + 0.5 * context_.length;
      statedScore =
          (subjectHits.length +
              0.3 * incidental.length +
              0.5 * contextHits.length) /
          denom;
    }
    double? profileScore;
    if (skills.isNotEmpty || interests.isNotEmpty) {
      profileScore = math.min(1, (skillHits.length + interestHits.length) / 2);
    }
    factors[MatchFactor.skillsInterests] = switch ((
      statedScore,
      profileScore,
    )) {
      (null, null) => null,
      (final s?, null) => s,
      (null, final p?) => p,
      (final s?, final p?) => 0.6 * s + 0.4 * p,
    };

    // Description relevance.
    final keywords = isSearch ? parsed.keywords : _profileKeywords(profile);
    double? descScore;
    final keywordHits = <String>[];
    if (keywords.isNotEmpty) {
      var num = 0.0;
      var den = 0.0;
      for (final k in keywords) {
        den += k.weight;
        final m = text.fieldScore(k.spellings);
        if (m > 0) {
          num += k.weight * m;
          if (k.weight >= 0.5) keywordHits.add(k.label);
        }
      }
      descScore = den == 0 ? null : num / den;
    }
    factors[MatchFactor.description] = descScore;

    // Geography.
    final geo = _geography(l, parsed, filters, profile, isSearch);
    factors[MatchFactor.geography] = geo?.$1;

    // Recency.
    final ageDays = math.max(
      0,
      context.now.difference(l.createdAt).inHours / 24,
    );
    factors[MatchFactor.recency] = math
        .pow(0.5, ageDays / config.recencyHalfLifeDays)
        .toDouble();

    // Previously expressed preferences.
    final prefs = context.preferences;
    final personalize =
        (profile?.personalizationEnabled ?? false) && prefs.hasSignals;
    factors[MatchFactor.preferences] = personalize ? prefs.score(l) : null;

    // 4. Weighted score over available factors.
    var num = 0.0;
    var den = 0.0;
    for (final f in MatchFactor.values) {
      final v = factors[f];
      if (v == null) continue;
      num += weights.of(f) * v;
      den += weights.of(f);
    }
    final score = den == 0 ? 0.0 : num / den;

    // 5. Minimum relevance.
    if (applyThreshold) {
      if (isSearch) {
        // Evidence for a typed request must come from what was typed; the
        // member's profile can rank results but never admit them.
        final goalsFromQuery = queryGoals.isNotEmpty;
        final querySubjects = goalsFromQuery ? goalSubjects : const <String>[];
        final contentWords = parsed.keywords.any((k) => k.weight >= 0.5);
        final needsEvidence = contentWords || querySubjects.isNotEmpty;
        // "Looking for an internship" names only a type: every compatible
        // listing is relevant. Any other words must find something.
        final exempt =
            goalsFromQuery &&
            fit >= 1 &&
            querySubjects.isEmpty &&
            !contentWords &&
            parsed.contextTerms.isEmpty;
        final hasEvidence =
            (goalsFromQuery && subjectHits.isNotEmpty) ||
            keywordHits.isNotEmpty ||
            contextHits.isNotEmpty;
        if (needsEvidence && !exempt && !hasEvidence) return null;
        if (score < config.minSearchScore) return null;
      } else if (score < config.minRecommendationScore) {
        return null;
      }
    }

    // 6. Reasons, derived only from the signals above.
    if (matchedGoal != null && fit > 0) {
      reasons.add(
        MatchReason(MatchFactor.goalFit, goalReason(matchedGoal, l, fit)),
      );
    }
    if (subjectHits.isNotEmpty) {
      reasons.add(
        MatchReason(
          MatchFactor.skillsInterests,
          'Mentions ${_list(subjectHits.map((s) => s.toLowerCase()))}',
        ),
      );
    } else if (skillHits.isNotEmpty) {
      reasons.add(
        MatchReason(
          MatchFactor.skillsInterests,
          'Matches your skills: ${_list(skillHits)}',
        ),
      );
    } else if (interestHits.isNotEmpty) {
      reasons.add(
        MatchReason(
          MatchFactor.skillsInterests,
          'Related to your interest in ${_list(interestHits.map((s) => s.toLowerCase()))}',
        ),
      );
    }
    final mentioned = {
      ...subjectHits.map((s) => s.toLowerCase()),
      ...skillHits.map((s) => s.toLowerCase()),
      ...interestHits.map((s) => s.toLowerCase()),
    };
    final extraKeywords = [
      for (final k in keywordHits)
        if (!mentioned.contains(k.toLowerCase())) k,
    ];
    if (isSearch && extraKeywords.isNotEmpty) {
      reasons.add(
        MatchReason(
          MatchFactor.description,
          'Matches your search: ${_list(extraKeywords.take(3).map((k) => '"${k.toLowerCase()}"'))}',
        ),
      );
    }
    if (geo?.$2 != null && (geo!.$1 >= 0.6)) {
      reasons.add(MatchReason(MatchFactor.geography, geo.$2!));
    }
    final prefReason = personalize ? prefs.reasonFor(l) : null;
    if (prefReason != null) {
      reasons.add(MatchReason(MatchFactor.preferences, prefReason));
    }
    if (ageDays < 4) {
      final d = ageDays.floor();
      reasons.add(
        MatchReason(
          MatchFactor.recency,
          d == 0 ? 'Posted today' : 'Posted $d day${d == 1 ? '' : 's'} ago',
        ),
      );
    }

    return MatchResult(
      listing: l,
      score: score,
      factors: factors,
      reasons: reasons,
      matchedGoal: matchedGoal,
    );
  }

  /// How well a listing's type and direction serve a goal, 0..1.
  ///
  /// Same type: the listing must take the complementary role (seeking a
  /// mentor is served by someone offering mentorship, never by another
  /// request for a mentor). Collaboration is reciprocal. A few related types
  /// score partially.
  static double compatibility(Goal g, Listing l) {
    if (l.type == g.type) {
      if (l.type.isReciprocal) {
        return l.direction == g.compatibleDirection ? 1.0 : 0.7;
      }
      return l.direction == g.compatibleDirection ? 1.0 : 0.0;
    }
    return switch ((g.type, g.role, l.type, l.direction)) {
      // A mentor can fill a volunteer role that needs a mentor.
      (
        ListingType.mentorship,
        GoalRole.offering,
        ListingType.volunteer,
        ListingDirection.offer,
      ) =>
        0.6,
      // A local business can provide the help someone is looking for.
      (ListingType.service, GoalRole.seeking, ListingType.business, _) => 0.7,
      (
        ListingType.business,
        GoalRole.seeking,
        ListingType.service,
        ListingDirection.offer,
      ) =>
        0.6,
      _ => 0.0,
    };
  }

  static String goalReason(Goal g, Listing l, double fit) {
    if (fit < 1) {
      return '${l.directionLabel} · related to what you ${g.role == GoalRole.seeking ? 'are looking for' : 'offer'}';
    }
    return switch ((g.type, g.role)) {
      (ListingType.mentorship, GoalRole.seeking) =>
        'Offers mentorship, which you’re looking for',
      (ListingType.mentorship, GoalRole.offering) =>
        'Looking for a mentor, and you offer mentorship',
      (ListingType.internship, GoalRole.seeking) =>
        'Internship opening, which you’re looking for',
      (ListingType.internship, GoalRole.offering) =>
        'Looking for an internship you could host',
      (ListingType.job, GoalRole.seeking) =>
        'Hiring, and you’re looking for work',
      (ListingType.job, GoalRole.offering) =>
        'Looking for work, and you’re hiring',
      (ListingType.service, GoalRole.seeking) =>
        'Offers the kind of help you’re looking for',
      (ListingType.service, GoalRole.offering) => 'Looking for help you offer',
      (ListingType.volunteer, GoalRole.seeking) =>
        'Needs volunteers, and you’d like to volunteer',
      (ListingType.volunteer, GoalRole.offering) =>
        'Wants to volunteer, and you need volunteers',
      (ListingType.collaboration, _) =>
        l.direction == ListingDirection.request
            ? 'Looking for collaborators'
            : 'Open to collaborating',
      (ListingType.business, GoalRole.seeking) =>
        'A local business, which you’re looking for',
      (ListingType.business, GoalRole.offering) => 'Related to your business',
    };
  }

  (double, String?)? _geography(
    Listing l,
    ParsedRequest parsed,
    MatchFilters filters,
    Profile? profile,
    bool isSearch,
  ) {
    final userArea = Areas.byId(
      (isSearch ? (parsed.areaId ?? filters.areaId) : null) ?? profile?.areaId,
    );
    final remotePref = parsed.remote;
    final remoteWelcome =
        remotePref == RemotePreference.remoteOk ||
        remotePref == RemotePreference.remoteOnly ||
        (profile?.openToRemote ?? false);
    if (userArea == null &&
        remotePref == RemotePreference.unspecified &&
        !(profile?.openToRemote ?? false)) {
      return null; // Member-side signal missing: factor dropped.
    }

    double? local;
    String? localReason;
    final la = l.area;
    if (la != null && userArea != null) {
      final d = Areas.distanceMiles(la, userArea);
      local = (1 - d / config.distanceFalloffMiles).clamp(0.0, 1.0);
      if (la.id == userArea.id) {
        localReason = 'In ${la.name}';
      } else {
        localReason = 'About ${d.round()} mi from ${userArea.name}';
      }
    }
    double? remote;
    if (l.remoteAvailable) remote = remoteWelcome ? 1.0 : 0.7;

    if (local == null && remote == null) {
      // Listing-side location unknown (or member gave only a remote
      // preference): neutral.
      return (userArea == null && remotePref == RemotePreference.remoteOk)
          ? (0.4, null)
          : (0.5, null);
    }
    if (remote != null && (local == null || remote >= local)) {
      return (
        remote,
        remoteWelcome ? 'Remote, so it works from anywhere' : null,
      );
    }
    return (local!, localReason);
  }

  List<SearchTerm> _profileKeywords(Profile? p) {
    if (p == null) return const [];
    final text = [
      p.seekingSummary,
      p.offeringSummary,
    ].where((s) => s.isNotEmpty).join('. ');
    if (text.isEmpty) return const [];
    return const DeterministicParser().parseSearch(text).keywords;
  }
}

/// Stemmed listing fields for term lookups.
class _ListingText {
  _ListingText(Listing l)
    : title = stemmedText(l.title),
      tags = stemmedText(l.tags.join(' , ')),
      description = stemmedText(l.description),
      category = stemmedText('${l.category.label} ${l.category.shortLabel}'),
      listingCategory = l.category;

  final String title;
  final String tags;
  final String description;
  final String category;

  final ListingCategory? listingCategory;

  bool has(String subject) => fieldScore(Lexicon.spellingsFor(subject)) > 0;

  /// [has], and consistent with the listing: the subject's category matches
  /// the listing's, or the subject is one of its tags.
  bool fits(String subject) {
    if (!has(subject)) return false;
    final category = Lexicon.byCanonical(subject)?.category;
    if (category == null || category == listingCategory) return true;
    return Lexicon.spellingsFor(subject).any((s) => containsPhrase(tags, s));
  }

  /// 1.0 title, 0.8 tags, 0.6 description, 0.4 category label, else 0.
  double fieldScore(List<String> spellings) {
    var best = 0.0;
    for (final s in spellings) {
      if (containsPhrase(title, s)) return 1.0;
      if (containsPhrase(tags, s)) best = math.max(best, 0.8);
      if (containsPhrase(description, s)) best = math.max(best, 0.6);
      if (containsPhrase(category, s)) best = math.max(best, 0.4);
    }
    return best;
  }
}

List<String> _unique(Iterable<String> items) {
  final seen = <String>{};
  return [
    for (final i in items)
      if (seen.add(i.toLowerCase())) i,
  ];
}

String _list(Iterable<String> items) {
  final l = items.toList();
  if (l.length <= 1) return l.join();
  if (l.length == 2) return '${l[0]} and ${l[1]}';
  return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
}
