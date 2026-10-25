import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:muslim_marketplace/src/app.dart';
import 'package:muslim_marketplace/src/bootstrap.dart';
import 'package:muslim_marketplace/src/config/app_config.dart';
import 'package:muslim_marketplace/src/data/demo/demo_backend.dart';
import 'package:muslim_marketplace/src/data/key_value_store.dart';
import 'package:muslim_marketplace/src/routing/router.dart';
import 'package:muslim_marketplace/src/state/session.dart';

const phone = Size(390, 844);
const desktop = Size(1440, 900);

/// Pumps the real app in demo mode with in-memory storage.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Size size = phone,
  KeyValueStore? store,
  double textScale = 1,
  AppConfig config = const AppConfig(),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final app = await bootstrap(
    store: store ?? MemoryStore(),
    demoLatency: Duration.zero,
    config: config,
    overrides: overrides,
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MarketplaceApp)));
}

/// Enters the demo as a sample member and waits for the home screen.
Future<void> enterAs(
  WidgetTester tester,
  ProviderContainer c,
  String memberId,
) async {
  await c.read(sessionProvider.notifier).startDemo(asMemberId: memberId);
  await tester.pumpAndSettle();
}

Future<void> goTo(
  WidgetTester tester,
  ProviderContainer c,
  String location,
) async {
  c.read(routerProvider).go(location);
  await tester.pumpAndSettle();
}

Future<DemoBackend> demoOf(ProviderContainer c) =>
    c.read(demoBackendProvider.future);

GoRouter routerOf(ProviderContainer c) => c.read(routerProvider);

/// Scrolls the first scrollable until [finder] is visible, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
