import 'repositories.dart';

/// Real-account sign-in for connected mode.
abstract interface class AccountGateway {
  /// The backend for a session restored from device storage, if any.
  Future<MarketplaceBackend?> restore();

  Future<MarketplaceBackend> signIn({
    required String email,
    required String password,
  });

  Future<SignUpResult> signUp({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> signOut();
}

sealed class SignUpResult {
  const SignUpResult();
}

class SignedUp extends SignUpResult {
  const SignedUp(this.backend);
  final MarketplaceBackend backend;
}

/// The project requires email confirmation before the first sign-in.
class ConfirmationRequired extends SignUpResult {
  const ConfirmationRequired(this.email);
  final String email;
}
