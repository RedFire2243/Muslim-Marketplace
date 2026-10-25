import 'demo_keys.dart';

/// Build-time configuration, supplied with `--dart-define` or
/// `--dart-define-from-file=config/local.json`. For the demo, every build
/// calls Gemini directly with the bundled [demoGeminiApiKey] unless it passes
/// its own `GEMINI_API_KEY` or opts out with `GEMINI_DIRECT_TEST=false`.
class AppConfig {
  const AppConfig({
    this.supabaseUrl = '',
    this.supabaseKey = '',
    this.aiExtraction = false,
    this.voiceSearchUrl = '',
    this.geminiDirectTest = false,
    this.geminiApiKey = '',
    this.geminiModel = defaultGeminiModel,
  });

  factory AppConfig.fromEnvironment() {
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacyKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const directTest = bool.fromEnvironment(
      'GEMINI_DIRECT_TEST',
      defaultValue: true,
    );
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');
    const model = String.fromEnvironment('GEMINI_MODEL');
    return AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL').trim(),
      supabaseKey: (key.isNotEmpty ? key : legacyKey).trim(),
      aiExtraction: const bool.fromEnvironment('AI_EXTRACTION'),
      voiceSearchUrl: const String.fromEnvironment('VOICE_SEARCH_URL').trim(),
      geminiDirectTest: directTest,
      geminiApiKey: !directTest
          ? ''
          : apiKey.trim().isEmpty
          ? demoGeminiApiKey
          : apiKey.trim(),
      geminiModel: model.trim().isEmpty ? defaultGeminiModel : model.trim(),
    );
  }

  final String supabaseUrl;
  final String supabaseKey;

  /// Use the `extract-profile` Edge Function for onboarding suggestions in
  /// connected mode. The deterministic parser is always the fallback.
  final bool aiExtraction;

  /// Public endpoint that transcribes voice searches. The endpoint keeps its
  /// AI provider credentials on the server.
  final String voiceSearchUrl;

  static const defaultGeminiModel = 'gemini-3.8-flash';

  /// Direct API mode: the app calls Gemini itself, so the key ships in the
  /// build. On by default for the demo and takes precedence over
  /// [voiceSearchUrl]; `GEMINI_DIRECT_TEST=false` uses the voice server.
  final bool geminiDirectTest;
  final String geminiApiKey;
  final String geminiModel;

  bool get hasDirectGemini =>
      geminiDirectTest && geminiApiKey.trim().isNotEmpty;

  /// Whether real accounts can be offered at all.
  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Whether a voice endpoint or explicit direct-test configuration is ready.
  /// HTTP supports a development server on the test device's local network.
  bool get hasVoiceSearch {
    if (hasDirectGemini) return true;
    final uri = Uri.tryParse(voiceSearchUrl.trim());
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }
}
