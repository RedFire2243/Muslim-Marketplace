import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/voice/voice_recorder.dart';

void main() {
  test('wraps PCM in a 16-bit mono WAV header', () {
    final pcm = Uint8List.fromList(List.generate(320, (i) => i % 256));
    final wav = wavFromPcm16(pcm, sampleRate: 16000);
    final header = ByteData.sublistView(wav, 0, 44);

    expect(wav.length, 44 + pcm.length);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 16)), 'WAVEfmt ');
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    expect(header.getUint32(4, Endian.little), 36 + pcm.length);
    expect(header.getUint16(20, Endian.little), 1);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint32(28, Endian.little), 32000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), pcm.length);
    expect(wav.sublist(44), pcm);
  });

  group('speech in a finished recording', () {
    const rate = 16000;

    /// 16-bit PCM from [seconds] of samples produced by [sample] (-1 to 1).
    Uint8List pcm(double seconds, double Function(int i) sample) {
      final n = (seconds * rate).round();
      final data = ByteData(n * 2);
      for (var i = 0; i < n; i++) {
        data.setInt16(i * 2, (sample(i) * 32767).round(), Endian.little);
      }
      return data.buffer.asUint8List();
    }

    final random = math.Random(1);
    double noise(double dbfs) =>
        (random.nextDouble() * 2 - 1) * math.pow(10, dbfs / 20) * math.sqrt(3);
    double tone(int i, double dbfs) =>
        math.sin(2 * math.pi * 220 * i / rate) *
        math.pow(10, dbfs / 20) *
        math.sqrt2;

    test('measures loudness per 100 ms', () {
      final levels = pcmLevels(
        pcm(0.5, (i) => tone(i, -20)),
        sampleRate: rate,
      ).toList();
      expect(levels, hasLength(5));
      for (final l in levels) {
        expect(l, closeTo(-20, 0.5));
      }
    });

    test('gives the same levels however the audio is split', () {
      final clip = pcm(1, (i) => i < rate / 2 ? tone(i, -12) : noise(-40));
      final whole = pcmLevels(clip, sampleRate: rate);
      final meter = LevelMeter(sampleRate: rate);
      final chunked = [
        // Odd sizes split samples across chunks.
        for (var i = 0; i < clip.length; i += 333)
          ...meter.add(clip.sublist(i, math.min(i + 333, clip.length))),
      ];
      expect(whole, hasLength(10));
      expect(chunked, hasLength(10));
      for (var i = 0; i < 10; i++) {
        expect(chunked[i], closeTo(whole[i], 1e-9));
      }
      expect(whole.first, closeTo(-12, 0.5));
      expect(whole.last, closeTo(-40, 1));
    });

    test('silence and steady noise are not speech', () {
      expect(hasSpeech(pcm(2, (_) => 0), sampleRate: rate), isFalse);
      expect(hasSpeech(pcm(2, (_) => noise(-45)), sampleRate: rate), isFalse);
      expect(hasSpeech(Uint8List(0), sampleRate: rate), isFalse);
    });

    test('a voice over background noise is speech', () {
      final clip = pcm(
        2,
        (i) => i > rate * 0.5 && i < rate * 1.2
            ? tone(i, -18) + noise(-50)
            : noise(-50),
      );
      expect(hasSpeech(clip, sampleRate: rate), isTrue);
    });
  });

  group('end of speech', () {
    /// Feeds [levels] and returns the index of the reading that ended
    /// listening, or null.
    int? endsAt(EndOfSpeechDetector d, Iterable<double> levels) {
      var i = 0;
      for (final level in levels) {
        if (d.add(level)) return i;
        i++;
      }
      return null;
    }

    test('stops after speech followed by a pause', () {
      final d = EndOfSpeechDetector();
      expect(endsAt(d, [-60, -60, -20, -18, -25, -20]), isNull);
      expect(d.heardSpeech, isTrue);
      // 1.5 s of quiet at 100 ms per reading.
      expect(endsAt(d, List.filled(20, -60)), 15);
    });

    test('a short pause between words keeps listening', () {
      final d = EndOfSpeechDetector();
      final speech = List<double>.filled(5, -20);
      final shortPause = List<double>.filled(8, -60);
      expect(
        endsAt(d, [-60, ...speech, ...shortPause, ...speech, ...shortPause]),
        isNull,
      );
    });

    test('gives up when nothing sounds like speech', () {
      final d = EndOfSpeechDetector();
      expect(endsAt(d, List.filled(80, -58)), 59);
      expect(d.heardSpeech, isFalse);
    });

    test('adapts to a noisy room', () {
      final d = EndOfSpeechDetector();
      // Background noise around -40 dBFS is not speech.
      expect(endsAt(d, [-40, -38, -42, -36, -40]), isNull);
      expect(d.heardSpeech, isFalse);
      expect(endsAt(d, [-15, -12]), isNull);
      expect(d.heardSpeech, isTrue);
    });

    test('treats silent or invalid readings as quiet', () {
      final d = EndOfSpeechDetector();
      expect(endsAt(d, [double.negativeInfinity, double.nan, -160]), isNull);
      expect(d.heardSpeech, isFalse);
      expect(endsAt(d, [-30]), isNull);
      expect(d.heardSpeech, isTrue);
    });
  });
}
