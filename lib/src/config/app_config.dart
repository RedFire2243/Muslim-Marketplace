/// Build-time configuration, supplied with `--dart-define` or
/// `--dart-define-from-file=config/local.json`. The Supabase publishable
/// (anon) key is designed to ship in clients, and the Claude key for
/// extraction lives only on the server. The one exception is the optional
/// Gemini key for voice search, which is compiled into the build that uses it.
class AppConfig {
  const AppConfig({
    this.supabaseUrl = '',
    this.supabaseKey = '',
    this.aiExtraction = false,
    this.geminiApiKey = '',
    this.geminiModel = defaultGeminiModel,
  });

  factory AppConfig.fromEnvironment() {
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacyKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const model = String.fromEnvironment('GEMINI_MODEL');
    return AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL').trim(),
      supabaseKey: (key.isNotEmpty ? key : legacyKey).trim(),
      aiExtraction: const bool.fromEnvironment('AI_EXTRACTION'),
      geminiApiKey: const String.fromEnvironment('GEMINI_API_KEY').trim(),
      geminiModel: model.trim().isEmpty ? defaultGeminiModel : model.trim(),
    );
  }

  static const defaultGeminiModel = 'gemini-3.8-flash';

  final String supabaseUrl;
  final String supabaseKey;

  /// Use the `extract-profile` Edge Function for onboarding suggestions in
  /// connected mode. The deterministic parser is always the fallback.
  final bool aiExtraction;

  /// Gemini API key for voice search. Anyone with the build can read it, so
  /// use it for local development or with a key restricted to your site.
  final String geminiApiKey;

  /// Gemini model that transcribes voice searches.
  final String geminiModel;

  /// Whether real accounts can be offered at all.
  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Whether the search box offers a microphone.
  bool get hasVoiceSearch => geminiApiKey.isNotEmpty;
}
