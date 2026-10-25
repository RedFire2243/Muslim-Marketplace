import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/config/app_config.dart';
import 'package:muslim_marketplace/src/data/seed/seed_data.dart';
import 'package:muslim_marketplace/src/state/discovery.dart';
import 'package:muslim_marketplace/src/state/session.dart';
import 'package:muslim_marketplace/src/state/voice_search.dart';
import 'package:muslim_marketplace/src/voice/speech_transcriber.dart';
import 'package:muslim_marketplace/src/voice/voice_recorder.dart';

import 'harness.dart';

class FakeRecorder implements VoiceRecorder {
  final levelsController = StreamController<double>();
  var permission = true;
  var permissionRequests = 0;
  var started = false;
  var stopped = false;
  var disposed = false;
  var length = const Duration(seconds: 3);
  var hasSpeech = true;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> start() async => started = true;

  @override
  Stream<double> get levels => levelsController.stream;

  @override
  Future<VoiceClip> stop() async {
    stopped = true;
    return VoiceClip(Uint8List(64), length, hasSpeech: hasSpeech);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await levelsController.close();
  }
}

class FakeTranscriber implements SpeechTranscriber {
  FakeTranscriber(this.reply);
  final String Function() reply;
  var calls = 0;

  @override
  Future<String> transcribe(Uint8List wav) async {
    calls++;
    return reply();
  }
}

class PendingTranscriber implements SpeechTranscriber {
  final response = Completer<String>();
  var calls = 0;

  @override
  Future<String> transcribe(Uint8List wav) {
    calls++;
    return response.future;
  }
}

void main() {
  late FakeRecorder recorder;
  late ProviderContainer container;

  Future<void> pumpVoice(
    WidgetTester tester,
    SpeechTranscriber t, {
    Size size = desktop,
  }) async {
    recorder = FakeRecorder();
    container = await pumpApp(
      tester,
      size: size,
      config: const AppConfig(
        voiceSearchUrl: 'https://voice.example.test/transcribe',
      ),
      overrides: [
        speechTranscriberProvider.overrideWithValue(t),
        voiceRecorderFactoryProvider.overrideWithValue(() => recorder),
      ],
    );
    await enterAs(tester, container, SeedIds.zaid);
  }

  String searchText() => container.read(discoveryProvider).query;

  final listening = find.textContaining('Listening');

  testWidgets('explicit direct test enables Gemini without the LAN service', (
    tester,
  ) async {
    final c = await pumpApp(
      tester,
      size: phone,
      config: const AppConfig(
        geminiDirectTest: true,
        geminiApiKey: 'test-only-key',
        voiceSearchUrl: 'http://unreachable.local:8765/transcribe-search',
      ),
    );
    await enterAs(tester, c, SeedIds.zaid);
    expect(c.read(appConfigProvider).hasDirectGemini, isTrue);
    expect(c.read(speechTranscriberProvider), isA<DirectGeminiTranscriber>());
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('discovery-voice-button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('Tap to speak'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a configured LAN endpoint enables the real voice provider', (
    tester,
  ) async {
    const endpoint = 'http://Hamzas-MacBook-Pro.local:8765/transcribe-search';
    final c = await pumpApp(
      tester,
      size: phone,
      config: const AppConfig(voiceSearchUrl: endpoint),
    );
    await enterAs(tester, c, SeedIds.zaid);

    expect(c.read(appConfigProvider).voiceSearchUrl, endpoint);
    expect(c.read(appConfigProvider).hasVoiceSearch, isTrue);
    expect(c.read(speechTranscriberProvider), isA<BackendSpeechTranscriber>());
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('discovery-voice-button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.byTooltip('Search by voice'), findsOneWidget);
    expect(find.text('Tap to speak'), findsOneWidget);
    expect(find.text('Voice search is unavailable right now.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Discover keeps a voice entry point and typing without a key', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: desktop);
    await enterAs(tester, c, SeedIds.zaid);
    expect(find.byTooltip('Search by voice'), findsNothing);
    expect(find.byTooltip('Voice search unavailable'), findsOneWidget);
    expect(find.text('Voice search is unavailable right now.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('discovery-voice-button')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Browse by category'), findsNothing);

    await tester.tap(find.text('Type instead'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('discovery-search-input'));
    await tester.enterText(field, 'looking for a robotics mentor');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(c.read(discoveryProvider).query, 'looking for a robotics mentor');
    expect(find.text('Robotics mentorship for students'), findsOneWidget);
  });

  testWidgets('speaking runs a search and stops when the speaker pauses', (
    tester,
  ) async {
    final transcriber = FakeTranscriber(
      () => 'robotics mentor and a summer internship',
    );
    await pumpVoice(tester, transcriber);

    await tester.tap(find.byTooltip('Search by voice'));
    await tester.pump();
    expect(recorder.started, isTrue);
    expect(listening, findsOneWidget);
    expect(find.textContaining('sent to Google Gemini'), findsOneWidget);
    expect(find.byTooltip('Stop and search'), findsOneWidget);

    // Background, a few words, then a pause ends listening by itself.
    for (final level in <double>[
      -60.0,
      -60,
      -20,
      -18,
      -22,
      -20,
      ...List.filled(15, -60.0),
    ]) {
      recorder.levelsController.add(level);
      await tester.pump();
    }
    expect(recorder.stopped, isFalse);
    recorder.levelsController.add(-60);
    await tester.pumpAndSettle();

    expect(recorder.stopped, isTrue);
    expect(recorder.disposed, isTrue);
    expect(transcriber.calls, 1);
    expect(searchText(), 'robotics mentor and a summer internship');
    expect(find.text('We found 2 things you’re looking for'), findsOneWidget);
    expect(find.text('Robotics mentorship for students'), findsOneWidget);
    expect(listening, findsNothing);
    expect(find.byTooltip('Search by voice'), findsOneWidget);
  });

  testWidgets('tapping the microphone again stops listening', (tester) async {
    final transcriber = FakeTranscriber(() => 'looking for a math tutor');
    await pumpVoice(tester, transcriber);

    await tester.tap(find.byTooltip('Search by voice'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop and search'));
    await tester.pumpAndSettle();

    expect(recorder.stopped, isTrue);
    expect(searchText(), 'looking for a math tutor');
  });

  testWidgets('typing searches without requesting microphone permission', (
    tester,
  ) async {
    final transcriber = FakeTranscriber(() => 'unused');
    await pumpVoice(tester, transcriber);

    await tester.tap(find.text('Type instead'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('discovery-search-input')),
      'looking for a robotics mentor',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(searchText(), 'looking for a robotics mentor');
    expect(find.text('Robotics mentorship for students'), findsOneWidget);
    expect(recorder.permissionRequests, 0);
    expect(transcriber.calls, 0);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets(
    'transcription keeps the voice button busy until matches return',
    (tester) async {
      final transcriber = PendingTranscriber();
      await pumpVoice(tester, transcriber);

      await tester.tap(find.byTooltip('Search by voice'));
      await tester.pump();
      await tester.tap(find.byTooltip('Stop and search'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byTooltip('Finding your matches'), findsOneWidget);
      expect(find.byTooltip('Search by voice'), findsNothing);
      expect(
        container.read(voiceSearchProvider).phase,
        VoicePhase.transcribing,
      );
      await tester.tap(find.byTooltip('Finding your matches'));
      await tester.pump();
      expect(transcriber.calls, 1);

      transcriber.response.complete('looking for a robotics mentor');
      await tester.pumpAndSettle();
      expect(searchText(), 'looking for a robotics mentor');
      expect(find.text('Robotics mentorship for students'), findsOneWidget);
      expect(find.byTooltip('Search by voice'), findsOneWidget);
    },
  );

  for (final size in [phone, desktop]) {
    testWidgets('voice button is prominent and visible (${size.width} wide)', (
      tester,
    ) async {
      await pumpVoice(tester, FakeTranscriber(() => 'a mentor'), size: size);
      final button = find.byKey(const ValueKey('discovery-voice-button'));
      final bounds = tester.getRect(button);

      expect(bounds.width, greaterThanOrEqualTo(96));
      expect(bounds.height, greaterThanOrEqualTo(96));
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.bottom, lessThan(size.height - 60));
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'a spoken search reveals matches and starts over on a phone (reduced motion: $reducedMotion)',
      (tester) async {
        if (reducedMotion) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        await pumpVoice(
          tester,
          FakeTranscriber(() => 'looking for a robotics mentor'),
          size: phone,
        );
        await tester.tap(find.byTooltip('Search by voice'));
        await tester.pump();
        await tester.tap(find.byTooltip('Stop and search'));
        await tester.pumpAndSettle();

        expect(searchText(), 'looking for a robotics mentor');
        final matches = find.text('Your matches');
        expect(matches, findsOneWidget);
        final bounds = tester.getRect(matches);
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThan(phone.height - 80));
        expect(find.text('Robotics mentorship for students'), findsOneWidget);

        await tester.tap(find.text('Start over'));
        await tester.pumpAndSettle();
        expect(searchText(), isEmpty);
        final microphone = tester.getRect(
          find.byKey(const ValueKey('discovery-voice-button')),
        );
        expect(microphone.top, greaterThanOrEqualTo(0));
        expect(microphone.bottom, lessThan(phone.height - 80));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the idle prompt fades to another invitation', (tester) async {
    await pumpVoice(tester, FakeTranscriber(() => 'a mentor'));
    expect(find.text('What are you looking for?'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('What can we help you find?'), findsOneWidget);
    expect(find.text('What are you looking for?'), findsNothing);
  });

  testWidgets('reduced motion keeps the invitation still', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpVoice(tester, FakeTranscriber(() => 'a mentor'));
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();

    expect(find.text('What are you looking for?'), findsOneWidget);
    expect(find.text('What can we help you find?'), findsNothing);
  });

  testWidgets('listening stops after 15 seconds', (tester) async {
    final transcriber = FakeTranscriber(() => 'a mentor');
    await pumpVoice(tester, transcriber);

    await tester.tap(find.byTooltip('Search by voice'));
    await tester.pump(const Duration(seconds: 14));
    expect(recorder.stopped, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(recorder.stopped, isTrue);
    expect(transcriber.calls, 1);
  });

  testWidgets('nothing heard leaves the search alone and says so', (
    tester,
  ) async {
    final transcriber = FakeTranscriber(() => '');
    await pumpVoice(tester, transcriber);

    await tester.tap(find.byTooltip('Search by voice'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop and search'));
    await tester.pumpAndSettle();

    expect(
      find.text('Didn’t catch that. Tap the microphone and try again.'),
      findsOneWidget,
    );
    expect(searchText(), isEmpty);
    expect(container.read(discoveryProvider).hasQuery, isFalse);
  });

  testWidgets('a very short recording is not sent', (tester) async {
    final transcriber = FakeTranscriber(() => 'unused');
    await pumpVoice(tester, transcriber);
    recorder.length = const Duration(milliseconds: 100);

    await tester.tap(find.byTooltip('Search by voice'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop and search'));
    await tester.pumpAndSettle();

    expect(transcriber.calls, 0);
    expect(find.textContaining('Didn’t catch that'), findsOneWidget);
  });

  testWidgets('a recording without speech is not sent', (tester) async {
    final transcriber = FakeTranscriber(() => 'invented words');
    await pumpVoice(tester, transcriber);
    recorder.hasSpeech = false;

    await tester.tap(find.byTooltip('Search by voice'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop and search'));
    await tester.pumpAndSettle();

    expect(transcriber.calls, 0);
    expect(searchText(), isEmpty);
    expect(find.textContaining('Didn’t catch that'), findsOneWidget);
  });

  testWidgets('a refused microphone explains what to do', (tester) async {
    final transcriber = FakeTranscriber(() => 'unused');
    await pumpVoice(tester, transcriber);
    recorder.permission = false;

    await tester.tap(find.byTooltip('Search by voice'));
    await tester.pumpAndSettle();

    expect(recorder.started, isFalse);
    expect(recorder.disposed, isTrue);
    expect(
      find.text('Allow microphone access to search by voice.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Search by voice'), findsOneWidget);
  });

  testWidgets('transcription errors keep the previous search', (tester) async {
    final transcriber = FakeTranscriber(
      () => throw const VoiceSearchException('Voice search is busy right now.'),
    );
    await pumpVoice(tester, transcriber);
    container.read(discoveryProvider.notifier).search('robotics mentor');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Search by voice'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search by voice'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop and search'));
    await tester.pumpAndSettle();

    expect(find.text('Voice search is busy right now.'), findsOneWidget);
    expect(find.byTooltip('Search by voice'), findsOneWidget);
    expect(searchText(), 'robotics mentor');
  });
}
