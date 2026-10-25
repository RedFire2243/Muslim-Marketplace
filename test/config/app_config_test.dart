import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_marketplace/src/config/app_config.dart';
import 'package:muslim_marketplace/src/config/demo_keys.dart';

void main() {
  test('direct Gemini needs the explicit private-test flag and a key', () {
    const keyOnly = AppConfig(geminiApiKey: 'test-only-key');
    expect(keyOnly.hasDirectGemini, isFalse);
    expect(keyOnly.hasVoiceSearch, isFalse);
    expect(const AppConfig(geminiDirectTest: true).hasDirectGemini, isFalse);
    const direct = AppConfig(
      geminiDirectTest: true,
      geminiApiKey: 'test-only-key',
    );
    expect(direct.hasDirectGemini, isTrue);
    expect(direct.hasVoiceSearch, isTrue);
    expect(direct.geminiModel, 'gemini-3.8-flash');
  });

  test('builds without Gemini settings use the bundled demo key', () {
    final config = AppConfig.fromEnvironment();
    if (const bool.fromEnvironment('GEMINI_DIRECT_TEST', defaultValue: true)) {
      const key = String.fromEnvironment('GEMINI_API_KEY');
      expect(config.hasDirectGemini, isTrue);
      expect(config.hasVoiceSearch, isTrue);
      expect(
        config.geminiApiKey,
        key.trim().isEmpty ? demoGeminiApiKey : key.trim(),
      );
    } else {
      expect(config.geminiDirectTest, isFalse);
      expect(config.geminiApiKey, isEmpty);
      expect(config.hasDirectGemini, isFalse);
    }
  });

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
