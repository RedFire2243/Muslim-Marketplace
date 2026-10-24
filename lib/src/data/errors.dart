/// Errors raised by repositories in both modes. Messages are written for
/// members, not developers.
sealed class MarketplaceException implements Exception {
  const MarketplaceException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The signed-in member may not perform this action (ownership,
/// conversation participation, request role).
class NotAllowedException extends MarketplaceException {
  const NotAllowedException([super.message = 'You don’t have access to that.']);
}

class NotFoundException extends MarketplaceException {
  const NotFoundException([
    super.message = 'We couldn’t find that. It may have been removed.',
  ]);
}

class ValidationException extends MarketplaceException {
  const ValidationException(
    this.fieldErrors, [
    super.message = 'Please check the highlighted fields.',
  ]);
  final Map<String, String> fieldErrors;
}

/// The action would duplicate something that already exists.
class ConflictException extends MarketplaceException {
  const ConflictException(super.message);
}

/// The status change is not allowed from the current state.
class InvalidTransitionException extends MarketplaceException {
  const InvalidTransitionException([
    super.message = 'That change is no longer possible.',
  ]);
}

/// The backend could not be reached.
class NetworkException extends MarketplaceException {
  const NetworkException([
    super.message =
        'We couldn’t reach the server. Check your connection and try again.',
  ]);
}

/// Sign-in or account errors.
class AccountException extends MarketplaceException {
  const AccountException(super.message);
}

/// Turns any error into a member-facing sentence.
String friendlyError(Object error) => switch (error) {
  final MarketplaceException e => e.message,
  _ => 'Something went wrong. Please try again.',
};
