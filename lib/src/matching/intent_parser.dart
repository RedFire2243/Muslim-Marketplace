import '../domain/areas.dart';
import '../domain/goal.dart';
import '../domain/taxonomy.dart';
import 'lexicon.dart';
import 'text.dart';

/// How a request treats remote opportunities.
enum RemotePreference {
  /// Nothing said: remote listings are fine but not preferred.
  unspecified,

  /// "remote", "online": remote listings are a good fit.
  remoteOk,

  /// "remote only": a hard constraint.
  remoteOnly,

  /// "in person only": a hard constraint.
  inPersonOnly,
}

/// A weighted search term with every stemmed spelling that counts as a hit.
class SearchTerm {
  const SearchTerm(this.label, this.spellings, this.weight);

  final String label;
  final List<String> spellings;

  /// 1.0 for recognised vocabulary, 0.5 for other content words.
  final double weight;

  @override
  bool operator ==(Object other) => other is SearchTerm && other.label == label;

  @override
  int get hashCode => label.hashCode;

  @override
  String toString() => label;
}

/// Structured interpretation of free text. Every value is traceable to the
/// member's words; anything not stated is absent.
class ParsedRequest {
  const ParsedRequest({
    this.text = '',
    this.goals = const [],
    this.keywords = const [],
    this.contextTerms = const [],
    this.skills = const [],
    this.interests = const [],
    this.areaId,
    this.remote = RemotePreference.unspecified,
  });

  static const empty = ParsedRequest();

  final String text;
  final List<Goal> goals;
  final List<SearchTerm> keywords;

  /// Vocabulary from self-description ("an engineering student"). Used as
  /// secondary relevance, never recorded as a skill.
  final List<String> contextTerms;
  final List<String> skills;
  final List<String> interests;
  final String? areaId;
  final RemotePreference remote;

  bool get isEmpty =>
      goals.isEmpty &&
      keywords.isEmpty &&
      areaId == null &&
      remote == RemotePreference.unspecified;
}

/// Answers from the onboarding questions.
class OnboardingAnswers {
  const OnboardingAnswers({
    this.offer = '',
    this.seek = '',
    this.interests = '',
    this.area = '',
  });

  final String offer;
  final String seek;
  final String interests;
  final String area;

  bool get isBlank =>
      offer.trim().isEmpty &&
      seek.trim().isEmpty &&
      interests.trim().isEmpty &&
      area.trim().isEmpty;

  String get combined => [
    offer,
    seek,
    interests,
    area,
  ].where((s) => s.trim().isNotEmpty).join('\n');

  OnboardingAnswers copyWith({
    String? offer,
    String? seek,
    String? interests,
    String? area,
  }) => OnboardingAnswers(
    offer: offer ?? this.offer,
    seek: seek ?? this.seek,
    interests: interests ?? this.interests,
    area: area ?? this.area,
  );

  Map<String, Object?> toJson() => {
    'offer': offer,
    'seek': seek,
    'interests': interests,
    'area': area,
  };

  factory OnboardingAnswers.fromJson(Map<String, Object?> json) =>
      OnboardingAnswers(
        offer: json['offer'] as String? ?? '',
        seek: json['seek'] as String? ?? '',
        interests: json['interests'] as String? ?? '',
        area: json['area'] as String? ?? '',
      );
}

/// Structured profile suggestions from onboarding answers.
class ProfileExtraction {
  const ProfileExtraction({
    this.skills = const [],
    this.interests = const [],
    this.goals = const [],
    this.offeringSummary = '',
    this.seekingSummary = '',
    this.areaId,
    this.openToRemote,
  });

  final List<String> skills;
  final List<String> interests;
  final List<Goal> goals;
  final String offeringSummary;
  final String seekingSummary;
  final String? areaId;

  /// Null when the member did not mention remote work.
  final bool? openToRemote;

  bool get isEmpty =>
      skills.isEmpty &&
      interests.isEmpty &&
      goals.isEmpty &&
      areaId == null &&
      openToRemote == null;
}

enum _NounKind {
  /// Seeking it means seeking the type (internship, mentor, tutoring).
  opportunity,

  /// Seeking these people means offering the type (interns, volunteers).
  counterpart,

  /// A first-person verb that offers the type ("I can mentor").
  verbOffer,

  /// A first-person verb that seeks the type ("I want to volunteer").
  verbSeek,
}

class _TypeCue {
  const _TypeCue(this.type, this.kind, this.start, this.end);
  final ListingType type;
  final _NounKind kind;
  final int start;
  final int end;
}

class _Clause {
  _Clause(this.tokens);
  final List<String> tokens;
  List<String> get stems => tokens.map(stem).toList();
  String get text => tokens.join(' ');
}

/// Rule-based parser used in demo mode and whenever AI extraction is
/// unavailable. It recognises role phrases ("looking for", "I can"),
/// opportunity words ("mentor", "internship", "volunteers"), a fixed
/// vocabulary of skills and subjects, Central Jersey place names and remote
/// preferences. It never infers anything that is not written.
class DeterministicParser {
  const DeterministicParser();

  ParsedRequest parseSearch(String text) =>
      _parse(text, defaultRole: GoalRole.seeking);

  ProfileExtraction parseProfile(OnboardingAnswers answers) {
    final offer = _parse(
      answers.offer,
      defaultRole: GoalRole.offering,
      skillsFromAll: true,
    );
    final seek = _parse(answers.seek, defaultRole: GoalRole.seeking);
    final interestsField = _parseInterestList(answers.interests);
    final areaField = _parse(answers.area, defaultRole: GoalRole.seeking);

    final goals = _mergeGoals([...offer.goals, ...seek.goals]);
    final skills = _unique([...offer.skills, ...seek.skills]);
    final interests = _unique([
      ...interestsField,
      ...offer.interests,
      ...seek.interests,
    ]).where((i) => !skills.contains(i)).toList();

    final areaId = areaField.areaId ?? seek.areaId ?? offer.areaId;
    final remotes = [areaField.remote, seek.remote, offer.remote];
    bool? openToRemote;
    if (remotes.any(
      (r) => r == RemotePreference.remoteOk || r == RemotePreference.remoteOnly,
    )) {
      openToRemote = true;
    } else if (remotes.contains(RemotePreference.inPersonOnly)) {
      openToRemote = false;
    }

    return ProfileExtraction(
      skills: skills,
      interests: interests,
      goals: goals,
      offeringSummary: _summary(answers.offer),
      seekingSummary: _summary(answers.seek),
      areaId: areaId,
      openToRemote: openToRemote,
    );
  }

  // ---------------------------------------------------------------------
  // Core parse

  ParsedRequest _parse(
    String text, {
    required GoalRole defaultRole,
    bool skillsFromAll = false,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const ParsedRequest();

    final goals = <Goal>[];
    final context = <String>[];
    final skills = <String>[];
    final interests = <String>[];
    final consumed = <String>{};

    for (final sentence in _sentences(trimmed)) {
      GoalRole? role;
      var pending = <String>[];
      Goal? lastGoal;
      int? lastGoalIndex;

      for (final clause in _clauses(sentence)) {
        final tokens = clause.tokens;
        final stems = clause.stems;
        if (tokens.isEmpty) continue;

        final cue = _findRoleCue(tokens);
        var postStart = 0;
        if (cue != null) {
          role = cue.$1;
          postStart = cue.$3;
          consumed.addAll(tokens.sublist(cue.$2, cue.$3));
        }

        // Self-description before a role phrase is context. In the "offer"
        // answer it is also a skill, unless it describes studies.
        // Words before the role phrase describe the member; after it, what
        // they want. A study description ("engineering student") is context.
        final preIsStudy = tokens
            .sublist(0, postStart)
            .any(_studyWords.contains);
        final isStudyClause =
            postStart == 0 && tokens.any(_studyWords.contains);
        if (postStart > 0) {
          for (final t in Lexicon.findIn(
            tokens.sublist(0, postStart).join(' '),
          )) {
            if (skillsFromAll && !preIsStudy) {
              skills.add(t.canonical);
            } else {
              context.add(t.canonical);
            }
          }
        }

        final post = tokens.sublist(postStart);

        // Interests and explicit skills.
        final interestSpan = _spanAfter(post, _interestCues);
        final clauseInterests = <String>[];
        if (interestSpan != null) {
          final found = Lexicon.findIn(interestSpan.join(' '));
          if (found.isNotEmpty) {
            clauseInterests.addAll(found.map((t) => t.canonical));
          } else {
            final free = _freePhrase(interestSpan);
            if (free != null) clauseInterests.add(free);
          }
          interests.addAll(clauseInterests);
        }
        final skillSpan = _spanAfter(post, _skillCues);
        if (skillSpan != null) {
          final found = Lexicon.findIn(skillSpan.join(' '));
          if (found.isNotEmpty) {
            skills.addAll(found.map((t) => t.canonical));
          } else {
            final free = _freePhrase(skillSpan);
            if (free != null) skills.add(free);
          }
        }

        final cues = _findTypeCues(tokens, stems, postStart);
        for (final c in cues) {
          consumed.addAll(tokens.sublist(c.start, c.end));
        }

        // Subjects: vocabulary after the role phrase, excluding interests.
        final subjectTerms = [
          for (final t in Lexicon.findIn(post.join(' ')))
            if (!clauseInterests.contains(t.canonical)) t.canonical,
        ];
        final clauseSubjects = isStudyClause ? const <String>[] : subjectTerms;
        if (isStudyClause) context.addAll(subjectTerms);
        if (skillsFromAll && !isStudyClause) skills.addAll(clauseSubjects);

        if (cues.isEmpty) {
          // "We're hiring" with no other detail is a job opening.
          if (cue != null &&
              cue.$1 == GoalRole.offering &&
              tokens.sublist(cue.$2, cue.$3).contains('hiring')) {
            goals.add(
              Goal(
                type: ListingType.job,
                role: GoalRole.offering,
                subjects: _unique([...pending, ...clauseSubjects]),
              ),
            );
            lastGoal = goals.last;
            lastGoalIndex = goals.length - 1;
            pending = [];
            continue;
          }
          if (lastGoal != null && lastGoalIndex != null) {
            final updated = lastGoal.copyWith(
              subjects: _unique([...lastGoal.subjects, ...clauseSubjects]),
            );
            goals[lastGoalIndex] = updated;
            lastGoal = updated;
          } else {
            pending = [...pending, ...clauseSubjects];
          }
          continue;
        }

        // One goal per type; a specific cue ("assistant", "I can mentor")
        // outranks a generic one ("job", "mentor").
        final byType = <ListingType, _TypeCue>{};
        for (final c in cues) {
          final existing = byType[c.type];
          if (existing == null ||
              (existing.kind == _NounKind.opportunity &&
                  c.kind != _NounKind.opportunity)) {
            byType[c.type] = c;
          }
        }
        for (final c in byType.values) {
          final goal = Goal(
            type: c.type,
            role: _resolveRole(c, role ?? defaultRole),
            subjects: _unique([...pending, ...clauseSubjects]),
          );
          goals.add(goal);
          lastGoal = goal;
          lastGoalIndex = goals.length - 1;
        }
        pending = [];
      }
      context.addAll(pending);
    }

    final area = _findArea(trimmed);
    final remote = _findRemote(trimmed);

    final mergedGoals = _mergeGoals(goals);
    final keywords = _keywords(trimmed, consumed, area?.$2 ?? const {});

    return ParsedRequest(
      text: trimmed,
      goals: mergedGoals,
      keywords: keywords,
      contextTerms: _unique(context),
      skills: _unique(skills),
      interests: _unique(interests),
      areaId: area?.$1,
      remote: remote,
    );
  }

  // ---------------------------------------------------------------------
  // Segmentation

  Iterable<String> _sentences(String text) => text
      .split(RegExp(r'[.!?;\n]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);

  static const _separators = {'and', 'or', 'also', 'plus', 'but', '&'};

  List<_Clause> _clauses(String sentence) {
    final clauses = <_Clause>[];
    for (final part in sentence.split(RegExp(r'[,:()]'))) {
      final tokens = tokenize(part.replaceAll('&', ' and '));
      var current = <String>[];
      for (var i = 0; i < tokens.length; i++) {
        final t = tokens[i];
        final isAsWellAs =
            t == 'as' &&
            i + 2 < tokens.length &&
            tokens[i + 1] == 'well' &&
            tokens[i + 2] == 'as';
        if (_separators.contains(t) || isAsWellAs) {
          if (current.isNotEmpty) clauses.add(_Clause(current));
          current = <String>[];
          if (isAsWellAs) i += 2;
          continue;
        }
        current.add(t);
      }
      if (current.isNotEmpty) clauses.add(_Clause(current));
    }
    return clauses;
  }

  // ---------------------------------------------------------------------
  // Role cues

  static const _seekingCues = <List<String>>[
    ['in', 'search', 'of'],
    ['hoping', 'to', 'find'],
    ['hope', 'to', 'find'],
    ['trying', 'to', 'find'],
    ['looking', 'for'],
    ['look', 'for'],
    ['searching', 'for'],
    ['search', 'for'],
    ['would', 'like'],
    ["i'd", 'like'],
    ['looking', 'to'],
    ['seeking'],
    ['seek'],
    ['need'],
    ['needs'],
    ['want'],
    ['wants'],
    ['find'],
    ['finding'],
    ['hire'],
    ['hiring'],
  ];

  static const _offeringCues = <List<String>>[
    ["we're", 'hiring'],
    ['we', 'are', 'hiring'],
    ['now', 'hiring'],
    ['i', 'have', 'experience'],
    ['i', 'offer'],
    ['we', 'offer'],
    ['i', 'provide'],
    ['we', 'provide'],
    ['i', 'can'],
    ['we', 'can'],
    ['i', 'teach'],
    ['i', 'tutor'],
    ['i', 'mentor'],
    ['i', 'run'],
    ['we', 'run'],
    ['i', 'own'],
    ['we', 'own'],
    ['i', 'do'],
    ['i', 'specialize'],
    ['i', 'build'],
    ['i', 'make'],
    ['i', 'fix'],
    ['i', 'repair'],
    ['i', 'sell'],
    ['i', 'coach'],
    ['offering'],
    ['providing'],
    ['happy', 'to'],
    ['willing', 'to'],
    ['available', 'to'],
    ['available', 'for'],
    ['glad', 'to'],
    ['can', 'help'],
  ];

  /// Cues that only count after a first-person word ("I'd be happy to").
  static const _firstPersonOnly = {
    'happy',
    'willing',
    'available',
    'glad',
    'can',
    'offering',
    'providing',
  };

  static const _firstPerson = {
    'i',
    "i'm",
    'im',
    "i'd",
    'id',
    "i'll",
    "i've",
    'am',
    'we',
    "we're",
    "we'd",
    "we'll",
    'me',
  };

  /// Returns (role, startIndex, endIndex) of the earliest role cue.
  (GoalRole, int, int)? _findRoleCue(List<String> tokens) {
    (GoalRole, int, int)? best;
    void consider(List<String> cue, GoalRole role) {
      for (var i = 0; i + cue.length <= tokens.length; i++) {
        var ok = true;
        for (var j = 0; j < cue.length; j++) {
          if (tokens[i + j] != cue[j]) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        if (_firstPersonOnly.contains(cue.first) &&
            !_hasFirstPersonBefore(tokens, i)) {
          continue;
        }
        final candidate = (role, i, i + cue.length);
        if (best == null ||
            i < best!.$2 ||
            (i == best!.$2 && cue.length > best!.$3 - best!.$2)) {
          best = candidate;
        }
        break;
      }
    }

    for (final c in _offeringCues) {
      consider(c, GoalRole.offering);
    }
    for (final c in _seekingCues) {
      consider(c, GoalRole.seeking);
    }
    return best;
  }

  bool _hasFirstPersonBefore(List<String> tokens, int index) {
    for (var k = index - 1; k >= 0 && k >= index - 3; k--) {
      if (_firstPerson.contains(tokens[k])) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------
  // Type cues

  static const _studyWords = {
    'student',
    'students',
    'studying',
    'study',
    'studies',
    'major',
    'majoring',
    'graduate',
    'freshman',
    'sophomore',
    'junior',
    'senior',
  };

  static const _identityLead = [
    ['as', 'a'],
    ['as', 'an'],
    ['be', 'a'],
    ['be', 'an'],
    ["i'm", 'a'],
    ["i'm", 'an'],
    ['im', 'a'],
    ['im', 'an'],
    ['i', 'am', 'a'],
    ['i', 'am', 'an'],
    ['work', 'as'],
  ];

  bool _isIdentity(List<String> tokens, int index) {
    // Look back up to three tokens (allowing adjectives such as "a math tutor").
    for (var back = 1; back <= 4 && index - back >= 0; back++) {
      for (final lead in _identityLead) {
        final start = index - back - lead.length + 1;
        if (start < 0) continue;
        var ok = true;
        for (var j = 0; j < lead.length; j++) {
          if (tokens[start + j] != lead[j]) {
            ok = false;
            break;
          }
        }
        if (ok) return true;
      }
    }
    return false;
  }

  static const _desireVerbs = {
    'looking',
    'want',
    'wants',
    'like',
    'love',
    'hoping',
    'hope',
    'trying',
    'planning',
    'eager',
    'ready',
  };

  /// True when the word at [index] is used as a verb with the member as its
  /// subject: "I can mentor", "I'd like to mentor", "looking to volunteer".
  /// "Professionals willing to mentor" is not, because someone else mentors.
  bool _verbForm(List<String> tokens, int index) {
    if (index == 0) return false;
    final prev = tokens[index - 1];
    if (prev == 'i' || prev == 'we') return true;
    if (!{'to', 'can', 'will', "i'll", "we'll", 'could'}.contains(prev)) {
      return false;
    }
    if (prev == 'to' &&
        index >= 2 &&
        _desireVerbs.contains(tokens[index - 2])) {
      return true;
    }
    return _hasFirstPersonBefore(tokens, index - 1);
  }

  /// Finds opportunity words from [from] onward. Indices are absolute so
  /// look-backs can see the role phrase ("I'd like | to mentor").
  List<_TypeCue> _findTypeCues(
    List<String> tokens,
    List<String> stems,
    int from,
  ) {
    final cues = <_TypeCue>[];
    final used = <int>{};

    void add(ListingType type, _NounKind kind, int start, [int? end]) {
      final e = end ?? start + 1;
      for (var i = start; i < e; i++) {
        if (used.contains(i)) return;
      }
      for (var i = start; i < e; i++) {
        used.add(i);
      }
      cues.add(_TypeCue(type, kind, start, e));
    }

    bool phraseAt(int i, List<String> phrase) {
      if (i + phrase.length > tokens.length) return false;
      for (var j = 0; j < phrase.length; j++) {
        if (tokens[i + j] != phrase[j]) return false;
      }
      return true;
    }

    for (var i = from; i < tokens.length; i++) {
      final t = tokens[i];
      final s = stems[i];
      final next = i + 1 < tokens.length ? tokens[i + 1] : '';

      // Volunteering. "volunteers" / "a volunteer" are people being recruited.
      if (s == 'volunteer') {
        final verb = _verbForm(tokens, i);
        final identity = _isIdentity(tokens, i);
        final opportunityNext = {
          'opportunity',
          'opportunities',
          'work',
          'role',
          'roles',
          'position',
          'positions',
          'shift',
          'shifts',
        }.contains(next);
        _NounKind kind;
        if (verb || identity || t == 'volunteering' || opportunityNext) {
          kind = _NounKind.verbSeek;
        } else {
          kind = _NounKind.counterpart;
        }
        add(ListingType.volunteer, kind, i, opportunityNext ? i + 2 : i + 1);
        // "volunteer mentor": the following role noun describes the volunteer.
        for (var k = i + 1; k < tokens.length && k <= i + 3; k++) {
          if (_roleNouns.contains(stems[k])) used.add(k);
        }
        continue;
      }

      // Internships.
      if (s == 'internship' || t == 'co-op' || t == 'coop') {
        add(ListingType.internship, _NounKind.opportunity, i);
        continue;
      }
      if (s == 'intern') {
        final seeks = _verbForm(tokens, i) || _isIdentity(tokens, i);
        add(
          ListingType.internship,
          seeks ? _NounKind.verbSeek : _NounKind.counterpart,
          i,
        );
        continue;
      }

      // Mentorship.
      if (s == 'mentor' ||
          t == 'mentorship' ||
          s == 'guidance' ||
          s == 'advisor' ||
          s == 'adviser') {
        if (_verbForm(tokens, i) || _isIdentity(tokens, i)) {
          add(ListingType.mentorship, _NounKind.verbOffer, i);
        } else {
          add(ListingType.mentorship, _NounKind.opportunity, i);
        }
        continue;
      }
      if (s == 'mentee') {
        add(
          ListingType.mentorship,
          _isIdentity(tokens, i)
              ? _NounKind.opportunity
              : _NounKind.counterpart,
          i,
        );
        continue;
      }

      // Jobs.
      if (s == 'job' ||
          s == 'position' ||
          s == 'employment' ||
          s == 'gig' ||
          s == 'apprenticeship') {
        add(ListingType.job, _NounKind.opportunity, i);
        continue;
      }
      if (t == 'work' &&
          i > 0 &&
          {
            'for',
            'find',
            'some',
            'more',
            'freelance',
            'part-time',
            'full-time',
            'paid',
          }.contains(tokens[i - 1])) {
        add(ListingType.job, _NounKind.opportunity, i);
        continue;
      }
      if ({
            'employee',
            'staff',
            'worker',
            'assistant',
            'cashier',
            'apprentice',
            'hire',
          }.contains(s) &&
          !_isIdentity(tokens, i)) {
        add(ListingType.job, _NounKind.counterpart, i);
        continue;
      }
      if ({'employee', 'assistant', 'cashier', 'apprentice'}.contains(s)) {
        add(ListingType.job, _NounKind.verbSeek, i);
        continue;
      }

      // Collaboration.
      if ({
            'teammate',
            'cofounder',
            'co-founder',
            'collaborator',
            'collaboration',
            'collaborate',
          }.contains(s) ||
          phraseAt(i, ['team', 'members']) ||
          phraseAt(i, ['project', 'partner']) ||
          phraseAt(i, ['project', 'partners']) ||
          phraseAt(i, ['business', 'partner']) ||
          phraseAt(i, ['business', 'partners'])) {
        final span =
            (phraseAt(i, ['team', 'members']) ||
                phraseAt(i, ['project', 'partner']) ||
                phraseAt(i, ['project', 'partners']) ||
                phraseAt(i, ['business', 'partner']) ||
                phraseAt(i, ['business', 'partners']))
            ? 2
            : 1;
        final offer =
            _isIdentity(tokens, i) ||
            (s == 'collaborate' && _verbForm(tokens, i));
        add(
          ListingType.collaboration,
          offer ? _NounKind.verbOffer : _NounKind.opportunity,
          i,
          i + span,
        );
        continue;
      }
      if (t == 'join' &&
          i + 2 < tokens.length + 1 &&
          tokens
              .skip(i + 1)
              .take(3)
              .any(
                (w) => {
                  'project',
                  'team',
                  'startup',
                  'hackathon',
                }.contains(stem(w)),
              )) {
        add(ListingType.collaboration, _NounKind.verbOffer, i);
        continue;
      }

      // Local businesses.
      if (phraseAt(i, ['local', 'business']) ||
          phraseAt(i, ['local', 'businesses']) ||
          phraseAt(i, ['muslim-owned']) ||
          phraseAt(i, ['muslim', 'owned'])) {
        add(
          ListingType.business,
          _NounKind.opportunity,
          i,
          i + (tokens[i] == 'muslim-owned' ? 1 : 2),
        );
        continue;
      }
      if ({
            'businesses',
            'shop',
            'shops',
            'store',
            'stores',
            'restaurant',
            'restaurants',
            'grocery',
            'groceries',
            'butcher',
            'bakery',
            'bakeries',
          }.contains(t) ||
          ((t == 'business') &&
              i > 0 &&
              {'my', 'our'}.contains(tokens[i - 1]))) {
        add(ListingType.business, _NounKind.opportunity, i);
        continue;
      }

      // Services: providers, activities and "someone to …".
      if (_serviceProviders.contains(s)) {
        final identity = _isIdentity(tokens, i);
        final verb = (s == 'tutor' || s == 'coach') && _verbForm(tokens, i);
        add(
          ListingType.service,
          identity || verb ? _NounKind.verbOffer : _NounKind.opportunity,
          i,
        );
        continue;
      }
      if ({'teach', 'tutor'}.contains(t) && _verbForm(tokens, i)) {
        add(ListingType.service, _NounKind.verbOffer, i);
        continue;
      }
      if (_serviceActivities.contains(t) ||
          phraseAt(i, ['help', 'with']) ||
          phraseAt(i, ['someone', 'to']) ||
          phraseAt(i, ['somebody', 'to']) ||
          phraseAt(i, ['anyone', 'to'])) {
        final span = _serviceActivities.contains(t) ? 1 : 2;
        add(ListingType.service, _NounKind.opportunity, i, i + span);
        continue;
      }
      if ({'client', 'customer'}.contains(s)) {
        add(ListingType.service, _NounKind.counterpart, i);
        continue;
      }
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  static const _roleNouns = {
    'mentor',
    'tutor',
    'coach',
    'teacher',
    'helper',
    'driver',
    'photographer',
    'designer',
    'organizer',
    'instructor',
    'coordinator',
  };

  static const _serviceProviders = {
    'tutor',
    'designer',
    'photographer',
    'videographer',
    'plumber',
    'electrician',
    'accountant',
    'bookkeeper',
    'caterer',
    'cleaner',
    'babysitter',
    'nanny',
    'handyman',
    'contractor',
    'translator',
    'mechanic',
    'trainer',
    'editor',
    'consultant',
    'developer',
    'carpenter',
    'painter',
    'teacher',
    'coach',
    'instructor',
    'baker',
    'chef',
    'realtor',
    'lawyer',
    'technician',
    'landscaper',
    'mover',
  };

  /// Raw (unstemmed) words naming a service activity.
  static const _serviceActivities = {
    'tutoring',
    'catering',
    'photography',
    'repair',
    'repairs',
    'bookkeeping',
    'service',
    'services',
    'cleaning',
    'babysitting',
    'childcare',
    'lesson',
    'lessons',
    'class',
    'classes',
    'design',
    'plumbing',
    'wiring',
    'translation',
    'videography',
    'consulting',
    'taxes',
    'fix',
    'fixed',
    'broken',
    'install',
    'installation',
  };

  /// Seeking a counterpart ("interns", "volunteers") means offering the
  /// opportunity; verbs carry their own role; other nouns follow the clause.
  GoalRole _resolveRole(_TypeCue cue, GoalRole clauseRole) =>
      switch (cue.kind) {
        _NounKind.verbOffer => GoalRole.offering,
        _NounKind.verbSeek => GoalRole.seeking,
        _NounKind.counterpart => GoalRole.offering,
        _NounKind.opportunity => clauseRole,
      };

  // ---------------------------------------------------------------------
  // Interests and skills

  static const _interestCues = <List<String>>[
    ['interested', 'in'],
    ['interest', 'in'],
    ['interests', 'include'],
    ['passionate', 'about'],
    ['fascinated', 'by'],
    ['hobbies', 'include'],
    ['i', 'enjoy'],
    ['enjoy'],
    ['enjoys'],
    ['i', 'love'],
    ['i', 'like'],
    ["i'm", 'into'],
    ['im', 'into'],
  ];

  static const _skillCues = <List<String>>[
    ['experience', 'with'],
    ['experience', 'in'],
    ['experienced', 'in'],
    ['experienced', 'with'],
    ['skilled', 'in'],
    ['skilled', 'at'],
    ['good', 'at'],
    ['proficient', 'in'],
    ['familiar', 'with'],
    ['fluent', 'in'],
    ['certified', 'in'],
    ['i', 'know'],
    ['know', 'some'],
    ['background', 'in'],
  ];

  List<String>? _spanAfter(List<String> tokens, List<List<String>> cues) {
    for (var i = 0; i < tokens.length; i++) {
      for (final cue in cues) {
        if (i + cue.length > tokens.length) continue;
        var ok = true;
        for (var j = 0; j < cue.length; j++) {
          if (tokens[i + j] != cue[j]) {
            ok = false;
            break;
          }
        }
        if (ok) return tokens.sublist(i + cue.length);
      }
    }
    return null;
  }

  /// A short free-text phrase (at most three content words) taken verbatim.
  String? _freePhrase(List<String> span) {
    final words = span
        .where((w) => !stopwords.contains(w) && w.length > 1)
        .toList();
    if (words.isEmpty || words.length > 3) return null;
    return sentenceCase(words.join(' '));
  }

  List<String> _parseInterestList(String text) {
    final out = <String>[];
    for (final chunk in text.split(RegExp(r'[,;\n]|\band\b|&|/'))) {
      var tokens = tokenize(chunk);
      final lead = _spanAfter(tokens, _interestCues);
      if (lead != null) tokens = lead;
      if (tokens.isEmpty) continue;
      final found = Lexicon.findIn(tokens.join(' '));
      if (found.isNotEmpty) {
        out.addAll(found.map((t) => t.canonical));
        continue;
      }
      final free = _freePhrase(tokens);
      if (free != null) out.add(free);
    }
    return _unique(out);
  }

  // ---------------------------------------------------------------------
  // Location and remote

  static const _locationLeads = {
    'near',
    'in',
    'around',
    'by',
    'from',
    'at',
    'close',
    'within',
    'based',
    'live',
    'nearby',
  };

  /// Returns the first named Central Jersey area and the words that named it.
  /// Only place names count; institutions do not imply a location.
  (String, Set<String>)? _findArea(String text) {
    final padded = ' ${normalizeText(text)} ';
    final aliases = <(String, Area)>[
      for (final a in Areas.all)
        for (final alias in a.aliases) (alias, a),
    ]..sort((x, y) => y.$1.length.compareTo(x.$1.length));
    (int, String, Area)? first;
    for (final (alias, area) in aliases) {
      final idx = padded.indexOf(' $alias ');
      if (idx < 0) continue;
      // Skip an alias that is part of a longer, already-matched alias
      // ("brunswick" inside "east brunswick").
      if (first != null &&
          idx >= first.$1 &&
          idx < first.$1 + first.$2.length + 1) {
        continue;
      }
      if (first == null || idx < first.$1) first = (idx, alias, area);
    }
    if (first == null) return null;
    return (first.$3.id, first.$2.split(' ').toSet());
  }

  RemotePreference _findRemote(String text) {
    final n = ' ${normalizeText(text)} ';
    bool has(String p) => n.contains(' $p ');
    if (has('remote only') ||
        has('only remote') ||
        has('fully remote') ||
        has('100% remote') ||
        has('online only') ||
        has('only online')) {
      return RemotePreference.remoteOnly;
    }
    if (has('in person only') ||
        has('in-person only') ||
        has('only in person') ||
        has('only in-person') ||
        has('no remote')) {
      return RemotePreference.inPersonOnly;
    }
    if (has('remote') ||
        has('remotely') ||
        has('online') ||
        has('virtual') ||
        has('virtually') ||
        has('from home') ||
        has('anywhere')) {
      return RemotePreference.remoteOk;
    }
    return RemotePreference.unspecified;
  }

  // ---------------------------------------------------------------------
  // Keywords

  static const _structuralWords = {
    'remote',
    'remotely',
    'online',
    'virtual',
    'virtually',
    'person',
    'in-person',
    'only',
    'anywhere',
    'home',
    'summer',
    'fall',
    'spring',
    'winter',
    'weekend',
    'weekends',
    'student',
    'students',
  };

  static const _lowSignal = {
    'summer',
    'fall',
    'spring',
    'winter',
    'weekend',
    'weekends',
    'student',
    'students',
    'part-time',
    'full-time',
    'paid',
    'free',
  };

  List<SearchTerm> _keywords(
    String text,
    Set<String> consumed,
    Set<String> locationTokens,
  ) {
    final terms = <SearchTerm>[];
    final lexiconTokens = <String>{};
    for (final term in Lexicon.findIn(text)) {
      terms.add(
        SearchTerm(term.canonical, Lexicon.spellingsFor(term.canonical), 1),
      );
      for (final v in term.variants) {
        lexiconTokens.addAll(tokenize(v));
      }
    }
    for (final token in tokenize(text)) {
      if (stopwords.contains(token) || token.length < 3) continue;
      if (consumed.contains(token) || locationTokens.contains(token)) continue;
      if (lexiconTokens.contains(token)) continue;
      if (_locationLeads.contains(token)) continue;
      if (_studyWords.contains(token) && !_lowSignal.contains(token)) continue;
      if (_structuralWords.contains(token) && !_lowSignal.contains(token)) {
        continue;
      }
      final s = stem(token);
      final label = token;
      final weight = _lowSignal.contains(token) ? 0.3 : 0.5;
      final term = SearchTerm(label, [s], weight);
      if (!terms.any((t) => t.spellings.contains(s))) terms.add(term);
    }
    return terms;
  }

  // ---------------------------------------------------------------------
  // Helpers

  List<Goal> _mergeGoals(List<Goal> goals) {
    final merged = <Goal>[];
    for (final g in goals) {
      final idx = merged.indexWhere(
        (m) => m.type == g.type && m.role == g.role,
      );
      if (idx < 0) {
        merged.add(g);
      } else {
        merged[idx] = merged[idx].copyWith(
          subjects: _unique([...merged[idx].subjects, ...g.subjects]),
        );
      }
    }
    return merged;
  }

  String _summary(String text) {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length > 280 ? '${t.substring(0, 277)}...' : t;
  }
}

List<String> _unique(Iterable<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final i in items) {
    final key = i.toLowerCase();
    if (i.trim().isEmpty) continue;
    if (seen.add(key)) out.add(i);
  }
  return out;
}
