import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/domain/goal.dart';
import 'package:muslim_marketplace/src/domain/taxonomy.dart';
import 'package:muslim_marketplace/src/matching/intent_parser.dart';

void main() {
  const parser = DeterministicParser();

  Goal? goalOf(ParsedRequest r, ListingType type) {
    for (final g in r.goals) {
      if (g.type == type) return g;
    }
    return null;
  }

  group('search parsing', () {
    test('keeps distinct intents in the engineering student request', () {
      final r = parser.parseSearch(
        "I'm an engineering student looking for a robotics mentor and a "
        'summer internship near New Brunswick.',
      );
      final mentor = goalOf(r, ListingType.mentorship);
      final internship = goalOf(r, ListingType.internship);
      expect(mentor, isNotNull);
      expect(mentor!.role, GoalRole.seeking);
      expect(mentor.subjects, contains('Robotics'));
      expect(internship, isNotNull);
      expect(internship!.role, GoalRole.seeking);
      expect(r.goals, hasLength(2));
      expect(r.areaId, 'new-brunswick');
      // "engineering student" is self-description, not a skill.
      expect(r.skills, isEmpty);
      expect(r.contextTerms, contains('Engineering'));
      expect(
        r.keywords.map((k) => k.label),
        containsAll(['Robotics', 'Engineering']),
      );
    });

    test('seeking volunteers means offering a volunteer role', () {
      final r = parser.parseSearch(
        'We need volunteers for a youth robotics team',
      );
      final g = goalOf(r, ListingType.volunteer);
      expect(g, isNotNull);
      expect(g!.role, GoalRole.offering);
    });

    test('wanting to volunteer means seeking volunteer work', () {
      final r = parser.parseSearch('I want to volunteer with kids on weekends');
      final g = goalOf(r, ListingType.volunteer);
      expect(g!.role, GoalRole.seeking);
    });

    test('a volunteer mentor is a volunteer role, not mentorship', () {
      final r = parser.parseSearch('looking for a volunteer robotics mentor');
      expect(goalOf(r, ListingType.volunteer)?.role, GoalRole.offering);
      expect(goalOf(r, ListingType.mentorship), isNull);
    });

    test('first-person mentoring offers mentorship', () {
      final r = parser.parseSearch("I'd like to mentor students in robotics");
      expect(goalOf(r, ListingType.mentorship)?.role, GoalRole.offering);
    });

    test('professionals willing to mentor me is still seeking mentorship', () {
      final r = parser.parseSearch(
        "I'm looking for engineering internships, project teammates, and "
        'professionals willing to mentor students.',
      );
      expect(goalOf(r, ListingType.mentorship)?.role, GoalRole.seeking);
      expect(goalOf(r, ListingType.internship)?.role, GoalRole.seeking);
      expect(goalOf(r, ListingType.collaboration), isNotNull);
    });

    test(
      'hiring a tutor seeks a service; hiring an assistant offers a job',
      () {
        final tutor = parser.parseSearch('hire a calculus tutor in Edison');
        expect(goalOf(tutor, ListingType.service)?.role, GoalRole.seeking);
        expect(
          goalOf(tutor, ListingType.service)?.subjects,
          contains('Calculus'),
        );
        expect(tutor.areaId, 'edison');

        final job = parser.parseSearch('hiring a part-time office assistant');
        expect(goalOf(job, ListingType.job)?.role, GoalRole.offering);
      },
    );

    test('looking for interns offers an internship', () {
      final r = parser.parseSearch(
        'looking for interns for my engineering firm',
      );
      expect(goalOf(r, ListingType.internship)?.role, GoalRole.offering);
    });

    test('remote preferences', () {
      expect(
        parser.parseSearch('remote web development work').remote,
        RemotePreference.remoteOk,
      );
      expect(
        parser.parseSearch('tutoring, remote only').remote,
        RemotePreference.remoteOnly,
      );
      expect(
        parser.parseSearch('in person only tutoring').remote,
        RemotePreference.inPersonOnly,
      );
      expect(
        parser.parseSearch('math tutor').remote,
        RemotePreference.unspecified,
      );
    });

    test('longest place name wins', () {
      expect(
        parser.parseSearch('jobs in East Brunswick').areaId,
        'east-brunswick',
      );
      expect(
        parser.parseSearch('jobs near North Brunswick').areaId,
        'north-brunswick',
      );
    });

    test('a university name does not set a location', () {
      final r = parser.parseSearch(
        "I'm a Rutgers student looking for a mentor",
      );
      expect(r.areaId, isNull);
    });

    test('plain keywords produce no goals', () {
      final r = parser.parseSearch('robotics');
      expect(r.goals, isEmpty);
      expect(r.keywords.single.label, 'Robotics');
    });

    test('empty text is empty', () {
      expect(parser.parseSearch('   ').isEmpty, isTrue);
    });
  });

  group('profile extraction', () {
    test('extracts only what is stated (source example)', () {
      final e = parser.parseProfile(
        const OnboardingAnswers(
          seek:
              "I'm a Rutgers student studying engineering. I know some Python "
              'and enjoy robotics. I\'m looking for engineering internships, '
              'project teammates, and professionals willing to mentor students.',
        ),
      );
      expect(e.skills, ['Python']);
      expect(e.interests, ['Robotics']);
      expect(
        e.goals.map((g) => g.type),
        containsAll([
          ListingType.internship,
          ListingType.collaboration,
          ListingType.mentorship,
        ]),
      );
      expect(e.goals.every((g) => g.role == GoalRole.seeking), isTrue);
      // No location or offering is invented.
      expect(e.areaId, isNull);
      expect(e.openToRemote, isNull);
      expect(e.offeringSummary, isEmpty);
      expect(e.skills, isNot(contains('Embedded systems')));
      expect(e.skills, isNot(contains('Engineering')));
    });

    test('offer answer yields skills and offering goals', () {
      final e = parser.parseProfile(
        const OnboardingAnswers(
          offer: 'I can tutor high school math and physics, and I know Python.',
          seek: 'A robotics mentor and a summer engineering internship',
          interests: 'robotics, renewable energy, soccer',
          area: 'New Brunswick, open to remote',
        ),
      );
      expect(e.skills, containsAll(['Math', 'Physics', 'Python']));
      final service = e.goals.firstWhere((g) => g.type == ListingType.service);
      expect(service.role, GoalRole.offering);
      expect(service.subjects, containsAll(['Math', 'Physics']));
      final mentor = e.goals.firstWhere(
        (g) => g.type == ListingType.mentorship,
      );
      expect(mentor.role, GoalRole.seeking);
      expect(
        e.interests,
        containsAll(['Robotics', 'Renewable energy', 'Soccer']),
      );
      expect(e.areaId, 'new-brunswick');
      expect(e.openToRemote, isTrue);
    });

    test('study descriptions in the offer answer are not skills', () {
      final e = parser.parseProfile(
        const OnboardingAnswers(
          offer: "I'm an engineering student and I can help with Excel",
        ),
      );
      expect(e.skills, contains('Excel'));
      expect(e.skills, isNot(contains('Engineering')));
    });

    test('blank answers extract nothing', () {
      expect(parser.parseProfile(const OnboardingAnswers()).isEmpty, isTrue);
    });
  });
}
