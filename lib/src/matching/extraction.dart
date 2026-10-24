import 'dart:async';

import '../domain/areas.dart';
import '../domain/goal.dart';
import '../domain/taxonomy.dart';
import 'intent_parser.dart';
import 'lexicon.dart';
import 'text.dart';

/// Where suggestions came from.
enum ExtractionSource {
  /// The server-side AI extractor, validated against the member's words.
  ai,

  /// The deterministic rule-based parser.
  rules,
}

/// Why the AI extractor was not used.
enum FallbackReason { notConfigured, timeout, malformed, unavailable }

class ExtractionOutcome {
  const ExtractionOutcome(this.extraction, this.source, {this.fallbackReason});

  final ProfileExtraction extraction;
  final ExtractionSource source;
  final FallbackReason? fallbackReason;
}

/// Turns onboarding answers into reviewable suggestions.
abstract interface class ProfileExtractor {
  Future<ExtractionOutcome> extract(OnboardingAnswers answers);
}

/// Rule-based extraction; always available, no network.
class RulesExtractor implements ProfileExtractor {
  const RulesExtractor({this.parser = const DeterministicParser()});

  final DeterministicParser parser;

  @override
  Future<ExtractionOutcome> extract(OnboardingAnswers answers) async =>
      ExtractionOutcome(
        parser.parseProfile(answers),
        ExtractionSource.rules,
        fallbackReason: FallbackReason.notConfigured,
      );
}

/// Transport for the server-side extractor (a Supabase Edge Function in
/// connected mode). Provider secrets never reach the client.
abstract interface class RemoteExtractionClient {
  Future<Object?> requestExtraction(OnboardingAnswers answers);
}

/// Uses AI suggestions when they arrive in time and pass validation, and the
/// deterministic parser otherwise. Results from both are grounded in the
/// member's own words before they are shown.
class AiProfileExtractor implements ProfileExtractor {
  AiProfileExtractor(
    this.client, {
    this.timeout = const Duration(seconds: 8),
    this.parser = const DeterministicParser(),
  });

  final RemoteExtractionClient client;
  final Duration timeout;
  final DeterministicParser parser;

  @override
  Future<ExtractionOutcome> extract(OnboardingAnswers answers) async {
    final rules = parser.parseProfile(answers);
    if (answers.isBlank) {
      return ExtractionOutcome(rules, ExtractionSource.rules);
    }
    try {
      final raw = await client.requestExtraction(answers).timeout(timeout);
      final ai = validateAiExtraction(raw, answers);
      return ExtractionOutcome(
        mergeExtractions(ai, rules),
        ExtractionSource.ai,
      );
    } on TimeoutException {
      return ExtractionOutcome(
        rules,
        ExtractionSource.rules,
        fallbackReason: FallbackReason.timeout,
      );
    } on FormatException {
      return ExtractionOutcome(
        rules,
        ExtractionSource.rules,
        fallbackReason: FallbackReason.malformed,
      );
    } catch (_) {
      return ExtractionOutcome(
        rules,
        ExtractionSource.rules,
        fallbackReason: FallbackReason.unavailable,
      );
    }
  }
}

/// Validates untrusted AI output. Throws [FormatException] when the shape is
/// wrong; silently drops any value that is not grounded in [answers].
///
/// Expected shape:
/// ```json
/// {"skills": ["Python"], "interests": ["Robotics"],
///  "goals": [{"type": "mentorship", "role": "seeking", "subjects": ["Robotics"]}],
///  "area": "New Brunswick"}
/// ```
ProfileExtraction validateAiExtraction(Object? raw, OnboardingAnswers answers) {
  if (raw is! Map) throw const FormatException('Extraction is not an object');
  final map = raw.map((k, v) => MapEntry(k.toString(), v));

  List<String> stringList(String key, {int max = 12}) {
    final value = map[key];
    if (value == null) return const [];
    if (value is! List) throw FormatException('$key is not a list');
    return value
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length <= 60)
        .take(max)
        .toList();
  }

  final source = answers.combined;
  final skillSource = [answers.offer, answers.seek].join('\n');

  final skills = [
    for (final s in stringList('skills'))
      if (isGrounded(s, skillSource) && !_isStudyOnly(s, answers))
        canonicalize(s),
  ];
  final interests = [
    for (final s in stringList('interests'))
      if (isGrounded(s, source)) canonicalize(s),
  ];

  final goals = <Goal>[];
  final rawGoals = map['goals'];
  if (rawGoals != null) {
    if (rawGoals is! List) throw const FormatException('goals is not a list');
    for (final g in rawGoals.take(8)) {
      if (g is! Map) continue;
      final type = _enumByWire(ListingType.values, g['type'], (t) => t.wire);
      final role = _enumByWire(GoalRole.values, g['role'], (r) => r.wire);
      if (type == null || role == null) continue;
      final subjects = (g['subjects'] is List)
          ? (g['subjects'] as List)
                .whereType<String>()
                .where((s) => isGrounded(s, source))
                .map(canonicalize)
                .take(6)
                .toList()
          : const <String>[];
      goals.add(Goal(type: type, role: role, subjects: _dedupe(subjects)));
    }
  }

  String? areaId;
  final rawArea = map['area'];
  if (rawArea is String && rawArea.trim().isNotEmpty) {
    final area = _resolveArea(rawArea);
    // The area must be one the member actually named.
    if (area != null &&
        area.aliases.any((a) => containsPhrase(normalizeText(source), a))) {
      areaId = area.id;
    }
  }

  return ProfileExtraction(
    skills: _dedupe(skills),
    interests: _dedupe(interests),
    goals: goals,
    offeringSummary: answers.offer.trim(),
    seekingSummary: answers.seek.trim(),
    areaId: areaId,
    // Remote preference always comes from explicit wording via the parser.
    openToRemote: null,
  );
}

/// Combines validated AI output with rule-based output (AI first).
ProfileExtraction mergeExtractions(
  ProfileExtraction ai,
  ProfileExtraction rules,
) {
  final goals = [...ai.goals];
  for (final g in rules.goals) {
    final idx = goals.indexWhere((x) => x.type == g.type && x.role == g.role);
    if (idx < 0) {
      goals.add(g);
    } else {
      goals[idx] = goals[idx].copyWith(
        subjects: _dedupe([...goals[idx].subjects, ...g.subjects]),
      );
    }
  }
  return ProfileExtraction(
    skills: _dedupe([...ai.skills, ...rules.skills]),
    interests: _dedupe([...ai.interests, ...rules.interests]),
    goals: goals,
    offeringSummary: rules.offeringSummary,
    seekingSummary: rules.seekingSummary,
    areaId: ai.areaId ?? rules.areaId,
    openToRemote: rules.openToRemote,
  );
}

/// True when every content word of [value] appears in [source] (after
/// stemming), or a recognised spelling of the term does.
bool isGrounded(String value, String source) {
  final sourceStems = contentStems(source).toSet();
  final valueStems = contentStems(value);
  if (valueStems.isEmpty) return false;
  if (valueStems.every(sourceStems.contains)) return true;
  final term = Lexicon.byCanonical(value);
  if (term == null) return false;
  final stemmedSource = stemmedText(source);
  return term.variants.any(
    (v) => containsPhrase(stemmedSource, stemmedText(v)),
  );
}

/// Display form: the lexicon spelling when known, otherwise sentence case.
String canonicalize(String value) =>
    Lexicon.byCanonical(value)?.canonical ??
    Lexicon.findIn(value)
        .where((t) => stemmedText(t.canonical) == stemmedText(value))
        .firstOrNull
        ?.canonical ??
    sentenceCase(value.trim());

bool _isStudyOnly(String skill, OnboardingAnswers answers) {
  // "Engineering" from "studying engineering" is not a qualification.
  final rules = const DeterministicParser().parseProfile(answers);
  if (rules.skills.any(
    (s) => s.toLowerCase() == canonicalize(skill).toLowerCase(),
  )) {
    return false;
  }
  final text = normalizeText('${answers.offer} ${answers.seek}');
  final s = normalizeText(skill);
  for (final lead in [
    'studying',
    'study',
    'major in',
    'majoring in',
    'student',
  ]) {
    if (text.contains('$lead $s') || text.contains('$s $lead')) return true;
  }
  return false;
}

Area? _resolveArea(String value) {
  final n = normalizeText(value);
  for (final a in Areas.all) {
    if (a.id == value || normalizeText(a.name) == n || a.aliases.contains(n)) {
      return a;
    }
  }
  return null;
}

T? _enumByWire<T>(List<T> values, Object? raw, String Function(T) wire) {
  if (raw is! String) return null;
  for (final v in values) {
    if (wire(v) == raw) return v;
  }
  return null;
}

List<String> _dedupe(Iterable<String> items) {
  final seen = <String>{};
  return [
    for (final i in items)
      if (seen.add(i.toLowerCase())) i,
  ];
}
