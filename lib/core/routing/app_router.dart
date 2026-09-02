import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/gmail_connect_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/companies/presentation/company_detail_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../session/session_controller.dart';
import 'app_redirect.dart';
import 'app_routes.dart';

class AppRouter {
  static GoRouter create(SessionController session) {
    return GoRouter(
      initialLocation: AppPaths.splash,
      refreshListenable: session,
      redirect: (context, state) => resolveRedirect(
        status: session.status,
        location: state.matchedLocation,
        isAdmin: session.isAdmin,
      ),
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
          path: AppPaths.gmailConnect,
          name: AppRoutes.gmailConnect,
          builder: (context, state) => const GmailConnectScreen(),
        ),
        GoRoute(
          path: AppPaths.companies,
          name: AppRoutes.companies,
          builder: (context, state) => const HomeShell(),
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
