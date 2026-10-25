import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muslim_marketplace/src/ai/gemini_client.dart';

http.Response structured(Object? value) => http.Response(
  jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': 'private thinking', 'thought': true},
            {'text': jsonEncode(value)},
          ],
        },
      },
    ],
  }),
  200,
);

void main() {
  GeminiClient client(
    MockClientHandler handler, {
    Duration timeout = const Duration(seconds: 20),
  }) => GeminiClient(
    apiKey: 'test-only-key',
    model: 'gemini-test',
    client: MockClient(handler),
    timeout: timeout,
  );

  Future<Map<String, Object?>> generate(GeminiClient transport) =>
      transport.generateJson(
        systemInstruction: 'Return only matching directory IDs.',
        parts: [
          {'text': 'Find an engineer'},
        ],
        responseSchema: {'type': 'OBJECT'},
      );

  test(
    'shared transport sends structured contents and header-only credentials',
    () async {
      late http.Request sent;
      final result = await generate(
        client((request) async {
          sent = request;
          return structured({
            'ids': ['member-1'],
          });
        }),
      );
      expect(result, {
        'ids': ['member-1'],
      });
      expect(
        sent.url.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent',
      );
      expect(sent.headers['x-goog-api-key'], 'test-only-key');
      expect(sent.url.query, isEmpty);
      expect(sent.body, isNot(contains('test-only-key')));
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['contents'][0]['parts'], [
        {'text': 'Find an engineer'},
      ]);
      expect(body['generationConfig']['responseMimeType'], 'application/json');
      expect(body['generationConfig']['thinkingConfig'], {
        'thinkingLevel': 'low',
      });
    },
  );

  test('malformed or non-object output is rejected', () async {
    for (final response in [
      structured(['member-1']),
      http.Response('{"candidates":[]}', 200),
      http.Response('not json', 200),
    ]) {
      await expectLater(
        generate(client((_) async => response)),
        throwsA(
          isA<GeminiClientException>().having(
            (error) => error.failure,
            'failure',
            GeminiFailure.invalidResponse,
          ),
        ),
      );
    }
  });

  test(
    'provider errors become safe categories without their raw response',
    () async {
      for (final (status, failure) in [
        (401, GeminiFailure.authentication),
        (403, GeminiFailure.authentication),
        (404, GeminiFailure.model),
        (429, GeminiFailure.rateLimited),
        (503, GeminiFailure.unavailable),
        (400, GeminiFailure.invalidResponse),
      ]) {
        await expectLater(
          generate(
            client((_) async => http.Response('SECRET diagnostic', status)),
          ),
          throwsA(
            isA<GeminiClientException>()
                .having((error) => error.failure, 'failure', failure)
                .having(
                  (error) => error.toString(),
                  'message',
                  isNot(contains('SECRET')),
                ),
          ),
        );
      }
      await expectLater(
        generate(client((_) async => http.Response('API_KEY_INVALID', 400))),
        throwsA(
          isA<GeminiClientException>().having(
            (error) => error.failure,
            'failure',
            GeminiFailure.authentication,
          ),
        ),
      );
    },
  );

  test('network failures and timeouts use safe categories', () async {
    await expectLater(
      generate(
        client((_) async => throw http.ClientException('SECRET network')),
      ),
      throwsA(
        isA<GeminiClientException>().having(
          (error) => error.failure,
          'failure',
          GeminiFailure.network,
        ),
      ),
    );
    final never = Completer<http.Response>();
    await expectLater(
      generate(
        client((_) => never.future, timeout: const Duration(milliseconds: 10)),
      ),
      throwsA(
        isA<GeminiClientException>().having(
          (error) => error.failure,
          'failure',
          GeminiFailure.timeout,
        ),
      ),
    );
  });
}
