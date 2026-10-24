import 'dart:math' as math;

import '../domain/activity.dart';
import '../domain/listing.dart';
import '../domain/taxonomy.dart';

/// How much each explicit signal moves a member's preferences.
class PreferenceWeights {
  const PreferenceWeights({
    this.saved = 1.0,
    this.contactRequested = 1.5,
    this.dismissed = -2.0,
    this.viewed = 0.25,
    this.viewCapPerCategory = 0.75,
  });

  final double saved;
  final double contactRequested;
  final double dismissed;

  /// Views are weak evidence and capped so they never outweigh one save.
  final double viewed;
  final double viewCapPerCategory;
}

/// A human-readable preference for the settings screen.
class PreferenceSignal {
  const PreferenceSignal(this.label, this.value, this.evidence);

  /// e.g. "Education & tutoring".
  final String label;

  /// Positive means "more like this", negative "less like this".
  final double value;

  /// e.g. "2 saved · 1 request".
  final String evidence;
}

class _Facet {
  _Facet(this.type, this.category, this.tags);
  ListingType type;
  ListingCategory category;
  List<String> tags;
  bool saved = false;
  bool contacted = false;
  bool dismissed = false;
  bool viewed = false;
}

class _Counts {
  int saved = 0;
  int contacted = 0;
  int dismissed = 0;
  int viewed = 0;
  double explicit = 0;
  double views = 0;
}

/// Transparent, explainable preferences computed from feedback events.
///
/// Each listing contributes once per kind of signal (saving the same listing
/// twice counts once; unsaving cancels a save). Affinities add up per
/// category, per listing type and per tag. Nothing is trained.
class PreferenceModel {
  PreferenceModel._({
    required this.categoryAffinity,
    required this.typeAffinity,
    required this.tagAffinity,
    required this.dismissedListingIds,
    required Map<ListingCategory, _Counts> counts,
    required this.eventCount,
  }) : _counts = counts; // ignore: prefer_initializing_formals

  static final empty = PreferenceModel._(
    categoryAffinity: const {},
    typeAffinity: const {},
    tagAffinity: const {},
    dismissedListingIds: const {},
    counts: const {},
    eventCount: 0,
  );

  factory PreferenceModel.fromEvents(
    Iterable<ActivityEvent> events, {
    PreferenceWeights weights = const PreferenceWeights(),
  }) {
    final sorted = events.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final facets = <String, _Facet>{};
    for (final e in sorted) {
      final f = facets.putIfAbsent(
        e.listingId,
        () => _Facet(e.listingType, e.category, e.tags),
      );
      f
        ..type = e.listingType
        ..category = e.category
        ..tags = e.tags;
      switch (e.type) {
        case ActivityType.saved:
          f.saved = true;
        case ActivityType.unsaved:
          f.saved = false;
        case ActivityType.contactRequested:
          f.contacted = true;
        case ActivityType.dismissed:
          f.dismissed = true;
        case ActivityType.viewed:
          f.viewed = true;
      }
    }

    final counts = <ListingCategory, _Counts>{};
    final types = <ListingType, double>{};
    final typeViews = <ListingType, double>{};
    final tags = <String, double>{};
    final dismissed = <String>{};

    for (final entry in facets.entries) {
      final f = entry.value;
      var explicit = 0.0;
      if (f.saved) explicit += weights.saved;
      if (f.contacted) explicit += weights.contactRequested;
      if (f.dismissed) {
        explicit += weights.dismissed;
        dismissed.add(entry.key);
      }
      final c = counts.putIfAbsent(f.category, _Counts.new);
      if (f.saved) c.saved++;
      if (f.contacted) c.contacted++;
      if (f.dismissed) c.dismissed++;
      if (f.viewed) {
        c.viewed++;
        c.views += weights.viewed;
      }
      c.explicit += explicit;
      types[f.type] = (types[f.type] ?? 0) + explicit;
      if (f.viewed) {
        typeViews[f.type] = (typeViews[f.type] ?? 0) + weights.viewed;
      }
      for (final t in f.tags) {
        tags[t] = (tags[t] ?? 0) + explicit * 0.5;
      }
    }

    final categories = <ListingCategory, double>{
      for (final e in counts.entries)
        e.key:
            e.value.explicit +
            math.min(e.value.views, weights.viewCapPerCategory),
    };
    for (final e in typeViews.entries) {
      types[e.key] =
          (types[e.key] ?? 0) + math.min(e.value, weights.viewCapPerCategory);
    }
    types.updateAll((k, v) => v.clamp(-4.0, 4.0));

    return PreferenceModel._(
      categoryAffinity: categories,
      typeAffinity: types,
      tagAffinity: tags,
      dismissedListingIds: dismissed,
      counts: counts,
      eventCount: sorted.length,
    );
  }

  final Map<ListingCategory, double> categoryAffinity;
  final Map<ListingType, double> typeAffinity;
  final Map<String, double> tagAffinity;
  final Set<String> dismissedListingIds;
  final Map<ListingCategory, _Counts> _counts;
  final int eventCount;

  bool get hasSignals =>
      categoryAffinity.values.any((v) => v != 0) ||
      typeAffinity.values.any((v) => v != 0);

  /// Raw affinity: category + half the type + a quarter of matching tags.
  double affinity(Listing l) {
    final cat = categoryAffinity[l.category] ?? 0;
    final type = typeAffinity[l.type] ?? 0;
    var tagSum = 0.0;
    for (final t in l.tags) {
      tagSum += tagAffinity[t] ?? 0;
    }
    return cat + 0.5 * type + 0.25 * tagSum.clamp(-1.0, 1.0);
  }

  /// Affinity mapped to 0..1, with 0.5 meaning neutral.
  double score(Listing l) => 0.5 + 0.5 * _tanh(affinity(l) / 2);

  /// A short reason when activity raised this listing, or null.
  String? reasonFor(Listing l) {
    final c = _counts[l.category];
    if (c == null || score(l) <= 0.55) return null;
    if (c.contacted > 0) return 'Similar to listings you asked about';
    if (c.saved > 0) return 'Similar to listings you saved';
    if (c.viewed > 0) return 'Similar to listings you viewed';
    return null;
  }

  /// Signals for the settings screen, strongest first.
  List<PreferenceSignal> describe() {
    final out = <PreferenceSignal>[];
    for (final e in categoryAffinity.entries) {
      if (e.value.abs() < 0.01) continue;
      final c = _counts[e.key]!;
      final parts = [
        if (c.saved > 0) '${c.saved} saved',
        if (c.contacted > 0)
          '${c.contacted} request${c.contacted == 1 ? '' : 's'}',
        if (c.dismissed > 0) '${c.dismissed} "show less"',
        if (c.viewed > 0) '${c.viewed} viewed',
      ];
      out.add(PreferenceSignal(e.key.label, e.value, parts.join(' · ')));
    }
    out.sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    return out;
  }

  static double _tanh(double x) {
    final e2 = math.exp(2 * x);
    return (e2 - 1) / (e2 + 1);
  }
}
