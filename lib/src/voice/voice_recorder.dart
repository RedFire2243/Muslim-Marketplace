import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

/// How much audio each loudness reading covers.
const levelInterval = Duration(milliseconds: 100);

/// One finished recording.
class VoiceClip {
  const VoiceClip(this.wav, this.length, {required this.hasSpeech});

  /// 16-bit mono PCM in a WAV container.
  final Uint8List wav;
  final Duration length;

  /// Whether anything in it could be speech. Transcription models tend to
  /// invent words for silence, so clips without it are never sent.
  final bool hasSpeech;
}

/// Captures one voice search from the microphone.
abstract interface class VoiceRecorder {
  /// Asks for microphone access when needed. False when it is refused.
  Future<bool> requestPermission();

  Future<void> start();

  /// Loudness in dBFS (0 is the loudest) of each [levelInterval] of audio
  /// recorded so far.
  Stream<double> get levels;

  Future<VoiceClip> stop();

  Future<void> dispose();
}

/// Records from the device microphone with the `record` plugin. Audio is
/// streamed as raw PCM on every platform (including the web) and wrapped as
/// WAV, so nothing touches the file system.
///
/// Levels are measured from the audio itself rather than polled on a timer:
/// browsers throttle timers in background or embedded pages, which would
/// stall the end-of-speech detection while recording carries on.
class MicRecorder implements VoiceRecorder {
  static const sampleRate = 16000;

  final _recorder = AudioRecorder();
  final _pcm = BytesBuilder(copy: false);
  final _meter = LevelMeter(sampleRate: sampleRate);
  final _levels = StreamController<double>.broadcast();
  final _done = Completer<void>();
  StreamSubscription<Uint8List>? _audio;

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: true,
      ),
    );
    _audio = stream.listen(_onAudio, onDone: _done.complete);
  }

  void _onAudio(Uint8List chunk) {
    _pcm.add(chunk);
    _meter.add(chunk).forEach(_levels.add);
  }

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<VoiceClip> stop() async {
    await _recorder.stop();
    // Let the last buffered chunk arrive.
    await _done.future.timeout(const Duration(seconds: 1), onTimeout: () {});
    final pcm = _pcm.takeBytes();
    return VoiceClip(
      wavFromPcm16(pcm, sampleRate: sampleRate),
      Duration(microseconds: pcm.length * 1000000 ~/ (sampleRate * 2)),
      hasSpeech: hasSpeech(pcm, sampleRate: sampleRate),
    );
  }

  @override
  Future<void> dispose() async {
    await _audio?.cancel();
    await _levels.close();
    await _recorder.dispose();
  }
}

/// Wraps little-endian 16-bit PCM samples in a WAV header.
Uint8List wavFromPcm16(
  Uint8List pcm, {
  required int sampleRate,
  int channels = 1,
}) {
  final header = ByteData(44);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * channels * 2, Endian.little);
  header.setUint16(32, channels * 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return Uint8List(44 + pcm.length)
    ..setAll(0, header.buffer.asUint8List())
    ..setAll(44, pcm);
}

/// Measures the loudness (RMS, in dBFS) of each [levelInterval] of
/// little-endian 16-bit mono PCM that arrives in chunks of any size.
class LevelMeter {
  LevelMeter({required int sampleRate})
    : _window = sampleRate * levelInterval.inMilliseconds ~/ 1000;

  final int _window;
  var _sum = 0.0;
  var _count = 0;

  /// Low byte of a sample split across two chunks.
  int? _carry;

  /// Levels of the windows that [chunk] completes.
  List<double> add(Uint8List chunk) {
    final levels = <double>[];
    void sample(int low, int high) {
      final s = (high << 8 | low).toSigned(16) / 32768;
      _sum += s * s;
      if (++_count == _window) {
        levels.add(10 * math.log(_sum / _window) / math.ln10);
        _sum = 0;
        _count = 0;
      }
    }

    var i = 0;
    if (_carry case final low? when chunk.isNotEmpty) {
      sample(low, chunk[0]);
      _carry = null;
      i = 1;
    }
    for (; i + 1 < chunk.length; i += 2) {
      sample(chunk[i], chunk[i + 1]);
    }
    if (i < chunk.length) _carry = chunk[i];
    return levels;
  }
}

/// Loudness in dBFS of each [levelInterval] of a whole recording.
List<double> pcmLevels(Uint8List pcm, {required int sampleRate}) =>
    LevelMeter(sampleRate: sampleRate).add(pcm);

/// Whether any part of a recording is clearly louder than its own quietest
/// part, which silence and steady background noise never are.
bool hasSpeech(Uint8List pcm, {required int sampleRate}) {
  final levels = pcmLevels(pcm, sampleRate: sampleRate).map(_level).toList();
  if (levels.isEmpty) return false;
  final floor = levels.reduce(math.min);
  return levels.any((l) => _isSpeech(l, floor));
}

/// How many dB above the background counts as speech.
const _speechMargin = 15.0;
const _quietest = -70.0;
const _minSpeech = -50.0;

double _level(double dbfs) => dbfs.isNaN ? _quietest : dbfs.clamp(_quietest, 0);

bool _isSpeech(double level, double floor) =>
    level > math.max(floor + _speechMargin, _minSpeech);

/// Decides when a voice search is over from the loudness of each
/// [levelInterval] of audio: after the speaker has said something and then paused, or
/// when nothing that sounds like speech arrives at all.
///
/// Speech is anything clearly louder than the quietest reading so far, so it
/// adapts to a noisy room. It only decides when to stop listening; the
/// transcriber decides what, if anything, was said.
class EndOfSpeechDetector {
  EndOfSpeechDetector({
    this.pause = const Duration(milliseconds: 1500),
    this.noSpeechTimeout = const Duration(seconds: 6),
  });

  final Duration pause;
  final Duration noSpeechTimeout;

  var _elapsed = Duration.zero;
  Duration? _quietSince;
  double? _floor;
  var _heardSpeech = false;

  bool get heardSpeech => _heardSpeech;

  /// Adds the next reading. True once listening should stop.
  bool add(double dbfs) {
    _elapsed += levelInterval;
    final level = _level(dbfs);
    final floor = _floor = math.min(_floor ?? level, level);
    if (_isSpeech(level, floor)) {
      _heardSpeech = true;
      _quietSince = null;
      return false;
    }
    if (!_heardSpeech) return _elapsed >= noSpeechTimeout;
    final since = _quietSince ??= _elapsed;
    return _elapsed - since >= pause;
  }
}
