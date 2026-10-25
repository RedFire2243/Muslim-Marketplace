import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase/supabase_gateway.dart';
import '../voice/speech_transcriber.dart';
import '../voice/voice_recorder.dart';
import 'discovery.dart';
import 'session.dart';

/// Null when neither a voice service nor explicit direct-test mode is configured.
final speechTranscriberProvider = Provider<SpeechTranscriber?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasVoiceSearch) return null;
  if (config.hasDirectGemini) {
    final transcriber = DirectGeminiTranscriber(
      apiKey: config.geminiApiKey,
      model: config.geminiModel,
    );
    ref.onDispose(transcriber.dispose);
    return transcriber;
  }
  final gateway = ref.watch(accountGatewayProvider);
  final transcriber = BackendSpeechTranscriber(
    url: config.voiceSearchUrl,
    accessToken: () {
      final session = ref.read(sessionProvider).value;
      if (session == null || session.isDemo) return null;
      return gateway is SupabaseAccountGateway
          ? gateway.client.auth.currentSession?.accessToken
          : null;
    },
  );
  ref.onDispose(transcriber.dispose);
  return transcriber;
});

/// Makes a fresh recorder for each voice search.
final voiceRecorderFactoryProvider = Provider<VoiceRecorder Function()>(
  (ref) => MicRecorder.new,
);

enum VoicePhase { idle, listening, transcribing }

class VoiceSearchState {
  const VoiceSearchState({
    this.phase = VoicePhase.idle,
    this.level = 0,
    this.error,
  });

  final VoicePhase phase;

  /// Microphone loudness while listening, from 0 to 1.
  final double level;

  /// Why the last voice search found nothing to search for.
  final String? error;
}

/// Listens for one spoken request, transcribes it and runs it as a search.
/// Listening stops when the speaker pauses, when they tap the microphone
/// again, or after [maxDuration].
class VoiceSearchController extends Notifier<VoiceSearchState> {
  static const maxDuration = Duration(seconds: 15);
  static const minDuration = Duration(milliseconds: 400);

  VoiceRecorder? _recorder;
  StreamSubscription<double>? _levels;
  Timer? _limit;

  @override
  VoiceSearchState build() {
    ref.onDispose(() {
      _stopListening();
      unawaited(_recorder?.dispose());
      _recorder = null;
    });
    return const VoiceSearchState();
  }

  /// Starts listening, or stops and searches when already listening.
  Future<void> toggle() => switch (state.phase) {
    VoicePhase.idle => start(),
    VoicePhase.listening => finish(),
    VoicePhase.transcribing => Future.value(),
  };

  Future<void> start() async {
    if (state.phase != VoicePhase.idle) return;
    final recorder = _recorder = ref.read(voiceRecorderFactoryProvider)();
    // False once this attempt was finished or abandoned while we waited.
    bool current() => ref.mounted && _recorder == recorder;
    state = const VoiceSearchState(phase: VoicePhase.listening);
    try {
      final allowed = await recorder.requestPermission();
      if (!current()) return;
      if (!allowed) return _fail('Allow microphone access to search by voice.');
      await recorder.start();
    } catch (e) {
      debugPrint('Voice search could not start: $e');
      if (current()) _fail('The microphone couldn’t be started.');
      return;
    }
    if (!current()) return;
    final detector = EndOfSpeechDetector();
    _levels = recorder.levels.listen((dbfs) {
      if (state.phase != VoicePhase.listening) return;
      state = VoiceSearchState(
        phase: VoicePhase.listening,
        level: ((dbfs + 60) / 60).clamp(0.0, 1.0),
      );
      if (detector.add(dbfs)) unawaited(finish());
    });
    _limit = Timer(maxDuration, () => unawaited(finish()));
  }

  /// Stops listening and searches for what was said.
  Future<void> finish() async {
    final recorder = _recorder;
    if (state.phase != VoicePhase.listening || recorder == null) return;
    _stopListening();
    _recorder = null;
    state = const VoiceSearchState(phase: VoicePhase.transcribing);
    try {
      final clip = await recorder.stop();
      if (!ref.mounted) return;
      final transcriber = ref.read(speechTranscriberProvider);
      if (transcriber == null) return _fail('Voice search isn’t set up.');
      final text = clip.length < minDuration || !clip.hasSpeech
          ? ''
          : await transcriber.transcribe(clip.wav);
      if (!ref.mounted) return;
      if (text.isEmpty) {
        return _fail('Didn’t catch that. Tap the microphone and try again.');
      }
      ref.read(discoveryProvider.notifier).search(text);
      state = const VoiceSearchState();
    } on VoiceSearchException catch (e) {
      if (ref.mounted) _fail(e.message);
    } catch (e) {
      debugPrint('Voice search failed: $e');
      if (ref.mounted) {
        _fail('Voice search didn’t work. Try again or type your search.');
      }
    } finally {
      unawaited(recorder.dispose());
    }
  }

  void _fail(String message) {
    _stopListening();
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) unawaited(recorder.dispose());
    state = VoiceSearchState(error: message);
  }

  void _stopListening() {
    _limit?.cancel();
    _limit = null;
    unawaited(_levels?.cancel());
    _levels = null;
  }
}

final voiceSearchProvider =
    NotifierProvider.autoDispose<VoiceSearchController, VoiceSearchState>(
      VoiceSearchController.new,
    );
