import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/config/app_config.dart';
import 'package:muslim_marketplace/src/data/seed/seed_data.dart';
import 'package:muslim_marketplace/src/state/discovery.dart';
import 'package:muslim_marketplace/src/state/voice_search.dart';
import 'package:muslim_marketplace/src/voice/speech_transcriber.dart';
import 'package:muslim_marketplace/src/voice/voice_recorder.dart';

import 'harness.dart';

class FakeRecorder implements VoiceRecorder {
  final levelsController = StreamController<double>();
  var permission = true;
  var started = false;
  var stopped = false;
  var disposed = false;
  var length = const Duration(seconds: 3);
  var hasSpeech = true;

  @override
  Future<bool> requestPermission() async => permission;

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

void main() {
  late FakeRecorder recorder;

  Future<void> pumpVoice(WidgetTester tester, SpeechTranscriber t) async {
    recorder = FakeRecorder();
    final c = await pumpApp(
      tester,
      size: desktop,
      config: const AppConfig(geminiApiKey: 'test-key'),
      overrides: [
        speechTranscriberProvider.overrideWithValue(t),
        voiceRecorderFactoryProvider.overrideWithValue(() => recorder),
      ],
    );
    await enterAs(tester, c, SeedIds.zaid);
  }

  String searchText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller!.text;

  const listening = 'Listening… tap the microphone when you’re done.';

  testWidgets('the microphone appears only when voice search is set up', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: desktop);
    await enterAs(tester, c, SeedIds.zaid);
    expect(find.byTooltip('Search by voice'), findsNothing);
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
    expect(find.text(listening), findsOneWidget);
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
    expect(searchText(tester), 'robotics mentor and a summer internship');
    expect(find.text('We found 2 things you’re looking for'), findsOneWidget);
    expect(find.text('Robotics mentorship for students'), findsOneWidget);
    expect(find.text(listening), findsNothing);
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
    expect(searchText(tester), 'looking for a math tutor');
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
    expect(searchText(tester), isEmpty);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(TextField).first),
      ).read(discoveryProvider).hasQuery,
      isFalse,
    );
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
    expect(searchText(tester), isEmpty);
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

  testWidgets('transcription errors are shown', (tester) async {
    final transcriber = FakeTranscriber(
      () => throw const VoiceSearchException('Voice search is busy right now.'),
    );
    await pumpVoice(tester, transcriber);

    await tester.tap(find.byTooltip('Search by voice'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop and search'));
    await tester.pumpAndSettle();

    expect(find.text('Voice search is busy right now.'), findsOneWidget);
    expect(find.byTooltip('Search by voice'), findsOneWidget);
  });
}
