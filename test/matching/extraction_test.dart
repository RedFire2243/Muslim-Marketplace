import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/domain/goal.dart';
import 'package:muslim_marketplace/src/domain/taxonomy.dart';
import 'package:muslim_marketplace/src/matching/extraction.dart';
import 'package:muslim_marketplace/src/matching/intent_parser.dart';

class FakeRemote implements RemoteExtractionClient {
  FakeRemote(this.respond);
  final Future<Object?> Function() respond;
  int calls = 0;

  @override
  Future<Object?> requestExtraction(OnboardingAnswers answers) {
    calls++;
    return respond();
  }
}

const answers = OnboardingAnswers(
  offer: 'I can tutor high school math.',
  seek: 'A robotics mentor and a summer internship.',
  interests: 'robotics, soccer',
  area: 'New Brunswick',
);

void main() {
  test('valid AI output is used, grounded, and merged with rules', () async {
    final ai = AiProfileExtractor(
      FakeRemote(
        () async => {
          'skills': ['Math', 'Tutoring'],
          'interests': ['Robotics'],
          'goals': [
            {
              'type': 'mentorship',
              'role': 'seeking',
              'subjects': ['Robotics'],
            },
            {'type': 'internship', 'role': 'seeking', 'subjects': []},
          ],
          'area': 'New Brunswick',
        },
      ),
    );
    final out = await ai.extract(answers);
    expect(out.source, ExtractionSource.ai);
    expect(out.extraction.skills, containsAll(['Math', 'Tutoring']));
    expect(out.extraction.areaId, 'new-brunswick');
    expect(
      out.extraction.goals.any(
        (g) => g.type == ListingType.mentorship && g.role == GoalRole.seeking,
      ),
      isTrue,
    );
  });

  test('invented values are dropped', () async {
    final ai = AiProfileExtractor(
      FakeRemote(
        () async => {
          'skills': ['Math', 'Embedded systems', 'Leadership'],
          'interests': ['Robotics', 'Quantum computing'],
          'goals': [
            {
              'type': 'mentorship',
              'role': 'seeking',
              'subjects': ['Robotics', 'Machine learning'],
            },
            {'type': 'spaceflight', 'role': 'seeking'},
          ],
          'area': 'Princeton',
        },
      ),
    );
    final out = await ai.extract(answers);
    expect(out.extraction.skills, isNot(contains('Embedded systems')));
    expect(out.extraction.skills, isNot(contains('Leadership')));
    expect(out.extraction.interests, isNot(contains('Quantum computing')));
    final mentor = out.extraction.goals.firstWhere(
      (g) => g.type == ListingType.mentorship,
    );
    expect(mentor.subjects, isNot(contains('Machine learning')));
    // An area the member never named is not accepted.
    expect(out.extraction.areaId, 'new-brunswick');
  });

  test('timeouts fall back to the rule-based parser', () async {
    final ai = AiProfileExtractor(
      FakeRemote(() => Completer<Object?>().future),
      timeout: const Duration(milliseconds: 20),
    );
    final out = await ai.extract(answers);
    expect(out.source, ExtractionSource.rules);
    expect(out.fallbackReason, FallbackReason.timeout);
    expect(out.extraction.skills, contains('Math'));
  });

  test('malformed responses fall back', () async {
    for (final bad in <Object?>[
      'not json',
      42,
      null,
      {'skills': 'Math'},
      {'goals': 'oops'},
    ]) {
      final out = await AiProfileExtractor(
        FakeRemote(() async => bad),
      ).extract(answers);
      expect(out.source, ExtractionSource.rules, reason: '$bad');
      expect(out.fallbackReason, FallbackReason.malformed, reason: '$bad');
    }
  });

  test('unavailable service falls back', () async {
    final out = await AiProfileExtractor(
      FakeRemote(() async => throw StateError('503')),
    ).extract(answers);
    expect(out.source, ExtractionSource.rules);
    expect(out.fallbackReason, FallbackReason.unavailable);
    expect(out.extraction.goals, isNotEmpty);
  });

  test('blank answers never call the service', () async {
    final remote = FakeRemote(() async => {});
    final out = await AiProfileExtractor(
      remote,
    ).extract(const OnboardingAnswers());
    expect(remote.calls, 0);
    expect(out.extraction.isEmpty, isTrue);
  });

  test('grounding check', () {
    expect(isGrounded('Python', 'I know some python'), isTrue);
    expect(isGrounded('Math', 'I teach algebra'), isTrue); // known spelling
    expect(isGrounded('Embedded systems', 'I enjoy robotics'), isFalse);
    expect(isGrounded('', 'anything'), isFalse);
  });

  test('rules extractor is the demo default', () async {
    final out = await const RulesExtractor().extract(answers);
    expect(out.source, ExtractionSource.rules);
    expect(out.extraction.interests, containsAll(['Robotics', 'Soccer']));
  });
}
