import '../../models/gmail_sync.dart';

enum SessionStatus {
  loading,
  signedOut,
  needsOnboarding,
  needsGmailConnection,
  ready,
}

SessionStatus resolveSessionStatus({
  required bool signedIn,
  required bool hasProfile,
  required GmailConnectionStatus gmailStatus,
}) {
  if (!signedIn) {
    return SessionStatus.signedOut;
  }
  if (!hasProfile) {
    return SessionStatus.needsOnboarding;
  }
  if (gmailStatus == GmailConnectionStatus.none) {
    return SessionStatus.needsGmailConnection;
  }
  return SessionStatus.ready;
}
