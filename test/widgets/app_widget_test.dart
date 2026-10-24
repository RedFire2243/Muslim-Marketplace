import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/data/errors.dart';
import 'package:muslim_marketplace/src/data/key_value_store.dart';
import 'package:muslim_marketplace/src/data/seed/seed_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslim_marketplace/src/ui/theme.dart';
import 'package:muslim_marketplace/src/ui/widgets/common.dart';

import 'harness.dart';

void main() {
  testWidgets('welcome offers the demo and explains why accounts are off', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Try the demo'), findsOneWidget);
    expect(find.textContaining('fictional members'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Accounts aren’t available here'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Try the demo'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Salaam! What should we call you?'), findsOneWidget);
  });

  testWidgets('onboarding keeps answers when going back and after a restart', (
    tester,
  ) async {
    final store = MemoryStore();
    await pumpApp(tester, store: store);
    await tester.tap(find.text('Try the demo'));
    await tester.pumpAndSettle();

    // A name is required.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Add the name other members will see.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Test Member');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'I can tutor high school math.',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A robotics mentor');

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('I can tutor high school math.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('A robotics mentor'), findsOneWidget);

    // Restart: the draft is restored from storage.
    await pumpApp(tester, store: store);
    expect(find.text('A robotics mentor'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'robotics, soccer');
    await tester.enterText(find.byType(TextField).last, 'New Brunswick');
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Here’s what we picked up'), findsOneWidget);
    expect(find.text('Looking for a mentor · Robotics'), findsOneWidget);
    expect(find.text('Offering a service · Tutoring, Math'), findsOneWidget);
    expect(find.text('List me in the member directory'), findsOneWidget);

    await tester.tap(find.text('Save and see matches'));
    await tester.pumpAndSettle();
    expect(find.text('Salaam, Test'), findsOneWidget);
    expect(find.text('Robotics mentorship for students'), findsWidgets);
  });

  testWidgets('posting validates required fields, then publishes', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: desktop);
    await enterAs(tester, c, SeedIds.amina);
    await goTo(tester, c, '/post');

    await tester.ensureVisible(find.text('Publish listing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish listing'));
    await tester.pumpAndSettle();
    expect(find.text('Please fix the 6 highlighted fields.'), findsOneWidget);
    expect(find.text('Choose what kind of listing this is.'), findsOneWidget);
    expect(find.text('Add a short title.'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Service'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offering a service'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Python help for beginners',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      'Friendly one-hour sessions to get you started with Python basics.',
    );
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Technology & software').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Can be done remotely'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Can be done remotely'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Publish listing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish listing'));
    await tester.pumpAndSettle();

    expect(
      find.text('Listing published. Members can now find it.'),
      findsOneWidget,
    );
    expect(find.text('Python help for beginners'), findsOneWidget);
    expect(find.text('Your listing'), findsOneWidget);
  });

  testWidgets('phones use a bottom bar; wide screens use a side rail', (
    tester,
  ) async {
    var c = await pumpApp(tester);
    await enterAs(tester, c, SeedIds.amina);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Listings you’ve kept for later. Only you can see this list.'),
      findsOneWidget,
    );

    c = await pumpApp(tester, size: desktop);
    await enterAs(tester, c, SeedIds.amina);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Post an opportunity'), findsWidgets);
    // Demo controls are reachable from the banner.
    expect(find.text('Switch member'), findsOneWidget);
  });

  testWidgets('a failed message shows its state and can be retried', (
    tester,
  ) async {
    final c = await pumpApp(tester);
    await enterAs(tester, c, SeedIds.amina);
    (await demoOf(c)).failNextMessageSends = 1;
    await goTo(tester, c, '/inbox/chat/${SeedIds.conversation(1)}');

    await tester.enterText(
      find.widgetWithText(TextField, 'Write a message'),
      'See you Thursday',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Not sent'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Not sent'), findsNothing);
    expect(find.text('See you Thursday'), findsOneWidget);
  });

  testWidgets('an unrelated member cannot open a private conversation', (
    tester,
  ) async {
    final c = await pumpApp(tester);
    await enterAs(tester, c, SeedIds.sarah);
    await goTo(tester, c, '/inbox/chat/${SeedIds.conversation(1)}');
    expect(find.text('This conversation is private'), findsOneWidget);
    expect(find.textContaining('CAD files'), findsNothing);
  });

  testWidgets('search explains intents and finds no fabricated results', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: desktop);
    await enterAs(tester, c, SeedIds.zaid);
    await tester.enterText(
      find.byType(TextField).first,
      'robotics mentor and a summer internship',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('We found 2 things you’re looking for'), findsOneWidget);
    expect(find.text('Robotics mentorship for students'), findsOneWidget);
    expect(
      find.text('Seeking a robotics mentor for my senior design project'),
      findsNothing,
    );

    await tester.enterText(
      find.byType(TextField).first,
      'quantum basket weaving',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('No listings match that yet'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);
  });

  testWidgets('withdrawing from the directory removes you from member search', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: desktop);
    await enterAs(tester, c, SeedIds.zaid);
    Future<void> search() async {
      await goTo(tester, c, '/');
      await tester.enterText(
        find.byType(TextField).first,
        'looking for a robotics mentor',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    await search();
    expect(find.text('Members who might help'), findsOneWidget);
    expect(find.text('Yusuf Karim'), findsWidgets);
    final countBefore = find.text('Yusuf Karim').evaluate().length;

    final demo = await demoOf(c);
    await demo.switchTo(SeedIds.yusuf);
    await demo.profiles.updateSettings(directoryVisible: false);
    await demo.switchTo(SeedIds.zaid);
    await tester.pumpAndSettle();

    await search();
    // Still listed as the owner of an active listing, but not as a directory match.
    expect(find.text('Yusuf Karim').evaluate().length, lessThan(countBefore));
  });

  testWidgets('error states offer a retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: AsyncView<int>(
            value: const AsyncError(NetworkException(), StackTrace.empty),
            onRetry: () => retried = true,
            data: (_) => const SizedBox(),
          ),
        ),
      ),
    );
    expect(find.text('That didn’t load'), findsOneWidget);
    expect(find.textContaining('couldn’t reach the server'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  for (final size in [phone, desktop]) {
    testWidgets('large text does not overflow (${size.width.toInt()} wide)', (
      tester,
    ) async {
      final c = await pumpApp(tester, size: size, textScale: 2);
      await enterAs(tester, c, SeedIds.amina);
      for (final location in [
        '/',
        '/listing/${SeedIds.listing(1)}',
        '/saved',
        '/inbox',
        '/inbox/chat/${SeedIds.conversation(1)}',
        '/profile',
        '/profile/settings',
        '/profile/edit',
        '/post',
      ]) {
        await goTo(tester, c, location);
        expect(tester.takeException(), isNull, reason: location);
      }
    });
  }
}
