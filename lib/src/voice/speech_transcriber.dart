import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

/// Sends the recording to the app's voice service, which owns the AI provider
/// credentials. The service accepts `{ "audio": "<base64 WAV>" }` and returns
/// `{ "transcript": "..." }`. Only the transcript is used as search text.
class BackendSpeechTranscriber implements SpeechTranscriber {
  BackendSpeechTranscriber({
    required this.url,
    this.accessToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  static const maxLength = 300;

  final String url;

  /// Read at request time so a refreshed account session is used immediately.
  /// Local development and demo services can accept requests without a token.
  final String? Function()? accessToken;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<String> transcribe(Uint8List wav) async {
    final http.Response res;
    try {
      final token = accessToken?.call()?.trim();
      res = await _client
          .post(
            Uri.parse(url.trim()),
            headers: {
              'content-type': 'application/json',
              if (token != null && token.isNotEmpty)
                'authorization': 'Bearer $token',
            },
            body: jsonEncode({'audio': base64Encode(wav)}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const VoiceSearchException(
        'Voice search took too long. Try again.',
      );
    } on http.ClientException {
      throw const VoiceSearchException(
        'Couldn’t reach voice search. Check your connection and try again.',
      );
    }
    if (res.statusCode != 200) throw _error(res);
    return _transcript(res.bodyBytes);
  }

  void dispose() => _client.close();

  VoiceSearchException _error(http.Response response) {
    String? code;
    try {
      if (response.bodyBytes.length <= 16384) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data case {'error': final String value}) code = value;
      }
    } on FormatException {
      // Only known stable codes are displayed; raw diagnostics remain private.
    }
    return VoiceSearchException(switch (code) {
      'voice_not_configured' =>
        'Voice transcription isn’t configured yet. Try typing your search.',
      'upstream_error' =>
        'Voice transcription failed. Try a shorter recording or type your search.',
      'timeout' =>
        'Voice transcription took too long. Try again with a shorter recording.',
      'unauthorized' => 'Sign in again to use voice search.',
      'authentication_unavailable' =>
        'Sign-in couldn’t be verified right now. Try again soon.',
      'rate_limited' =>
        'Voice search is busy right now. Try again in a minute.',
      'audio_too_long' || 'payload_too_large' =>
        'That recording was too long. Try a shorter search.',
      'invalid_audio' =>
        'That recording couldn’t be read. Please record your search again.',
      'request_not_allowed' || 'origin_not_allowed' =>
        'This voice service isn’t available from this device. Try typing your search.',
      _ => switch (response.statusCode) {
        401 => 'Sign in again to use voice search.',
        403 =>
          'Voice search isn’t available for this account. Try typing your search.',
        404 => 'Voice search isn’t set up correctly. Try typing your search.',
        413 => 'That recording was too long. Try a shorter search.',
        429 => 'Voice search is busy right now. Try again in a minute.',
        502 =>
          'Voice transcription failed. Try a shorter recording or type your search.',
        504 =>
          'Voice transcription took too long. Try again with a shorter recording.',
        >= 500 => 'Voice search is unavailable right now. Try again soon.',
        _ => 'Voice search didn’t work. Try again or type your search.',
      },
    });
  }

  String _transcript(Uint8List bytes) {
    try {
      final data = jsonDecode(utf8.decode(bytes));
      if (data case {'transcript': final String text}) {
        final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        return cleaned.length <= maxLength
            ? cleaned
            : cleaned.substring(0, maxLength).trim();
      }
    } on FormatException {
      // A malformed service response should never become a search request.
    }
    throw const VoiceSearchException(
      'Voice search didn’t work. Try again or type your search.',
    );
  }
}
