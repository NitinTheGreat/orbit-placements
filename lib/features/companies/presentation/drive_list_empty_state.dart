enum DriveListEmptyState { gmailDisconnected, noDrives, allOptedOut }

DriveListEmptyState? resolveEmptyState({
  required bool gmailConnected,
  required int companyCount,
  required bool optedOutOfAll,
}) {
  if (!gmailConnected) {
    return DriveListEmptyState.gmailDisconnected;
  }
  if (companyCount == 0) {
    return DriveListEmptyState.noDrives;
  }
  if (optedOutOfAll) {
    return DriveListEmptyState.allOptedOut;
  }
  return null;
}

bool everyDriveOptedOut({
  required int companyCount,
  required int optedOutCount,
}) {
  return companyCount > 0 && optedOutCount >= companyCount;
}
