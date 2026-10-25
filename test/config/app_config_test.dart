import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/config/app_config.dart';

void main() {
  const environmentEndpoint = String.fromEnvironment('VOICE_SEARCH_URL');
  test(
    'fromEnvironment preserves the public voice endpoint',
    () {
      final config = AppConfig.fromEnvironment();
      expect(config.voiceSearchUrl, environmentEndpoint.trim());
      expect(config.hasVoiceSearch, isTrue);
    },
    skip: environmentEndpoint.isEmpty,
  );

  test('voice search needs a service endpoint and no AI provider key', () {
    expect(const AppConfig().hasVoiceSearch, isFalse);
    expect(
      const AppConfig(
        voiceSearchUrl: 'https://voice.example.test/transcribe',
      ).hasVoiceSearch,
      isTrue,
    );
    expect(
      const AppConfig(
        voiceSearchUrl: 'http://192.168.1.10:8787/voice-search',
      ).hasVoiceSearch,
      isTrue,
    );
  });

  test('invalid voice endpoints leave voice search unavailable', () {
    for (final url in [
      '',
      '   ',
      '/voice-search',
      'voice.example.test',
      'https:',
      'ftp://voice.example.test/transcribe',
      'file:///voice-search',
      'https://',
    ]) {
      expect(
        AppConfig(voiceSearchUrl: url).hasVoiceSearch,
        isFalse,
        reason: url,
      );
    }
  });
}
