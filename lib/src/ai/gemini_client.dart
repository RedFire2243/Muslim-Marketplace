import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum GeminiFailure {
  authentication,
  model,
  rateLimited,
  unavailable,
  timeout,
  network,
  invalidResponse,
}

/// A safe error category. Provider response bodies and credentials stay private.
class GeminiClientException implements Exception {
  const GeminiClientException(this.failure);
  final GeminiFailure failure;

  @override
  String toString() => 'Gemini request failed: ${failure.name}';
}

/// Shared direct-test transport for structured voice and directory requests.
/// The explicit private-test configuration owns whether this client is enabled.
class GeminiClient {
  GeminiClient({
    required this.apiKey,
    required this.model,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.thinkingLevel = 'low',
  }) : _client = client ?? http.Client();

  static const endpoint = 'https://generativelanguage.googleapis.com/v1beta';
  final String apiKey;
  final String model;
  final Duration timeout;

  /// Gemini 3 models think at a high level by default, which makes a search
  /// over the demo directory take 9–15 s instead of 2–4 s. Null sends the
  /// model's default.
  final String? thinkingLevel;
  final http.Client _client;

  Future<Map<String, Object?>> generateJson({
    required String systemInstruction,
    required List<Map<String, Object?>> parts,
    required Map<String, Object?> responseSchema,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(
              '$endpoint/models/${Uri.encodeComponent(model)}:generateContent',
            ),
            headers: {
              'content-type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': systemInstruction},
                ],
              },
              'contents': [
                {'role': 'user', 'parts': parts},
              ],
              'generationConfig': {
                'responseMimeType': 'application/json',
                'responseSchema': responseSchema,
                if (thinkingLevel case final level?)
                  'thinkingConfig': {'thinkingLevel': level},
              },
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const GeminiClientException(GeminiFailure.timeout);
    } on http.ClientException {
      throw const GeminiClientException(GeminiFailure.network);
    }
    if (response.statusCode != 200) {
      throw GeminiClientException(_failure(response));
    }
    try {
      if (response.bodyBytes.length > 128 * 1024) {
        throw const GeminiClientException(GeminiFailure.invalidResponse);
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data case {
        'candidates': [
          {'content': {'parts': final List<Object?> responseParts}},
          ...,
        ],
      }) {
        final text = [
          for (final part in responseParts)
            if (part case {
              'text': final String value,
            } when part['thought'] != true)
              value,
        ].join();
        if (jsonDecode(text) case final Map<String, dynamic> result) {
          return result;
        }
      }
    } on FormatException {
      // Structured callers must never act on malformed or untyped output.
    }
    throw const GeminiClientException(GeminiFailure.invalidResponse);
  }

  GeminiFailure _failure(http.Response response) {
    if (response.statusCode == 400 &&
        response.bodyBytes.length <= 16384 &&
        utf8
            .decode(response.bodyBytes, allowMalformed: true)
            .contains('API_KEY_INVALID')) {
      return GeminiFailure.authentication;
    }
    return switch (response.statusCode) {
      401 || 403 => GeminiFailure.authentication,
      404 => GeminiFailure.model,
      429 => GeminiFailure.rateLimited,
      >= 500 => GeminiFailure.unavailable,
      _ => GeminiFailure.invalidResponse,
    };
  }

  void dispose() => _client.close();
}
