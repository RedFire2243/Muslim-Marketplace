/// Build-time configuration, supplied with `--dart-define` or
/// `--dart-define-from-file=config/local.json`. Nothing here is secret: the
/// Supabase publishable (anon) key is designed to ship in clients, and AI
/// provider keys live only on the server.
class AppConfig {
  const AppConfig({
    this.supabaseUrl = '',
    this.supabaseKey = '',
    this.aiExtraction = false,
  });

  factory AppConfig.fromEnvironment() {
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacyKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL').trim(),
      supabaseKey: (key.isNotEmpty ? key : legacyKey).trim(),
      aiExtraction: const bool.fromEnvironment('AI_EXTRACTION'),
    );
  }

  final String supabaseUrl;
  final String supabaseKey;

  /// Use the `extract-profile` Edge Function for onboarding suggestions in
  /// connected mode. The deterministic parser is always the fallback.
  final bool aiExtraction;

  /// Whether real accounts can be offered at all.
  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
