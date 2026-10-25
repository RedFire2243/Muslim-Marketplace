import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_marketplace/src/voice/speech_transcriber.dart';

http.Response reply(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> answer(List<Map<String, Object?>> parts) => {
  'candidates': [
    {
      'content': {'role': 'model', 'parts': parts},
    },
  ],
};

Matcher failsWith(String text) => throwsA(
  isA<VoiceSearchException>().having(
    (e) => e.message,
    'message',
    contains(text),
  ),
);

void main() {
  final wav = Uint8List.fromList([82, 73, 70, 70, 1, 2, 3, 4]);

  GeminiTranscriber transcriber(
    MockClientHandler handler, {
    Duration timeout = const Duration(seconds: 20),
  }) => GeminiTranscriber(
    apiKey: 'test-key',
    model: 'gemini-test',
    client: MockClient(handler),
    timeout: timeout,
  );

  test('sends the recording inline with the key in a header', () async {
    late http.Request sent;
    final text = await transcriber((req) async {
      sent = req;
      return reply(
        answer([
          {'text': '{"transcript": "robotics mentor near New Brunswick"}'},
        ]),
      );
    }).transcribe(wav);

    expect(text, 'robotics mentor near New Brunswick');
    expect(sent.method, 'POST');
    expect(
      sent.url.toString(),
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent',
    );
    expect(sent.headers['x-goog-api-key'], 'test-key');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['contents'][0]['parts'][0]['inlineData'], {
      'mimeType': 'audio/wav',
      'data': base64Encode(wav),
    });
    expect(
      body['systemInstruction']['parts'][0]['text'],
      contains('New Brunswick'),
    );
    expect(body['generationConfig']['responseMimeType'], 'application/json');
  });

  test('skips thinking and accepts a plain text answer', () async {
    final text = await transcriber(
      (_) async => reply(
        answer([
          {'text': 'The speaker wants a mentor.', 'thought': true},
          {'text': '  looking for a\n tutor  '},
        ]),
      ),
    ).transcribe(wav);
    expect(text, 'looking for a tutor');
  });

  test('silence and blocked requests give an empty transcript', () async {
    expect(
      await transcriber(
        (_) async => reply(
          answer([
            {'text': '{"transcript": ""}'},
          ]),
        ),
      ).transcribe(wav),
      '',
    );
    expect(
      await transcriber(
        (_) async => reply({
          'promptFeedback': {'blockReason': 'OTHER'},
        }),
      ).transcribe(wav),
      '',
    );
  });

  test('keeps the transcript search-sized', () async {
    final long = List.filled(100, 'mentor').join(' ');
    final text = await transcriber(
      (_) async => reply(
        answer([
          {
            'text': jsonEncode({'transcript': long}),
          },
        ]),
      ),
    ).transcribe(wav);
    expect(text.length, lessThanOrEqualTo(GeminiTranscriber.maxLength));
  });

  test('explains configuration and service errors', () async {
    expect(
      transcriber(
        (_) async => reply({
          'error': {
            'code': 400,
            'message': 'API key not valid. Please pass a valid API key.',
            'details': [
              {'reason': 'API_KEY_INVALID'},
            ],
          },
        }, 400),
      ).transcribe(wav),
      failsWith('API key was refused'),
    );
    expect(
      transcriber((_) async => reply({}, 403)).transcribe(wav),
      failsWith('API key was refused'),
    );
    expect(
      transcriber((_) async => reply({}, 404)).transcribe(wav),
      failsWith('“gemini-test” isn’t available'),
    );
    expect(
      transcriber((_) async => reply({}, 429)).transcribe(wav),
      failsWith('busy'),
    );
    expect(
      transcriber((_) async => reply({}, 503)).transcribe(wav),
      failsWith('unavailable'),
    );
    expect(
      transcriber((_) async => http.Response('not json', 200)).transcribe(wav),
      failsWith('didn’t work'),
    );
  });

  test('network failures and timeouts are reported', () async {
    expect(
      transcriber(
        (_) async => throw http.ClientException('offline'),
      ).transcribe(wav),
      failsWith('Couldn’t reach'),
    );
    final never = Completer<http.Response>();
    expect(
      transcriber(
        (_) => never.future,
        timeout: const Duration(milliseconds: 10),
      ).transcribe(wav),
      failsWith('took too long'),
    );
  });
}
