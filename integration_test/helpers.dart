import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/app.dart';
import 'package:muslim_marketplace/src/bootstrap.dart';
import 'package:muslim_marketplace/src/routing/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wipes device storage so each journey starts like a fresh install.
Future<void> freshInstall() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

/// Launches the real app with real device storage.
Future<void> launchApp(WidgetTester tester) async {
  await tester.pumpWidget(await bootstrap(key: UniqueKey()));
  await settle(tester);
}

/// Simulates closing and reopening the app: tears down the widget tree and
/// every provider, then boots again from what was saved on the device.
Future<void> restartApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await launchApp(tester);
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MarketplaceApp)));

Future<void> go(WidgetTester tester, String location) async {
  containerOf(tester).read(routerProvider).go(location);
  await settle(tester);
}

/// pumpAndSettle with a ceiling, for screens with network activity.
Future<void> settle(
  WidgetTester tester, [
  Duration timeout = const Duration(seconds: 15),
]) async {
  final end = DateTime.now().add(timeout);
  await tester.pump(const Duration(milliseconds: 100));
  while (DateTime.now().isBefore(end)) {
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      return;
    } catch (_) {
      // Still animating (for example a progress indicator); keep pumping.
      await tester.pump(const Duration(milliseconds: 200));
    }
  }
}

/// Waits until [finder] matches something.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      final visible = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .take(60)
          .join(' | ');
      throw TestFailure('Timed out waiting for $finder\nOn screen: $visible');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  await settle(tester);
}

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await settle(tester);
  await tester.tap(finder.first, warnIfMissed: false);
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text) =>
    tapOn(tester, find.text(text));

Future<void> typeInto(WidgetTester tester, Finder field, String value) async {
  await waitFor(tester, field);
  await tester.ensureVisible(field.first);
  await tester.enterText(field.first, value);
  await settle(tester);
}

Finder fieldLabelled(String label) => find.widgetWithText(TextField, label);

Future<void> search(WidgetTester tester, String query) async {
  await go(tester, '/');
  final field = find.byKey(const ValueKey('discovery-search-input'));
  if (field.evaluate().isEmpty) await tapText(tester, 'Type instead');
  await typeInto(tester, field, query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await settle(tester);
}

/// Demo only: switch member through the banner.
Future<void> switchMember(WidgetTester tester, String name) async {
  await tapOn(tester, find.byIcon(Icons.switch_account_outlined));
  await tapOn(
    tester,
    find.descendant(of: find.byType(BottomSheet), matching: find.text(name)),
  );
  await waitFor(
    tester,
    find.textContaining('Salaam, ${name.split(' ').first}'),
  );
}

/// Completes onboarding with the given answers (the name step may be
/// prefilled in connected mode).
Future<void> completeOnboarding(
  WidgetTester tester, {
  String? name,
  required String offer,
  required String seek,
  String interests = '',
  String area = '',
}) async {
  await waitFor(tester, find.text('Salaam! What should we call you?'));
  if (name != null) await typeInto(tester, find.byType(TextField), name);
  await tapText(tester, 'Next');
  await typeInto(tester, find.byType(TextField), offer);
  await tapText(tester, 'Next');
  await typeInto(tester, find.byType(TextField), seek);
  await tapText(tester, 'Next');
  if (interests.isNotEmpty) {
    await typeInto(tester, find.byType(TextField).first, interests);
  }
  if (area.isNotEmpty) {
    await typeInto(tester, find.byType(TextField).last, area);
  }
  await tapText(tester, 'Review');
  await waitFor(tester, find.text('Here’s what we picked up'));
}

/// Fills and publishes the create-listing form.
Future<void> publishListing(
  WidgetTester tester, {
  required String title,
  required String description,
}) async {
  await waitFor(tester, find.text('Publish listing'));
  await tapOn(tester, find.widgetWithText(ChoiceChip, 'Mentorship'));
  await tapText(tester, 'Offering mentorship');
  await typeInto(tester, fieldLabelled('Title'), title);
  await typeInto(tester, fieldLabelled('Description'), description);
  await tapText(tester, 'Category');
  await tapOn(tester, find.text('Engineering & science').last);
  await tapText(tester, 'Can be done remotely');
  await tapText(tester, 'Publish listing');
  await waitFor(tester, find.text('Your listing'));
}
