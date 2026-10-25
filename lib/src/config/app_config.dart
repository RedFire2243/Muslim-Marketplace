/// Build-time configuration, supplied with `--dart-define` or
/// `--dart-define-from-file=config/local.json`. Only public service URLs and
/// the Supabase publishable (anon) key belong in the app. AI provider keys
/// live on the server.
class AppConfig {
  const AppConfig({
    this.supabaseUrl = '',
    this.supabaseKey = '',
    this.aiExtraction = false,
    this.voiceSearchUrl = '',
  });

  factory AppConfig.fromEnvironment() {
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacyKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL').trim(),
      supabaseKey: (key.isNotEmpty ? key : legacyKey).trim(),
      aiExtraction: const bool.fromEnvironment('AI_EXTRACTION'),
      voiceSearchUrl: const String.fromEnvironment('VOICE_SEARCH_URL').trim(),
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

  /// Whether real accounts can be offered at all.
  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Whether a valid voice service endpoint is configured. HTTP is supported
  /// for a development server on the same network as a test device.
  bool get hasVoiceSearch {
    final uri = Uri.tryParse(voiceSearchUrl.trim());
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }
}
