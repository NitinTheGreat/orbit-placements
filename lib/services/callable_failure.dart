const String serverUnreachableMessage =
    'Orbit cannot reach the server right now. This is on our side, not '
    'yours. Please try again in a little while.';

bool looksLikeAnErrorCode(String? message) {
  final detail = message?.trim();
  if (detail == null || detail.isEmpty) {
    return true;
  }
  return detail.toUpperCase() == detail && !detail.contains(' ');
}

String? plainCallableFailure(String code, String? message) {
  switch (code) {
    case 'internal':
    case 'unavailable':
    case 'deadline-exceeded':
    case 'unknown':
    case 'aborted':
      return serverUnreachableMessage;
    case 'unauthenticated':
      return 'Sign in again to continue.';
    case 'permission-denied':
      return 'This is only available to VIT student accounts.';
  }
  return looksLikeAnErrorCode(message) ? null : message!.trim();
}
