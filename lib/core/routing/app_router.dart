import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/companies/presentation/company_detail_screen.dart';
import '../../features/companies/presentation/company_list_screen.dart';
import 'app_routes.dart';

class AppRouter {
  static GoRouter create() {
    return GoRouter(
      initialLocation: AppPaths.splash,
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
