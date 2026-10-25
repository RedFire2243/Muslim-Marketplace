import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/areas.dart';

/// Turns a short voice recording into the words that were said.
abstract interface class SpeechTranscriber {
  /// Returns what was said, or an empty string when nothing clear was. Throws
  /// [VoiceSearchException] with a message to show the member.
  Future<String> transcribe(Uint8List wav);
}

class VoiceSearchException implements Exception {
  const VoiceSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Transcribes with the Gemini API (`models.generateContent`, audio sent
/// inline). The answer is used only as search text, so it is trimmed to a
/// search-sized string and never interpreted further.
class GeminiTranscriber implements SpeechTranscriber {
  GeminiTranscriber({
    required this.apiKey,
    required this.model,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  static const endpoint = 'https://generativelanguage.googleapis.com/v1beta';
  static const maxLength = 300;

  final String apiKey;
  final String model;
  final Duration timeout;
  final http.Client _client;

  static final instructions =
      '''You transcribe short voice searches for a community marketplace in Central Jersey, where Muslims look for services, jobs, internships, mentors, collaborators, volunteering and local businesses.

Write down what the speaker asks for, in the language they speak, exactly as they say it. Leave out filler words (um, uh) and false starts. Do not answer, summarise, correct or add to the request.

Town names that may come up: ${Areas.all.map((a) => a.name).join(', ')}.

If the recording is silent, only noise, or you cannot make out the words, return an empty transcript. Never guess.''';

  @override
  Future<String> transcribe(Uint8List wav) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$endpoint/models/$model:generateContent'),
            headers: {
              'content-type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(_request(wav)),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const VoiceSearchException(
        'Voice search took too long. Try again.',
      );
    } on http.ClientException catch (e) {
      debugPrint('Gemini request failed: $e');
      throw const VoiceSearchException(
        'Couldn’t reach voice search. Check your connection and try again.',
      );
    }
    if (res.statusCode != 200) throw _error(res);
    return _transcript(res.body);
  }

  Map<String, Object?> _request(Uint8List wav) => {
    'systemInstruction': {
      'parts': [
        {'text': instructions},
      ],
    },
    'contents': [
      {
        'role': 'user',
        'parts': [
          {
            'inlineData': {'mimeType': 'audio/wav', 'data': base64Encode(wav)},
          },
        ],
      },
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'responseSchema': {
        'type': 'OBJECT',
        'properties': {
          'transcript': {'type': 'STRING'},
        },
        'required': ['transcript'],
      },
    },
  };

  VoiceSearchException _error(http.Response res) {
    debugPrint('Gemini returned ${res.statusCode}: ${res.body}');
    final body = res.body;
    if (res.statusCode == 401 ||
        res.statusCode == 403 ||
        body.contains('API_KEY_INVALID')) {
      return const VoiceSearchException(
        'Voice search isn’t set up correctly: the Gemini API key was refused.',
      );
    }
    return VoiceSearchException(switch (res.statusCode) {
      404 =>
        'Voice search isn’t set up correctly: the Gemini model “$model” isn’t available.',
      429 => 'Voice search is busy right now. Try again in a minute.',
      >= 500 => 'Voice search is unavailable right now. Try again soon.',
      _ => 'Voice search didn’t work. Try again or type your search.',
    });
  }

  String _transcript(String body) {
    final Object? data;
    try {
      data = jsonDecode(body);
    } on FormatException {
      throw const VoiceSearchException(
        'Voice search didn’t work. Try again or type your search.',
      );
    }
    // No candidates (for example a blocked request) means nothing usable.
    if (data case {
      'candidates': [{'content': {'parts': final List<Object?> parts}}, ...],
    }) {
      final text = [
        for (final p in parts)
          if (p case {'text': final String t} when p['thought'] != true) t,
      ].join().trim();
      return _clean(_unwrap(text));
    }
    return '';
  }

  /// The schema asks for `{"transcript": ...}`; accept plain text too.
  static String _unwrap(String text) {
    try {
      if (jsonDecode(text) case {'transcript': final String t}) return t;
    } on FormatException {
      // Plain text answer.
    }
    return text;
  }

  static String _clean(String text) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= maxLength ? t : t.substring(0, maxLength).trim();
  }
}
