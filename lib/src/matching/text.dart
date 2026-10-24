/// Text normalization shared by the parser, the extraction validator and the
/// ranker. Pure Dart; no Flutter imports.
library;

final _apostrophes = RegExp('[‘’ʼ`]');
final _nonWord = RegExp(r"[^a-z0-9+#'\-\s]");
final _spaces = RegExp(r'\s+');

/// Lowercases, unifies apostrophes, strips punctuation and collapses spaces.
String normalizeText(String input) {
  final lower = input.toLowerCase().replaceAll(_apostrophes, "'");
  final cleaned = lower
      .replaceAll(RegExp(r'[–—/]'), ' ')
      .replaceAll(_nonWord, ' ')
      .replaceAll(RegExp(r"(^|\s)'+|'+(\s|$)"), ' ')
      .replaceAll(RegExp(r'(^|\s)-+|-+(\s|$)'), ' ');
  return cleaned.replaceAll(_spaces, ' ').trim();
}

/// Splits normalized text into tokens.
List<String> tokenize(String input) {
  final normalized = normalizeText(input);
  if (normalized.isEmpty) return const [];
  return normalized.split(' ');
}

const _keepS = {
  'physics',
  'mathematics',
  'economics',
  'robotics',
  'electronics',
  'analytics',
  'graphics',
  'logistics',
  'ethics',
  'athletics',
  'news',
  'business',
  'class',
  'gas',
  'is',
  'us',
  'this',
  'his',
  'has',
  'was',
  'yes',
  'plus',
  'status',
  'campus',
  'bus',
  'canvas',
  'chess',
  'process',
  'less',
  'access',
  'success',
  'fitness',
  'wellness',
  'series',
  'cs',
  'sats',
  'aws',
  'ios',
  'js',
  'maths',
  'texas',
  'kids',
};

/// A deliberately light stemmer so "mentors", "mentoring" and "mentor"
/// compare equal without mangling domain words like "physics".
String stem(String token) {
  var t = token;
  if (t.endsWith("'s")) t = t.substring(0, t.length - 2);
  t = t.replaceAll("'", '');
  if (t.length <= 3 || _keepS.contains(t)) return t;
  if (t.endsWith('ies') && t.length > 4) {
    return '${t.substring(0, t.length - 3)}y';
  }
  if (t.endsWith('sses')) return t.substring(0, t.length - 2);
  if (t.endsWith('ing') && t.length >= 7) {
    var base = t.substring(0, t.length - 3);
    if (base.length > 3 &&
        base[base.length - 1] == base[base.length - 2] &&
        !'lsz'.contains(base[base.length - 1])) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }
  if (t.endsWith('s') &&
      !t.endsWith('ss') &&
      !t.endsWith('us') &&
      !t.endsWith('is')) {
    return t.substring(0, t.length - 1);
  }
  return t;
}

/// Common words that carry no matching signal.
const stopwords = {
  'a',
  'about',
  'after',
  'again',
  'all',
  'also',
  'am',
  'an',
  'and',
  'any',
  'are',
  'around',
  'as',
  'at',
  'be',
  'been',
  'being',
  'both',
  'but',
  'by',
  'can',
  'could',
  'did',
  'do',
  'does',
  'doing',
  'for',
  'from',
  'get',
  'getting',
  'had',
  'has',
  'have',
  'having',
  'he',
  'her',
  'here',
  'him',
  'his',
  'how',
  'i',
  "i'd",
  "i'll",
  "i'm",
  "i've",
  'if',
  'in',
  'into',
  'is',
  'it',
  "it's",
  'its',
  'just',
  'like',
  'looking',
  'me',
  'more',
  'most',
  'my',
  'near',
  'need',
  'needs',
  'needed',
  'nearby',
  'no',
  'not',
  'now',
  'of',
  'on',
  'one',
  'or',
  'other',
  'our',
  'out',
  'over',
  'please',
  'really',
  'seek',
  'seeking',
  'she',
  'so',
  'some',
  'someone',
  'something',
  'such',
  'than',
  'that',
  'the',
  'their',
  'them',
  'then',
  'there',
  'these',
  'they',
  'this',
  'those',
  'through',
  'to',
  'too',
  'up',
  'us',
  'very',
  'want',
  'wanting',
  'was',
  'we',
  "we're",
  'were',
  'what',
  'when',
  'where',
  'which',
  'who',
  'will',
  'with',
  'within',
  'would',
  'you',
  'your',
  'find',
  'finding',
  'search',
  'searching',
  'hoping',
  'hope',
  'help',
  'im',
  'id',
  'ive',
  'able',
  'anyone',
  'interested',
  'willing',
  'happy',
  'available',
  'great',
  'good',
  'love',
  'enjoy',
  'know',
  'etc',
  'thing',
  'things',
  'lot',
  'lots',
  'bit',
  'new',
  'area',
  'local',
  'community',
  'person',
  'people',
  'opportunity',
  'opportunities',
  'offer',
  'offering',
  'offers',
  'provide',
  'providing',
};

/// Tokens worth matching: normalized, stemmed, without stopwords.
List<String> contentStems(String input) => [
  for (final t in tokenize(input))
    if (!stopwords.contains(t) && t.length > 1) stem(t),
];

/// True when [phrase] (normalized) appears in [haystack] (normalized) on
/// word boundaries.
bool containsPhrase(String haystackNormalized, String phraseNormalized) {
  if (phraseNormalized.isEmpty) return false;
  final h = ' $haystackNormalized ';
  return h.contains(' $phraseNormalized ');
}

/// Normalized text with every token stemmed, for phrase checks that ignore
/// plural and -ing endings.
String stemmedText(String input) => tokenize(input).map(stem).join(' ');

/// Title-cases free text for display ("renewable energy" -> "Renewable energy").
String sentenceCase(String s) {
  final t = s.trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1);
}
