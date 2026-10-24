import '../domain/taxonomy.dart';
import 'text.dart';

/// A recognised skill or subject with its spelling variants.
class LexiconTerm {
  const LexiconTerm(this.canonical, this.variants, [this.category]);

  /// Display form, e.g. "Python".
  final String canonical;

  /// Normalized spellings, single words or phrases, e.g. ["python"].
  final List<String> variants;
  final ListingCategory? category;
}

/// Vocabulary used by the deterministic parser. A term is only ever extracted
/// when one of its variants literally appears in the member's words.
abstract final class Lexicon {
  static const terms = <LexiconTerm>[
    // Technology
    LexiconTerm('Python', ['python'], ListingCategory.technology),
    LexiconTerm('JavaScript', [
      'javascript',
      'typescript',
    ], ListingCategory.technology),
    LexiconTerm('React', [
      'react',
      'reactjs',
      'react native',
    ], ListingCategory.technology),
    LexiconTerm('Flutter', ['flutter', 'dart'], ListingCategory.technology),
    LexiconTerm('Java', ['java'], ListingCategory.technology),
    LexiconTerm('C++', ['c++'], ListingCategory.technology),
    LexiconTerm('Web development', [
      'web development',
      'web developer',
      'website',
      'web design',
      'web app',
      'web apps',
      'wordpress',
    ], ListingCategory.technology),
    LexiconTerm('App development', [
      'app development',
      'mobile app',
      'mobile apps',
      'app developer',
      'ios app',
      'android app',
    ], ListingCategory.technology),
    LexiconTerm('Software engineering', [
      'software engineering',
      'software engineer',
      'software developer',
      'software development',
      'programming',
      'coding',
      'coder',
      'developer',
    ], ListingCategory.technology),
    LexiconTerm('Data analysis', [
      'data analysis',
      'data analytics',
      'data science',
      'data analyst',
      'sql',
    ], ListingCategory.technology),
    LexiconTerm('Machine learning', [
      'machine learning',
      'artificial intelligence',
      'ai',
    ], ListingCategory.technology),
    LexiconTerm('Cybersecurity', [
      'cybersecurity',
      'cyber security',
      'information security',
    ], ListingCategory.technology),
    LexiconTerm('IT support', [
      'it support',
      'tech support',
      'computer repair',
      'networking setup',
      'help desk',
    ], ListingCategory.technology),
    LexiconTerm('Excel', [
      'excel',
      'spreadsheet',
      'spreadsheets',
    ], ListingCategory.business),
    // Engineering & science
    LexiconTerm('Robotics', [
      'robotics',
      'robot',
      'robots',
      'first robotics',
    ], ListingCategory.engineering),
    LexiconTerm('CAD', [
      'cad',
      'solidworks',
      'autocad',
      'fusion 360',
    ], ListingCategory.engineering),
    LexiconTerm('Mechanical engineering', [
      'mechanical engineering',
      'mechanical engineer',
    ], ListingCategory.engineering),
    LexiconTerm('Electrical engineering', [
      'electrical engineering',
      'electrical engineer',
      'circuits',
      'embedded systems',
      'arduino',
    ], ListingCategory.engineering),
    LexiconTerm('Civil engineering', [
      'civil engineering',
      'civil engineer',
    ], ListingCategory.engineering),
    LexiconTerm('Engineering', [
      'engineering',
      'engineer',
      'engineers',
    ], ListingCategory.engineering),
    LexiconTerm('Renewable energy', [
      'renewable energy',
      'solar',
      'clean energy',
      'sustainability',
    ], ListingCategory.engineering),
    LexiconTerm('Physics', ['physics'], ListingCategory.education),
    LexiconTerm('Chemistry', [
      'chemistry',
      'organic chemistry',
    ], ListingCategory.education),
    LexiconTerm('Biology', ['biology'], ListingCategory.education),
    // Education
    LexiconTerm('Math', [
      'math',
      'maths',
      'mathematics',
      'algebra',
      'geometry',
      'precalculus',
      'statistics',
    ], ListingCategory.education),
    LexiconTerm('Calculus', [
      'calculus',
      'calc',
      'ap calc',
      'ap calculus',
    ], ListingCategory.education),
    LexiconTerm('SAT prep', [
      'sat',
      'sat prep',
      'test prep',
      'act prep',
    ], ListingCategory.education),
    LexiconTerm('Tutoring', [
      'tutoring',
      'tutor',
      'tutors',
      'homework help',
    ], ListingCategory.education),
    LexiconTerm('Quran', [
      'quran',
      "qur'an",
      'tajweed',
      'hifz',
      'quran recitation',
    ], ListingCategory.education),
    LexiconTerm('Arabic', ['arabic'], ListingCategory.education),
    LexiconTerm('Urdu', ['urdu'], ListingCategory.education),
    LexiconTerm('Islamic studies', [
      'islamic studies',
      'seerah',
      'fiqh',
    ], ListingCategory.education),
    LexiconTerm('Writing', [
      'writing',
      'writer',
      'writers',
      'copywriting',
      'essay',
      'essays',
      'blog',
      'journalism',
    ], ListingCategory.creative),
    LexiconTerm('Translation', [
      'translation',
      'translator',
      'interpreting',
      'interpreter',
    ], ListingCategory.other),
    // Business & careers
    LexiconTerm('Accounting', [
      'accounting',
      'accountant',
      'cpa',
    ], ListingCategory.business),
    LexiconTerm('Bookkeeping', [
      'bookkeeping',
      'bookkeeper',
      'quickbooks',
    ], ListingCategory.business),
    LexiconTerm('Tax preparation', [
      'tax preparation',
      'tax prep',
      'taxes',
      'tax return',
      'tax returns',
    ], ListingCategory.business),
    LexiconTerm('Finance', [
      'finance',
      'financial planning',
      'budgeting',
      'investing',
    ], ListingCategory.business),
    LexiconTerm('Marketing', [
      'marketing',
      'digital marketing',
      'seo',
    ], ListingCategory.business),
    LexiconTerm('Social media', [
      'social media',
      'instagram',
      'tiktok',
    ], ListingCategory.business),
    LexiconTerm('Small business', [
      'small business',
      'small businesses',
      'entrepreneurship',
      'entrepreneur',
      'entrepreneurs',
      'startup',
      'startups',
      'founder',
    ], ListingCategory.business),
    LexiconTerm('Administrative support', [
      'administrative',
      'admin assistant',
      'office assistant',
      'scheduling',
      'data entry',
    ], ListingCategory.business),
    LexiconTerm('Resume review', [
      'resume',
      'resumes',
      'cv',
      'cover letter',
    ], ListingCategory.careers),
    LexiconTerm('Interview prep', [
      'interview prep',
      'mock interview',
      'mock interviews',
      'interviewing',
    ], ListingCategory.careers),
    LexiconTerm('Career advice', [
      'career advice',
      'career guidance',
      'career coaching',
      'career coach',
      'career',
    ], ListingCategory.careers),
    LexiconTerm('Public speaking', [
      'public speaking',
      'presentation skills',
    ], ListingCategory.careers),
    LexiconTerm('Leadership', ['leadership'], ListingCategory.careers),
    // Creative
    LexiconTerm('Graphic design', [
      'graphic design',
      'graphic designer',
      'logo',
      'logos',
      'branding',
      'flyer',
      'flyers',
      'canva',
      'illustration',
    ], ListingCategory.creative),
    LexiconTerm('Photography', [
      'photography',
      'photographer',
      'photos',
      'photo',
    ], ListingCategory.creative),
    LexiconTerm('Video editing', [
      'video editing',
      'videography',
      'videographer',
      'video',
    ], ListingCategory.creative),
    // Health
    LexiconTerm('Fitness', [
      'fitness',
      'personal trainer',
      'workout',
      'gym',
    ], ListingCategory.health),
    LexiconTerm('Nutrition', [
      'nutrition',
      'nutritionist',
      'dietitian',
    ], ListingCategory.health),
    LexiconTerm('Counseling', [
      'counseling',
      'counselling',
      'counselor',
      'mental health',
    ], ListingCategory.health),
    LexiconTerm('Pre-med', [
      'pre-med',
      'premed',
      'medical school',
      'medicine',
      'nursing',
      'healthcare',
    ], ListingCategory.health),
    // Home
    LexiconTerm('Electrical work', [
      'electrician',
      'electrical',
      'wiring',
      'light fixtures',
      'outlets',
    ], ListingCategory.home),
    LexiconTerm('Plumbing', ['plumbing', 'plumber'], ListingCategory.home),
    LexiconTerm('Carpentry', [
      'carpentry',
      'carpenter',
      'woodworking',
    ], ListingCategory.home),
    LexiconTerm('Home repair', [
      'home repair',
      'home repairs',
      'repairs',
      'handyman',
      'renovation',
    ], ListingCategory.home),
    LexiconTerm('Childcare', [
      'childcare',
      'babysitting',
      'babysitter',
      'nanny',
    ], ListingCategory.home),
    LexiconTerm('Cleaning', [
      'cleaning',
      'cleaner',
      'house cleaning',
    ], ListingCategory.home),
    // Food
    LexiconTerm('Catering', [
      'catering',
      'caterer',
      'cater',
    ], ListingCategory.food),
    LexiconTerm('Baking', [
      'baking',
      'bakery',
      'baker',
      'pastries',
      'pastry',
      'bread',
      'cakes',
    ], ListingCategory.food),
    LexiconTerm('Cooking', [
      'cooking',
      'cook',
      'chef',
      'meal prep',
    ], ListingCategory.food),
    LexiconTerm('Halal food', ['halal'], ListingCategory.food),
    // Community
    LexiconTerm('Youth programs', [
      'youth',
      'kids',
      'children',
      'teens',
      'high school students',
    ], ListingCategory.community),
    LexiconTerm('Event planning', [
      'event planning',
      'events',
      'event',
    ], ListingCategory.community),
    LexiconTerm('Food pantry', [
      'food pantry',
      'food drive',
      'food bank',
    ], ListingCategory.community),
    LexiconTerm('STEM education', ['stem'], ListingCategory.education),
    LexiconTerm('Hackathons', [
      'hackathon',
      'hackathons',
    ], ListingCategory.technology),
  ];

  static final List<(String, LexiconTerm)> _variantIndex = () {
    final entries = <(String, LexiconTerm)>[
      for (final term in terms)
        for (final v in term.variants) (stemmedText(v), term),
    ];
    // Longest phrases first so "software engineering" wins over "engineering".
    entries.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return entries;
  }();

  /// Terms whose variants appear in [text], longest match first. Each match
  /// consumes its words so "software engineering" does not also yield
  /// "Engineering".
  static List<LexiconTerm> findIn(String text) =>
      findSpans(text).map((s) => s.term).toList();

  /// Like [findIn] but also returns the matched token span.
  static List<LexiconMatch> findSpans(String text) {
    final stems = tokenize(text).map(stem).toList();
    if (stems.isEmpty) return const [];
    final used = List<bool>.filled(stems.length, false);
    final matches = <LexiconMatch>[];
    final seen = <String>{};
    for (final (variant, term) in _variantIndex) {
      final parts = variant.split(' ');
      for (var i = 0; i + parts.length <= stems.length; i++) {
        var ok = true;
        for (var j = 0; j < parts.length; j++) {
          if (used[i + j] || stems[i + j] != parts[j]) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        for (var j = 0; j < parts.length; j++) {
          used[i + j] = true;
        }
        if (seen.add(term.canonical)) {
          matches.add(LexiconMatch(term, i, i + parts.length));
        }
      }
    }
    matches.sort((a, b) => a.start.compareTo(b.start));
    return matches;
  }

  static LexiconTerm? byCanonical(String value) {
    final key = value.trim().toLowerCase();
    for (final t in terms) {
      if (t.canonical.toLowerCase() == key) return t;
    }
    return null;
  }

  /// All stemmed spellings for a term or free-text subject, used by the ranker.
  static List<String> spellingsFor(String subject) {
    final term = byCanonical(subject);
    if (term != null) {
      return {
        for (final v in [term.canonical, ...term.variants]) stemmedText(v),
      }.where((s) => s.isNotEmpty).toList();
    }
    final s = stemmedText(subject);
    return s.isEmpty ? const [] : [s];
  }

  /// Keywords that hint at a category, for the create-listing form's
  /// suggestion and for weak category matching.
  static ListingCategory? suggestCategory(String text) {
    final counts = <ListingCategory, int>{};
    for (final term in findIn(text)) {
      final c = term.category;
      if (c != null) counts[c] = (counts[c] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }
}

class LexiconMatch {
  const LexiconMatch(this.term, this.start, this.end);
  final LexiconTerm term;
  final int start;
  final int end;
}
