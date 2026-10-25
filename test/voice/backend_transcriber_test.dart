import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_marketplace/src/voice/speech_transcriber.dart';

http.Response reply(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Matcher failsWith(String text) => throwsA(
  isA<VoiceSearchException>().having(
    (e) => e.message,
    'message',
    contains(text),
  ),
);

void main() {
  final wav = Uint8List.fromList([82, 73, 70, 70, 1, 2, 3, 4]);

  BackendSpeechTranscriber transcriber(
    MockClientHandler handler, {
    String? Function()? accessToken,
    Duration timeout = const Duration(seconds: 20),
  }) => BackendSpeechTranscriber(
    url: 'https://voice.example.test/transcribe',
    accessToken: accessToken,
    client: MockClient(handler),
    timeout: timeout,
  );

  test(
    'sends WAV to the backend without AI credentials or model details',
    () async {
      late http.Request sent;
      final text = await transcriber((req) async {
        sent = req;
        return reply({'transcript': 'robotics mentor near New Brunswick'});
      }).transcribe(wav);

      expect(text, 'robotics mentor near New Brunswick');
      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://voice.example.test/transcribe');
      expect(sent.headers['content-type'], contains('application/json'));
      expect(sent.headers.containsKey('x-goog-api-key'), isFalse);
      expect(sent.headers.containsKey('authorization'), isFalse);
      expect(jsonDecode(sent.body), {'audio': base64Encode(wav)});
    },
  );

  test('reads the current account token for each request', () async {
    final sentTokens = <String?>[];
    var token = 'first-session-token';
    final service = transcriber((req) async {
      sentTokens.add(req.headers['authorization']);
      return reply({'transcript': 'a mentor'});
    }, accessToken: () => token);

    await service.transcribe(wav);
    token = 'refreshed-session-token';
    await service.transcribe(wav);
    expect(sentTokens, [
      'Bearer first-session-token',
      'Bearer refreshed-session-token',
    ]);
  });

  test(
    'an empty account token is omitted for local and demo requests',
    () async {
      final service = transcriber((req) async {
        expect(req.headers.containsKey('authorization'), isFalse);
        return reply({'transcript': ''});
      }, accessToken: () => '  ');
      expect(await service.transcribe(wav), isEmpty);
    },
  );

  test('cleans whitespace and preserves the transcript language', () async {
    final text = await transcriber(
      (_) async => reply({'transcript': '  أبحث عن\n مرشد  '}),
    ).transcribe(wav);
    expect(text, 'أبحث عن مرشد');
  });

  test('an empty transcript means nothing was heard', () async {
    expect(
      await transcriber((_) async => reply({'transcript': ''})).transcribe(wav),
      '',
    );
  });

  test('keeps the transcript search-sized', () async {
    final long = List.filled(100, 'mentor').join(' ');
    final text = await transcriber(
      (_) async => reply({'transcript': long}),
    ).transcribe(wav);
    expect(text.length, lessThanOrEqualTo(BackendSpeechTranscriber.maxLength));
  });

  test(
    'rejects malformed responses instead of searching response content',
    () async {
      for (final body in <Object?>[
        {},
        {'transcript': null},
        {'transcript': 123},
        {'error': 'upstream_failure'},
        ['a mentor'],
      ]) {
        await expectLater(
          transcriber((_) async => reply(body)).transcribe(wav),
          failsWith('didn’t work'),
        );
      }
      await expectLater(
        transcriber(
          (_) async => http.Response('not json', 200),
        ).transcribe(wav),
        failsWith('didn’t work'),
      );
    },
  );

  test('explains account, configuration and service errors', () async {
    for (final (status, message) in [
      (401, 'Sign in again'),
      (403, 'isn’t available for this account'),
      (404, 'isn’t set up correctly'),
      (413, 'too long'),
      (429, 'busy'),
      (502, 'Voice transcription failed'),
      (504, 'took too long'),
      (503, 'unavailable'),
      (400, 'didn’t work'),
    ]) {
      await expectLater(
        transcriber(
          (_) async => reply({'error': 'service_error'}, status),
        ).transcribe(wav),
        failsWith(message),
      );
    }
  });

  test(
    'uses stable backend error codes without exposing diagnostics',
    () async {
      for (final (code, status, message) in [
        ('voice_not_configured', 503, 'isn’t configured yet'),
        ('upstream_error', 502, 'Voice transcription failed'),
        ('timeout', 504, 'took too long'),
        ('unauthorized', 401, 'Sign in again'),
        ('authentication_unavailable', 503, 'Sign-in couldn’t be verified'),
        ('rate_limited', 429, 'busy'),
        ('audio_too_long', 413, 'recording was too long'),
        ('payload_too_large', 413, 'recording was too long'),
        ('invalid_audio', 400, 'recording couldn’t be read'),
        ('request_not_allowed', 403, 'isn’t available from this device'),
        ('origin_not_allowed', 403, 'isn’t available from this device'),
      ]) {
        await expectLater(
          transcriber(
            (_) async => reply({
              'error': code,
              'message': 'SECRET provider diagnostic',
            }, status),
          ).transcribe(wav),
          throwsA(
            isA<VoiceSearchException>().having(
              (error) => error.message,
              'message',
              allOf(contains(message), isNot(contains('SECRET'))),
            ),
          ),
        );
      }
    },
  );

  test(
    'unknown or malformed backend errors use safe HTTP fallback copy',
    () async {
      for (final response in [
        reply({'error': 'SECRET provider diagnostic'}, 502),
        http.Response('SECRET raw response', 502),
        http.Response.bytes([255], 502),
      ]) {
        await expectLater(
          transcriber((_) async => response).transcribe(wav),
          failsWith('Voice transcription failed'),
        );
      }
    },
  );

  test('network failures and timeouts are reported', () async {
    await expectLater(
      transcriber(
        (_) async => throw http.ClientException('offline'),
      ).transcribe(wav),
      failsWith('Couldn’t reach'),
    );
    final never = Completer<http.Response>();
    await expectLater(
      transcriber(
        (_) => never.future,
        timeout: const Duration(milliseconds: 10),
      ).transcribe(wav),
      failsWith('took too long'),
    );
  });
}
