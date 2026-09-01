import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/companies/presentation/company_detail_screen.dart';
import '../../features/companies/presentation/company_list_screen.dart';
import '../session/session_controller.dart';
import 'app_routes.dart';

class AppRouter {
  static GoRouter create(SessionController session) {
    return GoRouter(
      initialLocation: AppPaths.splash,
      refreshListenable: session,
      redirect: (context, state) {
        final location = state.matchedLocation;

        switch (session.status) {
          case SessionStatus.loading:
            return location == AppPaths.splash ? null : AppPaths.splash;

          case SessionStatus.signedOut:
            return location == AppPaths.login ? null : AppPaths.login;

          case SessionStatus.needsOnboarding:
            return location == AppPaths.onboarding
                ? null
                : AppPaths.onboarding;

          case SessionStatus.ready:
            if (location == AppPaths.splash ||
                location == AppPaths.login ||
                location == AppPaths.onboarding) {
              return AppPaths.companies;
            }
            if (location == AppPaths.admin && !session.isAdmin) {
              return AppPaths.companies;
            }
            return null;
        }
      },
      routes: [
        GoRoute(
          path: AppPaths.splash,
          name: AppRoutes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: AppPaths.login,
          name: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppPaths.onboarding,
          name: AppRoutes.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppPaths.companies,
          name: AppRoutes.companies,
          builder: (context, state) => const CompanyListScreen(),
          routes: [
            GoRoute(
              path: AppPaths.companyDetail,
              name: AppRoutes.companyDetail,
              builder: (context, state) => CompanyDetailScreen(
                companyId: state.pathParameters['companyId'] ?? '',
              ),
            ),
          ],
        ),
        GoRoute(
          path: AppPaths.admin,
          name: AppRoutes.admin,
          builder: (context, state) => const AdminScreen(),
        ),
      ],
    );
  }
}
