// The core multi-user journey in connected mode, driven through the
// interface against a real backend (local Supabase or a test project).
//
//   supabase start && supabase db reset
//   flutter test integration_test/connected_journey_test.dart -d macos \
//     --dart-define-from-file=config/local.json
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:muslim_marketplace/src/config/app_config.dart';
import 'package:muslim_marketplace/src/state/data_providers.dart';

import 'helpers.dart';

final runId = DateTime.now().millisecondsSinceEpoch;
const password = 'integration-test-password';
String emailFor(String who) => '$who.$runId@example.test';

Future<void> signUp(WidgetTester tester, String name, String who) async {
  await go(tester, '/welcome');
  await tapText(tester, 'Create an account');
  await typeInto(tester, fieldLabelled('Your name'), name);
  await typeInto(tester, fieldLabelled('Email'), emailFor(who));
  await typeInto(tester, fieldLabelled('Password'), password);
  await tapOn(tester, find.widgetWithText(FilledButton, 'Create account'));
}

Future<void> signIn(WidgetTester tester, String who) async {
  await go(tester, '/welcome');
  await tapText(tester, 'Sign in');
  await typeInto(tester, fieldLabelled('Email'), emailFor(who));
  await typeInto(tester, fieldLabelled('Password'), password);
  await tapOn(tester, find.widgetWithText(FilledButton, 'Sign in'));
}

Future<void> signOut(WidgetTester tester) async {
  await go(tester, '/profile/settings');
  await tapText(tester, 'Sign out');
  await waitFor(tester, find.text('Try the demo'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final configured = AppConfig.fromEnvironment().hasBackend;

  testWidgets('6. two members connect and message through the backend', (
    tester,
  ) async {
    await freshInstall();
    await launchApp(tester);

    // Owner: create an account, onboard, publish a listing.
    await signUp(tester, 'Owner Example', 'owner');
    await completeOnboarding(
      tester,
      offer: 'I can mentor students in robotics.',
      seek: 'Volunteer opportunities with youth programs.',
      area: 'Edison',
    );
    expect(find.text('Offering mentorship · Robotics'), findsOneWidget);
    await tapText(tester, 'Save and see matches');
    await waitFor(tester, find.text('Salaam, Owner'));
    // Connected mode never shows demo controls.
    expect(find.textContaining('Fictional'), findsNothing);
    expect(find.byIcon(Icons.switch_account_outlined), findsNothing);

    final title = 'Robotics mentoring circle $runId';
    await go(tester, '/post');
    await publishListing(
      tester,
      title: title,
      description:
          'Weekly robotics mentoring for students preparing for competitions.',
    );
    await signOut(tester);

    // Requester: separate account finds the listing and asks to connect.
    await signUp(tester, 'Requester Example', 'requester');
    await completeOnboarding(
      tester,
      offer: 'I can help with Python.',
      seek: 'A robotics mentor.',
    );
    await tapText(tester, 'Save and see matches');
    await waitFor(tester, find.text('Salaam, Requester'));
    await search(tester, 'robotics mentoring circle $runId');
    await tapText(tester, title);
    await tapText(tester, 'Request to connect');
    await tapText(tester, 'Send request');
    await waitFor(tester, find.text('Request pending'));
    await signOut(tester);

    // Owner accepts and replies.
    await signIn(tester, 'owner');
    await waitFor(tester, find.text('Salaam, Owner'));
    await go(tester, '/inbox');
    await tapText(tester, 'Requests');
    await waitFor(tester, find.text('Requester Example'));
    await tapOn(tester, find.widgetWithText(FilledButton, 'Accept'));
    await waitFor(tester, find.text('You’re connected'));
    await typeInto(
      tester,
      fieldLabelled('Write a message'),
      'Welcome! See you Saturday.',
    );
    await tapOn(tester, find.byTooltip('Send message'));
    await waitFor(tester, find.text('Welcome! See you Saturday.'));
    final conversationId = containerOf(
      tester,
    ).read(conversationsProvider).value!.first.id;
    await signOut(tester);

    // Requester reads and replies.
    await signIn(tester, 'requester');
    await waitFor(tester, find.text('Salaam, Requester'));
    await go(tester, '/inbox/chat/$conversationId');
    await waitFor(tester, find.text('Welcome! See you Saturday.'));
    await typeInto(tester, fieldLabelled('Write a message'), 'Thank you!');
    await tapOn(tester, find.byTooltip('Send message'));
    await waitFor(tester, find.text('Thank you!'));
    await signOut(tester);

    // An unrelated member cannot open the conversation.
    await signUp(tester, 'Outsider Example', 'outsider');
    await waitFor(tester, find.text('Salaam! What should we call you?'));
    await completeOnboarding(
      tester,
      offer: 'Nothing yet',
      seek: 'Volunteering',
    );
    await tapText(tester, 'Save and see matches');
    await waitFor(tester, find.text('Salaam, Outsider'));
    await go(tester, '/inbox/chat/$conversationId');
    await waitFor(tester, find.text('This conversation is private'));
    expect(find.text('Welcome! See you Saturday.'), findsNothing);
    await signOut(tester);
  }, skip: !configured);
}
