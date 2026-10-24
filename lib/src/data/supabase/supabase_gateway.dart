import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../account_gateway.dart';
import '../errors.dart';
import '../repositories.dart';
import 'supabase_backend.dart';

/// Email and password accounts through Supabase Auth.
class SupabaseAccountGateway implements AccountGateway {
  SupabaseAccountGateway(this.client, this.config);

  final SupabaseClient client;
  final AppConfig config;

  static Future<SupabaseAccountGateway> initialize(AppConfig config) async {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseKey,
    );
    return SupabaseAccountGateway(Supabase.instance.client, config);
  }

  MarketplaceBackend _backend(String userId) => SupabaseBackend(
    client,
    currentUserId: userId,
    aiExtraction: config.aiExtraction,
  );

  @override
  Future<MarketplaceBackend?> restore() async {
    final user = client.auth.currentSession?.user;
    return user == null ? null : _backend(user.id);
  }

  @override
  Future<MarketplaceBackend> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw const AccountException(
          'We couldn’t sign you in. Please try again.',
        );
      }
      return _backend(user.id);
    } on AuthException catch (e) {
      throw AccountException(_friendly(e));
    } on MarketplaceException {
      rethrow;
    } catch (_) {
      throw const NetworkException();
    }
  }

  @override
  Future<SignUpResult> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final res = await client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      final user = res.user;
      if (res.session != null && user != null) {
        return SignedUp(_backend(user.id));
      }
      return ConfirmationRequired(email);
    } on AuthException catch (e) {
      throw AccountException(_friendly(e));
    } catch (_) {
      throw const NetworkException();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (_) {
      // Local session is cleared even if the server can't be reached.
    }
  }

  String _friendly(AuthException e) {
    final code = e.code ?? '';
    if (code == 'invalid_credentials') {
      return 'That email and password don’t match.';
    }
    if (code == 'email_not_confirmed') {
      return 'Please confirm your email first, then sign in.';
    }
    if (code == 'user_already_exists') {
      return 'An account with that email already exists. Try signing in.';
    }
    if (code == 'weak_password') return 'Choose a longer password.';
    return e.message;
  }
}
