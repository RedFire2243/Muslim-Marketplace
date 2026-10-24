import '../domain/goal.dart';
import '../domain/profile.dart';
import 'intent_parser.dart';
import 'lexicon.dart';
import 'text.dart';

class MemberMatch {
  const MemberMatch(this.member, this.score, this.reason);
  final MemberProfile member;
  final double score;
  final String reason;
}

/// Finds directory members whose own words fit a search. Members who did not
/// opt into the directory are never passed in. Role-aware: when the searcher
/// seeks something, members are matched on what they offer; when the
/// searcher offers something, on what members seek.
class MemberMatcher {
  const MemberMatcher();

  List<MemberMatch> rank(
    List<MemberProfile> members,
    ParsedRequest parsed, {
    int limit = 6,
  }) {
    if (parsed.goals.isEmpty && parsed.keywords.isEmpty) return const [];
    final seeking =
        parsed.goals.isEmpty ||
        parsed.goals.any((g) => g.role == GoalRole.seeking);
    final offering = parsed.goals.any((g) => g.role == GoalRole.offering);
    final subjects = {for (final g in parsed.goals) ...g.subjects};
    final out = <MemberMatch>[];
    for (final m in members) {
      final d = m.details;
      if (d == null) continue;
      // Only what the member says they offer; a headline describes them.
      final offerText = stemmedText(
        [d.offeringSummary, ...d.skills].join(' . '),
      );
      final seekText = stemmedText(d.seekingSummary);
      final hits = <String>{};
      var side = '';
      void check(String text, String label) {
        for (final s in subjects) {
          if (Lexicon.spellingsFor(s).any((sp) => containsPhrase(text, sp))) {
            hits.add(s.toLowerCase());
            side = label;
          }
        }
        for (final k in parsed.keywords) {
          if (k.weight < 0.5) continue;
          if (k.spellings.any((sp) => containsPhrase(text, sp))) {
            hits.add(k.label.toLowerCase());
            side = label;
          }
        }
      }

      if (seeking) check(offerText, 'Offers');
      if (offering) check(seekText, 'Looking for');
      if (hits.isEmpty) continue;
      out.add(
        MemberMatch(
          m,
          hits.length.toDouble(),
          '$side ${hits.take(3).join(', ')}',
        ),
      );
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.member.displayName.compareTo(b.member.displayName);
    });
    return out.take(limit).toList();
  }
}
