import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_marketplace/src/voice/speech_transcriber.dart';

http.Response transcript(Object? text) => http.Response(
  jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {
              'text': jsonEncode({'transcript': text}),
            },
          ],
        },
      },
    ],
  }),
  200,
);

void main() {
  final wav = Uint8List.fromList([82, 73, 70, 70, 1, 2, 3, 4]);
  DirectGeminiTranscriber transcriber(MockClientHandler handler) =>
      DirectGeminiTranscriber(
        apiKey: 'test-only-key',
        model: 'gemini-test',
        client: MockClient(handler),
      );

  test(
    'sends WAV directly to Gemini and searches only the transcript',
    () async {
      late http.Request sent;
      final text = await transcriber((request) async {
        sent = request;
        return transcript('  robotics mentor\n near New Brunswick  ');
      }).transcribe(wav);
      expect(text, 'robotics mentor near New Brunswick');
      expect(sent.url.host, 'generativelanguage.googleapis.com');
      expect(sent.headers['x-goog-api-key'], 'test-only-key');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['contents'][0]['parts'][0]['inlineData'], {
        'mimeType': 'audio/wav',
        'data': base64Encode(wav),
      });
      expect(
        body['systemInstruction']['parts'][0]['text'],
        contains('New Brunswick'),
      );
      expect(body['generationConfig']['responseSchema']['required'], [
        'transcript',
      ]);
    },
  );

  test('silence is empty and transcripts remain search-sized', () async {
    expect(
      await transcriber((_) async => transcript('')).transcribe(wav),
      isEmpty,
    );
    final text = await transcriber(
      (_) async => transcript(List.filled(100, 'mentor').join(' ')),
    ).transcribe(wav);
    expect(text.length, lessThanOrEqualTo(DirectGeminiTranscriber.maxLength));
  });

  test(
    'wrong transcript type and provider errors become safe messages',
    () async {
      for (final (response, expected) in [
        (transcript(42), 'Voice transcription failed'),
        (
          http.Response('SECRET provider detail', 403),
          'credentials were refused',
        ),
        (http.Response('SECRET provider detail', 404), 'model isn’t available'),
        (http.Response('SECRET provider detail', 429), 'busy'),
        (http.Response('SECRET provider detail', 503), 'unavailable'),
      ]) {
        await expectLater(
          transcriber((_) async => response).transcribe(wav),
          throwsA(
            isA<VoiceSearchException>().having(
              (error) => error.message,
              'message',
              allOf(contains(expected), isNot(contains('SECRET'))),
            ),
          ),
        );
      }
    },
  );
}
