import '../session/session_status.dart';
import 'app_routes.dart';

String? resolveRedirect({
  required SessionStatus status,
  required String location,
  required bool isAdmin,
}) {
  switch (status) {
    case SessionStatus.loading:
      return location == AppPaths.splash ? null : AppPaths.splash;

    case SessionStatus.signedOut:
      return location == AppPaths.login ? null : AppPaths.login;

    case SessionStatus.needsOnboarding:
      return location == AppPaths.onboarding ? null : AppPaths.onboarding;

    case SessionStatus.needsGmailConnection:
      return location == AppPaths.gmailConnect ? null : AppPaths.gmailConnect;

    case SessionStatus.ready:
      const gated = <String>{
        AppPaths.splash,
        AppPaths.login,
        AppPaths.onboarding,
        AppPaths.gmailConnect,
      };
      if (gated.contains(location)) {
        return AppPaths.companies;
      }
      if (location == AppPaths.admin && !isAdmin) {
        return AppPaths.companies;
      }
      return null;
  }
}
