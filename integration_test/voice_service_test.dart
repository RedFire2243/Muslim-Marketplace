import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:muslim_marketplace/src/bootstrap.dart';
import 'package:muslim_marketplace/src/config/app_config.dart';
import 'package:muslim_marketplace/src/data/key_value_store.dart';
import 'package:muslim_marketplace/src/data/seed/seed_data.dart';
import 'package:muslim_marketplace/src/state/discovery.dart';
import 'package:muslim_marketplace/src/state/session.dart';
import 'package:muslim_marketplace/src/state/voice_search.dart';

import 'helpers.dart';

/// Opt-in real-device check. Supply a synthetic WAV as VOICE_SMOKE_AUDIO in
/// an ignored build config. It never records the member or changes their data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  const audio = String.fromEnvironment('VOICE_SMOKE_AUDIO');

  testWidgets(
    'device can transcribe through the server and display matching listings',
    (tester) async {
      await tester.pumpWidget(
        await bootstrap(
          config: config,
          store: MemoryStore(),
          demoLatency: Duration.zero,
        ),
      );
      await settle(tester);
      final container = containerOf(tester);
      await container
          .read(sessionProvider.notifier)
          .startDemo(asMemberId: SeedIds.amina);
      await settle(tester);

      final microphone = find.byKey(const ValueKey('discovery-voice-button'));
      expect(tester.widget<IconButton>(microphone).onPressed, isNotNull);
      final transcriber = container.read(speechTranscriberProvider);
      expect(transcriber, isNotNull);

      final transcript = await transcriber!.transcribe(base64Decode(audio));
      expect(transcript.toLowerCase(), contains('robotics'));
      expect(transcript.toLowerCase(), contains('mentor'));
      container.read(discoveryProvider.notifier).search(transcript);
      await settle(tester);
      expect(find.text('Robotics mentorship for students'), findsOneWidget);
      expect(find.text('Your matches'), findsOneWidget);
    },
    skip: !config.hasVoiceSearch || audio.isEmpty,
  );
}
