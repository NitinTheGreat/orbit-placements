import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/routing/app_redirect.dart';
import 'package:orbit/core/routing/app_routes.dart';
import 'package:orbit/core/session/session_status.dart';

String? redirect(
  SessionStatus status,
  String location, {
  bool isAdmin = false,
}) {
  return resolveRedirect(status: status, location: location, isAdmin: isAdmin);
}

void main() {
  group('gmail connect gating', () {
    test('sends a student who has never connected to the connect step', () {
      expect(
        redirect(SessionStatus.needsGmailConnection, AppPaths.companies),
        AppPaths.gmailConnect,
      );
    });

    test('does not redirect once already on the connect step', () {
      expect(
        redirect(SessionStatus.needsGmailConnection, AppPaths.gmailConnect),
        isNull,
      );
    });

    test('blocks every other destination until connected', () {
      for (final path in [
        AppPaths.splash,
        AppPaths.login,
        AppPaths.onboarding,
        AppPaths.companies,
        AppPaths.admin,
      ]) {
        expect(
          redirect(SessionStatus.needsGmailConnection, path),
          AppPaths.gmailConnect,
          reason: '$path should not be reachable before connecting Gmail',
        );
      }
    });

    test('a ready student is pushed off the connect step', () {
      expect(
        redirect(SessionStatus.ready, AppPaths.gmailConnect),
        AppPaths.companies,
      );
    });
  });

  group('onboarding order', () {
    test('onboarding comes before the connect step', () {
      expect(
        redirect(SessionStatus.needsOnboarding, AppPaths.gmailConnect),
        AppPaths.onboarding,
      );
    });

    test('signed out beats onboarding', () {
      expect(
        redirect(SessionStatus.signedOut, AppPaths.onboarding),
        AppPaths.login,
      );
    });

    test('loading holds on splash', () {
      expect(
        redirect(SessionStatus.loading, AppPaths.companies),
        AppPaths.splash,
      );
      expect(redirect(SessionStatus.loading, AppPaths.splash), isNull);
    });
  });

  group('admin gate', () {
    test('a non-admin cannot reach the admin route', () {
      expect(redirect(SessionStatus.ready, AppPaths.admin), AppPaths.companies);
    });

    test('an admin can', () {
      expect(
        redirect(SessionStatus.ready, AppPaths.admin, isAdmin: true),
        isNull,
      );
    });

    test('company detail is left alone when ready', () {
      expect(
        redirect(SessionStatus.ready, AppPaths.companyDetailOf('abc')),
        isNull,
      );
    });
  });
}
