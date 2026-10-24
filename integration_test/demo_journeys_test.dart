// End-to-end journeys in demo mode, driven through the interface with real
// device storage.
//
//   flutter test integration_test/demo_journeys_test.dart -d macos
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:muslim_marketplace/src/data/seed/seed_data.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(freshInstall);

  testWidgets(
    '1. onboard, search, inspect a match, save it, and keep it after restart',
    (tester) async {
      await launchApp(tester);
      await tapText(tester, 'Try the demo');
      await completeOnboarding(
        tester,
        name: 'Journey Tester',
        offer: 'I can tutor high school math.',
        seek: 'A robotics mentor and a summer engineering internship.',
        interests: 'robotics, soccer',
        area: 'New Brunswick',
      );
      expect(find.text('Looking for a mentor · Robotics'), findsOneWidget);
      expect(
        find.text('Looking for an internship · Engineering'),
        findsOneWidget,
      );
      await tapText(tester, 'Save and see matches');
      await waitFor(tester, find.text('Salaam, Journey'));

      await search(
        tester,
        "I'm an engineering student looking for a robotics mentor and a summer internship near New Brunswick.",
      );
      expect(find.text('We found 2 things you’re looking for'), findsOneWidget);
      expect(
        find.text('Seeking a robotics mentor for my senior design project'),
        findsNothing,
      );

      await tapText(tester, 'Robotics mentorship for students');
      await waitFor(tester, find.text('Why this might fit you'));
      expect(
        find.text('Offers mentorship, which you’re looking for'),
        findsOneWidget,
      );
      await tapText(tester, 'Save for later');
      await waitFor(tester, find.text('Saved'));

      await restartApp(tester);
      await waitFor(tester, find.text('Salaam, Journey'));
      await go(tester, '/saved');
      await waitFor(tester, find.text('Robotics mentorship for students'));
    },
  );

  testWidgets('2. create, edit, and close a listing', (tester) async {
    await launchApp(tester);
    await tapText(tester, 'Explore as a sample member');
    await waitFor(tester, find.text('Salaam, Amina'));
    await go(tester, '/post');
    await publishListing(
      tester,
      title: 'CAD basics for robotics teams',
      description:
          'Two short sessions on modelling robot parts in CAD for student teams.',
    );
    expect(find.text('CAD basics for robotics teams'), findsOneWidget);

    await tapText(tester, 'Edit listing');
    await typeInto(
      tester,
      fieldLabelled('Title'),
      'CAD workshop for robotics teams',
    );
    await tapText(tester, 'Save changes');
    await waitFor(tester, find.text('CAD workshop for robotics teams'));

    await tapText(tester, 'Close listing');
    await tapOn(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Close listing'),
      ),
    );
    await waitFor(
      tester,
      find.text('This listing is closed and no longer accepting requests.'),
    );
    expect(find.text('Edit listing'), findsNothing);

    await go(tester, '/profile/listings');
    await waitFor(tester, find.text('Closed'));
  });

  testWidgets(
    '3. request, switch members, accept, message, and keep it after restart',
    (tester) async {
      await launchApp(tester);
      await tapText(tester, 'Explore as a sample member');
      await waitFor(tester, find.text('Salaam, Amina'));
      await switchMember(tester, 'Zaid Mansour');

      await go(tester, '/listing/${SeedIds.listing(1)}');
      await tapText(tester, 'Request to connect');
      await typeInto(
        tester,
        fieldLabelled('Message'),
        'Salaam! Could you help with my robotics club?',
      );
      await tapText(tester, 'Send request');
      await waitFor(tester, find.text('Request pending'));

      await switchMember(tester, 'Yusuf Karim');
      await go(tester, '/inbox');
      await tapText(tester, 'Requests');
      await waitFor(tester, find.text('Zaid Mansour'));
      await tapOn(tester, find.widgetWithText(FilledButton, 'Accept'));
      await waitFor(tester, find.text('You’re connected'));
      await typeInto(
        tester,
        fieldLabelled('Write a message'),
        'Happy to help, Zaid!',
      );
      await tapOn(tester, find.byTooltip('Send message'));
      await waitFor(tester, find.text('Happy to help, Zaid!'));

      await switchMember(tester, 'Zaid Mansour');
      await go(tester, '/inbox');
      await tapText(tester, 'Messages');
      await tapText(tester, 'Yusuf Karim');
      await waitFor(tester, find.text('Happy to help, Zaid!'));
      await typeInto(
        tester,
        fieldLabelled('Write a message'),
        'JazakAllah khair!',
      );
      await tapOn(tester, find.byTooltip('Send message'));
      await waitFor(tester, find.text('JazakAllah khair!'));

      await restartApp(tester);
      await go(tester, '/inbox');
      await tapText(tester, 'Messages');
      await tapText(tester, 'Yusuf Karim');
      await waitFor(tester, find.text('Happy to help, Zaid!'));
      expect(find.text('JazakAllah khair!'), findsOneWidget);
    },
  );

  testWidgets('4. an unrelated member cannot open a conversation', (
    tester,
  ) async {
    await launchApp(tester);
    await tapText(tester, 'Explore as a sample member');
    await waitFor(tester, find.text('Salaam, Amina'));
    // Amina can read her conversation with Yusuf.
    await go(tester, '/inbox/chat/${SeedIds.conversation(1)}');
    await waitFor(tester, find.textContaining('CAD files'));

    await switchMember(tester, 'Sarah Ahmed');
    await go(tester, '/inbox/chat/${SeedIds.conversation(1)}');
    await waitFor(tester, find.text('This conversation is private'));
    expect(find.textContaining('CAD files'), findsNothing);
  });

  testWidgets('5. leaving the directory changes what others discover', (
    tester,
  ) async {
    await launchApp(tester);
    await tapText(tester, 'Explore as a sample member');
    await waitFor(tester, find.text('Salaam, Amina'));
    await switchMember(tester, 'Zaid Mansour');

    await search(tester, 'looking for a robotics mentor');
    await waitFor(tester, find.text('Members who might help'));
    final before = find.text('Yusuf Karim').evaluate().length;
    expect(before, greaterThanOrEqualTo(2)); // listing owner + directory card

    await switchMember(tester, 'Yusuf Karim');
    await go(tester, '/profile/settings');
    await tapText(tester, 'List me in the member directory');
    await waitFor(tester, find.text('You’ve left the directory'));

    await switchMember(tester, 'Zaid Mansour');
    await search(tester, 'looking for a robotics mentor');
    await waitFor(tester, find.text('Robotics mentorship for students'));
    expect(find.text('Yusuf Karim').evaluate().length, before - 1);
  });
}
